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

package EnsEMBL::Web::Component::Variation::Compara_Alignments;

use strict;

use base qw(EnsEMBL::Web::Component::Compara_Alignments);

sub get_sequence_data {
  my ($self, $slices, $config) = @_;
  my (@sequence, @markup, @temp_slices);
  
  $self->set_variation_filter($config);
  
  foreach my $sl (@$slices) {
    my $mk            = {};
    my $slice         = $sl->{'slice'};
    my $name          = $sl->{'name'};
    my $seq           = uc $slice->seq(1);
    my @variation_seq = map ' ', 1..length $seq;
    
    $config->{'length'} ||= $slice->length;
    
    $self->set_alignments($config, $sl, $mk, $seq) if $config->{'align'};
    $self->set_variations($config, $sl, $mk, \@variation_seq);
    
    foreach (@{$config->{'focus_position'} || []}) {
      $mk->{'variations'}{$_}{'align'} = 1;
      delete $mk->{'variations'}{$_}{'href'} unless $config->{'ref_slice_seq'}; # delete link on the focus variation on the primary species, since we're already looking at it
    }
    
    if (!$sl->{'no_variations'} && grep /\S/, @variation_seq) {
      push @temp_slices, {};
      push @markup,      {};
      push @sequence,    [ map {{ letter => $_ }} @variation_seq ];
    }
    
    push @temp_slices, $sl;
    push @markup,      $mk;
    push @sequence,    [ map {{ letter => $_ }} split '', $seq ];
    
    $config->{'ref_slice_seq'} ||= $sequence[-1];
  }
  
  $config->{'display_width'} = $config->{'length'};
  $config->{'slices'}        = \@temp_slices;
  
  return (\@sequence, \@markup);
}

sub markup_conservation {
  my $self = shift;
  my ($sequence, $config) = @_;
  
  my $difference = 0;
  
  for my $i (0..scalar(@$sequence)-1) {
    next unless keys %{$config->{'slices'}->[$i]};
    next if $config->{'slices'}->[$i]->{'no_alignment'};
    
    my $seq = $sequence->[$i];
    
    for (0..$config->{'length'}-1) {
      next if $seq->[$_]->{'letter'} eq $config->{'ref_slice_seq'}->[$_]->{'letter'};
      
      $seq->[$_]->{'class'} .= 'dif ';
      $difference = 1;
    }
  }
  
  $config->{'key'}->{'difference'} = 1 if $difference;
}

sub content {  
  my $self         = shift;
  my $hub          = $self->hub;
  my $object       = $self->object;
  my $species      = $hub->species;
  my $species_defs = $hub->species_defs;
  my $width        = 20;
  my %mappings     = %{$object->variation_feature_mapping}; 
  my $v            = keys %mappings == 1 ? [ values %mappings ]->[0] : $mappings{$hub->param('vf')};
  
  return $self->_info('Unable to draw SNP neighbourhood', $object->not_unique_location) if $object->not_unique_location;
  
  my $defaults = { 
    snp_display          => 1, 
    conservation_display => 1,
    variation_sequence   => 1,
    v                    => $hub->param('v'),
    focus_variant        => $hub->param('vf'),
    failed_variant       => $object->Obj->is_failed,
    ambiguity            => 0,
  };
  my $html;
  
  my $seq_type   = $v->{'type'}; 
  my $seq_region = $v->{'Chr'};
  my $start      = $v->{'start'} - ($width/2);  
  my $end        = $v->{'start'} + abs($v->{'end'} - $v->{'start'}) + ($width / 2);
  my $slice      = $hub->get_adaptor('get_SliceAdaptor')->fetch_by_region($seq_type, $seq_region, $start, $end, 1);
  my $align      = $hub->param('align');
  my $alert      = $self->check_for_align_problems({
                                'align'   => $align,
                                'species' => $species,
                                'slice'   => $slice,
                                'ignore'  => 'ancestral_sequences',
                                });
  
  $html .= $alert if $alert;
 
  # Get all slices for the gene
  my ($slices, $slice_length) = $self->object->get_slices({
                                    'slice'   => $slice, 
                                    'align'   => $align, 
                                    'species' => $species
                                });
  my ($info, @aligned_slices, %non_aligned_slices, %no_variation_slices, $ancestral_seq);

  foreach my $s (@$slices) {
    my $other_species_dbs = $species_defs->get_config($s->{'name'}, 'databases');
    my $name              = $species_defs->species_label($s->{'name'});
    
    if ($s->{'name'} eq 'ancestral_sequences') {
      $ancestral_seq = $name;
      $s->{'no_variations'} = 1;
    } else {
      $s->{'no_variations'} = $other_species_dbs && $other_species_dbs->{'DATABASE_VARIATION'} ? 0 : 1;
    }
    
    foreach (@{$s->{'underlying_slices'}}) {
      if ($_->seq_region_name ne 'GAP') {
        $s->{'no_alignment'} = 0;
        last;
      }
      
      $s->{'no_alignment'} = 1;
    }
    
    push @aligned_slices, $s if $ancestral_seq || !$s->{'no_alignment'};
    
    if ($name ne $ancestral_seq) {
      if ($s->{'no_alignment'}) {
        $non_aligned_slices{$name} = 1;
      } elsif ($s->{'no_variations'}) {
        $no_variation_slices{$name} = 1;
      }
    }
  }

  # Don't show the aligment if there is only 1 sequence (reference)
  my $align_threshold = ($ancestral_seq) ? 2 : 1;
  if (scalar(@aligned_slices) <= $align_threshold) {
    return $self->_info('No alignment', "No phylogenetic context available at this location.");
  }
 
  my $align_species = $species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}{$align}{'species'};
  my %aligned_names = map { $_->{'name'} => 1 } @aligned_slices;
  if (scalar keys %no_variation_slices) {
    $info .= sprintf(
      '<p>The following %d%s species have no variation database:</p><ul><li>%s</li></ul>',
      scalar keys %no_variation_slices,
      (scalar keys %aligned_names != scalar keys %$align_species ? ' displayed' : ''),
      join "</li>\n<li>", sort keys %no_variation_slices
    );
  } 

  $html .= $self->content_sub_slice($slice, \@aligned_slices, $defaults);

  $html .= $self->_info('Notes', $info) if $info;

  return $html;
}

sub get_export_data {
## Get data for export
  my $self = shift;
  ## Fetch explicitly, as we're probably coming from a DataExport URL
  return $self->hub->core_object('Location');
}

1;
