=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Factory::MultipleLocation;

use strict;

use POSIX qw(floor);

use Bio::EnsEMBL::Registry;

use base qw(EnsEMBL::Web::Factory::Location);

sub canLazy { return 0; }

sub createObjects {
  my $self = shift;
  
  $self->SUPER::createObjects;
  
  my $object = $self->object;
  
  return unless $object;

  # Ignore r parameters if recalculating
  if($self->hub->script eq 'Page' and $self->param('realign')) {
    foreach my $p ($self->param) {
      next unless $p =~ /^r\d+$/;
      $self->delete_param($p);
    }
  }

  # Redirect if we need to generate a new url
  return if $self->generate_url($object->slice);
  
  my $hub       = $self->hub;
  my $action_id = $self->param('id');
  my $gene      = 0;
  my $invalid   = 0;
  my @slices;
  my $chr_flag;
  
  my %inputs = (
    0 => { 
      s => $self->species,
      r => $self->param('r'),
      g => $self->param('g')
    }
  );
  
  foreach ($self->param) {
    $inputs{$2}->{$1} = $self->param($_) if /^([gr])(\d+)$/;
    ($inputs{$1}->{'s'}, $inputs{$1}->{'chr'}) = split '--', $self->param($_) if /^s(\d+)$/;
    $chr_flag = 1 if $inputs{$1} && $inputs{$1}->{'chr'};
  }
  
  # Strip bad parameters (r/g without s)
  foreach my $id (grep !$inputs{$_}->{'s'}, keys %inputs) {
    $self->delete_param("$_$id") for keys %{$inputs{$id}};
    $invalid = 1;
  }
  
  $inputs{$action_id}->{'action'} = $self->param('action') if $inputs{$action_id};
  
  # If we had bad parameters, redirect to remove them from the url.
  # If we came in on an a gene, redirect so that we use the location in the url instead.
  return $self->problem('redirect', $hub->url($hub->multi_params)) if $invalid || $self->input_genes(\%inputs) || $self->change_all_locations(\%inputs);
  
  foreach (sort { $a <=> $b } keys %inputs) {
    my $species = $inputs{$_}->{'s'};
    my $r       = $inputs{$_}->{'r'};
    
    next unless $species && $r;
    
    $self->__set_species($species);
    
    my ($seq_region_name, $s, $e, $strand) = $r =~ /^([^:]+):(-?\w+\.?\w*)-(-?\w+\.?\w*)(?::(-?\d+))?/;
    $s = 1 if $s < 1;
    
    $inputs{$_}->{'chr'} ||= $seq_region_name if $chr_flag;
    
    my $action = $inputs{$_}->{'action'};
    my $chr    = $inputs{$_}->{'chr'} || $seq_region_name;
    my $slice;
    
    my $modifiers = {
      in      => sub { ($s, $e) = ((3*$s + $e)/4,   (3*$e + $s)/4  ) }, # Half the length
      out     => sub { ($s, $e) = ((3*$s - $e)/2,   (3*$e - $s)/2  ) }, # Double the length
      left    => sub { ($s, $e) = ($s - ($e-$s)/10, $e - ($e-$s)/10) }, # Shift left by length/10
      left2   => sub { ($s, $e) = ($s - ($e-$s)/2,  $e - ($e-$s)/2 ) }, # Shift left by length/2
      right   => sub { ($s, $e) = ($s + ($e-$s)/10, $e + ($e-$s)/10) }, # Shift right by length/10
      right2  => sub { ($s, $e) = ($s + ($e-$s)/2,  $e + ($e-$s)/2 ) }, # Shift right by length/2
      flip    => sub { ($strand ||= 1) *= -1 },
      realign => sub { $self->realign(\%inputs, $_) },
      primary => sub { $self->change_primary_species(\%inputs, $_) }
    };
    
    # We are modifying the url - redirect.
    if ($action && exists $modifiers->{$action}) {
      $modifiers->{$action}();
      
      $self->check_slice_exists($_, $chr, $s, $e, $strand);
      
      return $self->problem('redirect', $hub->url($hub->multi_params));
    }
    
    eval { $slice = $self->slice_adaptor->fetch_by_region(undef, $chr, $s, $e, $strand); };
    next if $@;

    # Get image left and right padding
    my $padding = $hub->create_padded_region();
    push @slices, {
      slice         => $slice->expand($padding->{flank5}, $padding->{flank3}),
      species       => $species,
      target        => $inputs{$_}->{'chr'},
      species_check => $species eq $hub->species ? join('--', grep $_, $species, $inputs{$_}->{'chr'}) : $species,
      name          => $slice->seq_region_name,
      short_name    => $object->chr_short_name($slice, $species),
      start         => $slice->start,
      end           => $slice->end,
      strand        => $slice->strand,
      length        => $slice->seq_region_length
    };
  }
  
  $object->__data->{'_multi_locations'} = \@slices;
}

sub generate_url {
  my ($self, $slice) = @_;

  my @add = grep { s/^s(\d+)$/$1/ && $self->param("s$_") && !(defined $self->param("r$_") || defined $self->param("g$_")) } $self->param;
  
  $self->add_species($slice, \@add) if scalar @add;
  
  return 1 if scalar @add;
}

sub add_species {
  my ($self, $slice, $add) = @_;
  my $hub           = $self->hub;
  my $session       = $hub->session;
  my %valid_species = map { $_ => 1 } $self->species_defs->valid_species;
  my @no_alignment;
  my @no_species;
  my $paralogues = 0;
  my @haplotypes;
  my @remove;
  
  my ($i) = sort { $b <=> $a } grep { s/^s(\d+)$/$1/ && $self->param("s$_") } $self->param;
  
  foreach (@$add) {
    my $param = $_;
    my $id;
    
    $i++;
    
    if (int eq $_) {
      $id = $_;
      $param = $self->param("s$_");
    } else {
      $id = $i;
    }
    
    my ($species, $seq_region_name) = split '--', $param;
    
    if ($self->best_guess($slice, $id, $species, $seq_region_name)) {
      $self->param("s$id", $param);
    } else {
      if ($valid_species{$species}) {
        if ($species eq $self->species) {
          $paralogues++ unless $seq_region_name;
          if ($seq_region_name) {
            push @haplotypes, $self->species_defs->species_label($species) . ' ' . $seq_region_name;
          }
        } else {
          push @no_alignment, $self->species_defs->species_label($species) . ($seq_region_name ? " $seq_region_name" : '');
        }
      } else {
        push @no_species, $species;
      }
      
      push @remove, $id;
    }
  }
  
  $self->remove_species(\@remove) if scalar @remove;
  
  if (scalar @no_species) {
    $session->set_record_data({
      type     => 'message',
      function => '_error',
      code     => 'invalid_species',
      message  => scalar @no_species > 1 ? 
        'The following species do not exist in the database: <ul><li>' . join('</li><li>', @no_species) . '</li></ul>' :
        'The following species does not exist in the database:' . $no_species[0]
    });
  }
  
  if (scalar @no_alignment) {
    $session->set_record_data({
      type     => 'message',
      function => '_warning',
      code     => 'missing_species',
      message  => scalar @no_alignment > 1 ? 
        'There are no alignments in this region for the following species: <ul><li>' . join('</li><li>', @no_alignment) . '</li></ul>' :
        'There is no alignment in this region for ' . $no_alignment[0]
    });
  }
  
  if (scalar @haplotypes) {
    $session->set_record_data({
      type     => 'message',
      function => '_warning',
      code     => 'missing_species',
      message  => scalar @haplotypes > 1 ? 
        'There are no alignments in this region for the following: <ul><li>' . join('</li><li>', @haplotypes) . '</li></ul>' :
        'There is no alignment in this region for ' . $haplotypes[0]
    });
  }

  if ($paralogues) {
    $session->set_record_data({
      type     => 'message',
      function => '_warning',
      code     => 'missing_species',
      message  => ($paralogues == 1 ? 'A paralogue has' : 'Paralogues have') . ' been removed for ' . $self->species
    });
  }
  
  if (!scalar @remove) {
    $self->clear_problem_type('redirect');
    $self->problem('redirect', $hub->url($hub->multi_params));
  }
}

sub remove_species {
  my ($self, $remove, $primary_species) = @_;
  
  $remove = [ $remove ] unless ref $remove;
  
  foreach my $i (@$remove) {
    $self->delete_param("$_$i") for qw(s g r);
  }
  
  my $hub        = $self->hub;
  my $new_params = $hub->multi_params;
  my $params;
  my $i = 1;
  
  # Accounting for missing species, bump the values up to condense the url
  foreach (sort keys %$new_params) {
    if (/^s(\d+)$/ && $new_params->{$_}) {
      $params->{"s$i"} = $new_params->{"s$1"};
      $params->{"r$i"} = $new_params->{"r$1"};
      $params->{"g$i"} = $new_params->{"g$1"} if $new_params->{"g$1"};
      $i++;
    } elsif (!/^[sgr]\d+$/) {
      $params->{$_} = $new_params->{$_};
    }
  }
  
  $params->{'species'} = $primary_species if $primary_species;
  
  $self->clear_problem_type('redirect');
  $self->problem('redirect', $hub->url($params));
}

sub best_guess {
  my ($self, $slice, $id, $species, $seq_region_name) = @_;
  
  my $width = $slice->end - $slice->start + 1;
  
  foreach my $method ($seq_region_name && $species eq $self->species ? 'LASTZ_PATCH' : (), qw(BLASTZ_NET LASTZ_NET TRANSLATED_BLAT TRANSLATED_BLAT_NET BLASTZ_RAW LASTZ_RAW BLASTZ_CHAIN CACTUS_HAL_PW)) {    

    my ($seq_region, $cp, $strand);
  
    eval {
      ($seq_region, $cp, $strand) = $self->dna_align_feature_adaptor->interpolate_best_location($slice, $species, $method, $seq_region_name);
    };
    
    if ($seq_region) {
      my $start = floor($cp - ($width-1)/2);
      my $end   = floor($cp + ($width-1)/2);
      
      $self->__set_species($species);
      
      return 1 if $self->check_slice_exists($id, $seq_region, $start, $end, $strand);
    }
  }
  return 0;
}

sub input_genes {
  my ($self, $inputs) = @_;
  
  my $gene = 0;
  
  foreach (grep { $inputs->{$_}->{'g'} && !$inputs->{$_}->{'r'} } keys %$inputs) {
    my $species = $inputs->{$_}->{'s'};
    my $g       = $inputs->{$_}->{'g'};
    
    next unless $species;
    
    $self->__set_species($species);
    
    my $slice = $self->slice_adaptor->fetch_by_gene_stable_id($g);
    
    $self->check_slice_exists($_, $slice->seq_region_name, $slice->start, $slice->end, $slice->strand);
    
    $gene = 1;
  }
  
  return $gene;
}

sub check_slice_exists {
  my ($self, $id, $chr, $start, $end, $strand) = @_;
  
  if (defined $start) {
    $start = floor($start);
    
    $end = $start unless defined $end;
    $end = floor($end);
    $end = 1 if $end < 1;
    
    # Truncate slice to start of seq region
    if ($start < 1) {
      $end += abs($start) + 1;
      $start = 1;
    }
    
    ($start, $end) = ($end, $start) if $start > $end;
    
    $strand ||= 1;

    my $db = $self->database('core');
    my $csa = $db->get_CoordSystemAdaptor();
    my @coord_systems = @{$csa->fetch_all()};
    push(@coord_systems, @{$self->__coord_systems} );
    foreach my $system (@coord_systems) {  
      my $slice;
      
      eval { $slice = $self->slice_adaptor->fetch_by_region($system->name, $chr, $start, $end, $strand); };
      next if $@;
      
      if ($slice) {
        if ($start > $slice->seq_region_length || $end > $slice->seq_region_length) {
          ($start, $end) = ($slice->seq_region_length - $slice->length + 1, $slice->seq_region_length);
          $start = 1 if $start < 1;
          
          $slice = $self->slice_adaptor->fetch_by_region($system->name, $chr, $start, $end, $strand);
        }
        
        $self->param('r' . ($id || ''), "$chr:$start-$end:$strand"); # Set the r parameter for use in the redirect
        
        return 1;
      }
    }
  }
  
  return 0;
}

sub realign {
  my ($self, $inputs, $id) = @_;
  my $hub        = $self->hub;
  my $species    = $inputs->{0}{'s'};
  my $params     = $hub->multi_params($id);
  my $alignments = $self->species_defs->multi_hash->{'DATABASE_COMPARA'}->{'ALIGNMENTS'} || {};
  
  my %allowed;
  
  foreach my $i (grep { $alignments->{$_}{'class'} =~ /pairwise/ } keys %$alignments) {
    foreach (keys %{$alignments->{$i}{'species'}}) {
      $allowed{$_} = 1 if $alignments->{$i}{'species'}{$species} && ($_ ne $species || scalar keys %{$alignments->{$i}{'species'}} == 1);
    }
  }
  
  # Retain r/g for species with no alignments
  foreach (keys %$inputs) {
    next if $allowed{$inputs->{$_}{'s'}} || $_ == 0;
    
    $params->{"r$_"} = $inputs->{$_}{'r'};
    $params->{"g$_"} = $inputs->{$_}{'g'};
  }
  
  $self->problem('redirect', $hub->url($params));
}

sub change_primary_species {
  my ($self, $inputs, $id) = @_;
  
  my $old_species = $inputs->{0}->{'s'};
  my $old_chr = [ split(/:/,$inputs->{0}->{'r'}) ]->[0];
  
  $inputs->{$id}->{'r'} =~ s/:-?1$//; # Remove strand parameter for the new primary species
  
  $self->param('r', $inputs->{$id}->{'r'});
  $self->param('g', $inputs->{$id}->{'g'}) if $inputs->{$id}->{'g'};
  $self->param('s99999', "$old_species--$old_chr"); # Set arbitrarily high - will be recuded by remove_species
  $self->delete_param('align'); # Remove the align parameter because it may not be applicable for the new species
  
  foreach my $i (grep $_, keys %$inputs) {
    if ($inputs->{$i}->{'s'} eq $self->species) {
      $self->delete_param($_ . $i) for keys %{$inputs->{$i}}; # Remove parameters if one of the secondary species is the same as the primary (looking at an paralogue)
    } elsif ($i != $id) {
      $self->delete_param("$_$i") for qw(r g); # Strip location-setting parameters on other non-primary species
    }
  }
  
  $self->remove_species($id, $inputs->{$id}->{'s'});
}

sub change_all_locations {
  my ($self, $inputs) = @_;
  
  if ($self->param('multi_action') eq 'all') {
    my $all_s = $self->param('all_s');
    my $all_w = $self->param('all_w');
    
    foreach (keys %$inputs) {
      my ($seq_region_name, $s, $e, $strand) = $inputs->{$_}->{'r'} =~ /^([^:]+):(-?\w+\.?\w*)-(-?\w+\.?\w*)(?::(-?\d+))?/;
      
      $self->__set_species($inputs->{$_}->{'s'});
      
      my $max = $self->slice_adaptor->fetch_by_region(undef, $seq_region_name, $s, $e, $strand)->seq_region_length;
      
      if ($all_s) {
        $s += $all_s;
        $e += $all_s;
      } else {
        my $c = int(($s + $e) / 2);
        ($s, $e) = ($c - int($all_w/2) + 1, $c + int($all_w/2));
      }
      
      ($s, $e) = (1, $e - $s || 1) if $s < 1;
      ($s, $e) = ($max - ($e - $s), $max) if $e > $max;
      $s = 1 if $s < 1;
      
      $self->param($_ ? "r$_" : 'r', "$seq_region_name:$s-$e" . ($strand ? ":$strand" : ''));
    }
    
    return 1;
  }
}

sub slice_adaptor {
  my $self = shift;
  my $species = $self->__species;
  
  return $self->__data->{'adaptors'}->{$species} ||= Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'Slice');
}

sub dna_align_feature_adaptor {
  my $self = shift;
  
  return $self->__data->{'compara_adaptors'}->{'dna_align_feature'} ||= $self->database('compara')->get_DnaAlignFeatureAdaptor;
}

1;
