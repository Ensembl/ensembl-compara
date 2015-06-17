=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ZMenu::TextSequence;

use strict;

use Bio::EnsEMBL::Variation::Utils::Constants;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $object  = $self->object;
  my @vf      = $hub->param('vf');
  my $lrg     = $hub->param('lrg');
  my $adaptor = $hub->get_adaptor('get_VariationAdaptor', 'variation');
  
  $object = $self->hub->core_object('LRG') unless defined $object;

  if ($lrg && $hub->referer->{'ENSEMBL_TYPE'} eq 'LRG') {
    eval { $self->{'lrg_slice'} = $hub->get_adaptor('get_SliceAdaptor')->fetch_by_region('LRG', $lrg); };
  } elsif ($hub->referer->{'ENSEMBL_TYPE'} eq 'Transcript' || $hub->param('_transcript')) {
    $self->{'transcript'} = $hub->get_adaptor('get_TranscriptAdaptor')->fetch_by_stable_id($hub->param('_transcript') || $hub->param('t'));
  }
 
  my $vfa = $hub->get_adaptor('get_VariationFeatureAdaptor','variation'); 
  foreach (@vf) {
    my $feature = $vfa->fetch_by_dbID($_);
    my $variation = $feature->variation();
    my $variation_object = $self->new_object('Variation', $variation, $object->__data);
    $self->variation_content($variation_object, $feature);
    $self->new_feature;
  }
}

sub variation_content {
  my ($self, $object, $feature) = @_;
  my $hub        = $self->hub;
  my $variation  = $object->Obj;  
  my $seq_region = $feature->seq_region_name . ':';  
  my $chr_start  = $feature->start;
  my $chr_end    = $feature->end;
  my $allele     = $feature->allele_string;
  my @failed     = @{$feature->variation->get_all_failed_descriptions};
  my $position   = "$seq_region$chr_start";
  my ($lrg_position, %population_data, %population_allele);
 
  my $v = $feature->variation()->name(); 
  my %url_params = (
    type   => 'Variation',
    v      => $v,
    vf     => $feature->dbID(),
    source => $feature->source_name,
  );
  
  if ($chr_end < $chr_start) {
    $position = "between $seq_region$chr_end & $seq_region$chr_start";
  } elsif ($chr_end > $chr_start) {
    $position = "$seq_region$chr_start-$chr_end";
  }
  
  # If we have an LRG in the URL, get the LRG coordinates as well
  if ($self->{'lrg_slice'}) {
    my $lrg_feature = $feature->transfer($self->{'lrg_slice'});
    my $lrg_start   = $lrg_feature->start;
    my $lrg_end     = $lrg_feature->end;
    $lrg_position   = $lrg_feature->seq_region_name . ":$lrg_start";
    
    if ($lrg_end < $lrg_start) {
      $lrg_position = "between $lrg_end & $lrg_start on " . $lrg_feature->seq_region_name;
    } elsif ($lrg_end > $lrg_start) {
      $lrg_position = $lrg_feature->seq_region_name . ":$lrg_start-$lrg_end";
    }
  }
  
  $allele = substr($allele, 0, 10) . '...' if length $allele > 10; # truncate very long allele strings
  
  $self->caption(sprintf('%s: <a href="%s">%s</a>', $feature->variation->is_somatic ? 'Somatic mutation' : 'Variation', $hub->url({ action => 'Explore', %url_params }), $v), 1);
  
  my @entries = ({ type => 'Position', label => $position });
  
  if (scalar @failed) {
    push @entries, { type => 'Failed status', label_html => sprintf '<span style="color:red">%s</span>', shift @failed };
    push @entries, { type => '',              label_html => sprintf '<span style="color:red">%s</span>', shift @failed } while @failed;
  }
  
  push @entries, { type => 'LRG position', label => $lrg_position } if $lrg_position;
  push @entries, { type => 'Alleles',      label => $allele };
  
  if ($self->{'transcript'}) {
    my $tv = $feature->get_all_TranscriptVariations([$self->{'transcript'}])->[0];
    
    if ($tv) {
      my $pep_alleles = $tv->pep_allele_string;
      my $codons      = $tv->codons;
      ## Also truncate long peptides
      if (length $pep_alleles > 10) {
        $pep_alleles =~ /(\w{10})\w+(\w\/\w)(\w+)/;
        $pep_alleles = $1.'...'.$2;
        $pep_alleles .= '...' if $3;
      }
      if (length $codons > 10) {
        $codons =~ /(\w{10})\w+(\w\/\w)(\w+)/;
        $codons = $1.'...'.$2;
        $codons .= '...' if $3;
      }
      
      push @entries, { type => 'Amino acids', label => $pep_alleles} if $pep_alleles && $pep_alleles =~ /\//;
      push @entries, { type => 'Codons',      label => $codons}      if $codons      && $codons      =~ /\//;
    }
  }

  # Consequence terms and display
  my %ct    = map { $_->SO_term => { label => $_->label, 'rank' => $_->rank, 'description' => $_->description } } values %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
  my %types = map {$_ => $ct{$_}{rank}} @{($self->{'transcript'} ? $feature->get_all_TranscriptVariations([$self->{'transcript'}])->[0] : $feature)->consequence_type};  

  my $var_styles = $self->hub->species_defs->colour('variation');
  my $colourmap  = $self->hub->colourmap;
  my $type = join ' ',
     map {
       sprintf(
         '<li>'.
         '  <nobr><span class="colour" style="background-color:%s">&nbsp;</span> '.
         '  <span class="_ht conhelp coltab_text" title="%s">%s</span></nobr>'.
         '</li>',
         $var_styles->{$_} ? $colourmap->hex_by_name($var_styles->{$_}->{'default'}) : $colourmap->hex_by_name($var_styles->{'default'}->{'default'}),
         $ct{$_}->{'description'},
         $ct{$_}->{'label'}
       )
     }
     sort { $types{$a} <=> $types{$b} } keys %types;

  push @entries, (
    { type  => 'Consequences',   label_html => "<ul>$type</ul>" },
    { link  => $hub->url({ action => 'Explore', %url_params}), label => 'Explore this variation'},
    { link  => $hub->url({ action => 'Mappings', %url_params }), label => 'Gene/Transcript Locations' }
  );

  push @entries, { link => $hub->url({ action => 'Phenotype', %url_params }), label => 'Phenotype Data' } if scalar @{$object->get_external_data};

  foreach my $pop (sort { $a->{'pop_info'}{'Name'} cmp $b->{'pop_info'}{'Name'} } grep { $_->{'pop_info'}{'Name'} =~ /^1000genomes.+phase_\d/i } values %{$object->freqs($feature)}) {
    my $name = [ split /:/, $pop->{'pop_info'}{'Name'} ]->[-1]; # shorten the population name
       $name = $name =~ /phase_1_(.+)/ ? $1 : '';
    
    foreach my $ssid (sort { $a->{'submitter'} cmp $b->{'submitter'} } values %{$pop->{'ssid'}}) {
      my @afreqs = @{$ssid->{'AlleleFrequency'}};
      
      foreach my $allele (@{$ssid->{'Alleles'}}) {
        push @{$population_allele{$name}}, $allele unless grep $_ eq $allele, @{$population_allele{$name}};
        $population_data{$name}{$ssid->{'submitter'}}{$allele} = sprintf '%.3f', shift @afreqs;
      }
    }
  }
    
  push @entries, { class => 'population', link => $hub->url({ action => 'Population', %url_params }), label => 'Population Allele Frequencies' } if scalar keys %population_data;

  my %colours;
  $colours{$_} = "base_$_" for(qw(C G A T));
  foreach my $name (sort { !$a <=> !$b || $b =~ /ALL/ cmp $a =~ /ALL/ || $a cmp $b } keys %population_data) {
    my %display = reverse %{$population_data{$name}};
    my $i       = 0;
    
    foreach my $submitter (keys %{$population_data{$name}}) {
      my (@freqs, $af);
      
      # Keep the alleles order
      foreach my $al (@{$population_allele{$name}}) {
        if ($population_data{$name}{$submitter}{$al}){
          $colours{$al} ||= "base_".(scalar(keys %colours)%4);
          push @freqs, $colours{$al};
          push @freqs, $population_data{$name}{$submitter}{$al};
          $af .= $af ? ', ' : '';
          $af .= "$al: $population_data{$name}{$submitter}{$al}";
        }
      }
      
      my $img;
         $img .= sprintf '<span class="freq %s" style="width:%spx"></span>', shift @freqs, 100 * shift @freqs while @freqs;
         $af   = "<div>$af</div>";
      
      if ($submitter) {
        push @entries, { childOf => 'population', type => $i++ ? ' ' : $name || ' ', label_html => $submitter };
        push @entries, { childOf => 'population', type => ' ', label_html => "$img$af" };
      } else {
        push @entries, { childOf => 'population', type => $name, label_html => "$img$af" };
      }
    }
  }
  
  $self->add_entry($_) for @entries;
}

1;
