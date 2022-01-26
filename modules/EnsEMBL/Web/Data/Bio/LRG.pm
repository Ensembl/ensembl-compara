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

package EnsEMBL::Web::Data::Bio::LRG;

### NAME: EnsEMBL::Web::Data::Bio::LRG
### Wrapper around a hashref containing two Bio::EnsEMBL:: objects, one on
### LRG coordinates and one on standard Ensembl chromosomal coordinates 

### STATUS: Under Development

### DESCRIPTION:
### This module and its children provide additional data-handling
### capabilities on top of those provided by the API

use strict;
use warnings;
no warnings qw(uninitialized);

use base qw(EnsEMBL::Web::Data::Bio);

sub convert_to_drawing_parameters {
  my $self = shift;
  my $data = $self->data_objects;
  my $results = [];
  my $prev_lrg = 0;
  my $tmp_row;

  foreach my $slice_pair (@$data) {
    my $lrg = $slice_pair->{'lrg'};
    my $chr = $slice_pair->{'chr'};
    
    # get the strand by projecting to lrg coord system
    my %strands;    
    foreach my $segment(@{$chr->project('lrg')}) {
      my $sl = $segment->to_Slice;
      next unless $sl->seq_region_name eq $lrg->seq_region_name;      
      $strands{$sl->strand} = 1;
    }
    
    # get the LRG's HGNC name
    my $lrg_sr_name = $lrg->seq_region_name;
    my $gene = (grep $_->stable_id eq $lrg_sr_name, @{$lrg->get_all_Genes_by_type('LRG_gene')})[0];
    next unless $gene;
    my $hgnc_name = $gene->display_xref->display_id();

    if (ref($lrg) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($lrg);
      push(@$results, $unmapped);
    }
    
    else {
      (my $lrg_number = $lrg_sr_name) =~ s/^LRG_//i;
      
      if($lrg_sr_name ne $prev_lrg) {
        push @$results, $tmp_row if defined $tmp_row;
        
        $tmp_row = {
          'lrg_name'    => $lrg_sr_name,
          'lrg_number'  => $lrg_number,
          'lrg_start'   => $lrg->start,
          'lrg_end'     => $lrg->end,
          'region'      => $chr->seq_region_name,
          'start'       => $chr->start,
          'end'         => $chr->end,
          'strand'      => (scalar keys %strands > 1 ? "mixed" : (keys %strands)[0]),
          'length'      => $lrg->seq_region_length,
          'label'       => $chr->name,
          'hgnc_name'   => $hgnc_name,
        };
      }
      
      else {
        $tmp_row->{lrg_start} = $lrg->start if $lrg->start < $tmp_row->{lrg_start};
        $tmp_row->{lrg_end}   = $lrg->end if $lrg->end > $tmp_row->{lrg_end};
        $tmp_row->{start}     = $chr->start if $chr->start < $tmp_row->{start};
        $tmp_row->{end}       = $chr->end if $chr->end > $tmp_row->{end};
      }
    }
    
    $prev_lrg = $lrg_sr_name;
  }
  
  push @$results, $tmp_row if $tmp_row;

  return [$results, []];
}

1;
