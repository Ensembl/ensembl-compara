=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Data::Bio::AlignFeature;

### NAME: EnsEMBL::Web::Data::Bio::AlignFeature
### Base class - wrapper around Bio::EnsEMBL::DnaAlignFeature 
### or ProteinAlignFeature API object(s) 

### STATUS: Under Development
### Replacement for EnsEMBL::Web::Object::Feature

### DESCRIPTION:
### This module provides additional data-handling
### capabilities on top of those provided by the API

use strict;
use warnings;
no warnings qw(uninitialized);

use base qw(EnsEMBL::Web::Data::Bio);

sub convert_to_drawing_parameters {
### Converts a set of API objects into simple parameters 
### for use by drawing code and HTML components
  my $self = shift;
  my $data = $self->data_objects;
  my $type = $self->type;
  my $results = [];

  my @coord_systems = @{$self->coord_systems}; 
  foreach my $f (@$data) {
    if (ref($f) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($f);
      push(@$results, $unmapped);
    }
    else {
#     next unless ($f->score > 80);
      my( $region, $start, $end, $strand ) = ( $f->seq_region_name, $f->start, $f->end, $f->strand );
      if( $f->coord_system_name ne $coord_systems[0] ) {
        foreach my $system ( @coord_systems ) {
          # warn "Projecting feature to $system";
          my $slice = $f->project( $system );
          # warn @$slice;
          if( @$slice == 1 ) {
            ($region,$start,$end,$strand) = ($slice->[0][2]->seq_region_name, $slice->[0][2]->start, $slice->[0][2]->end, $slice->[0][2]->strand );
            last;
          } 
        }
      }
      push @$results, {
        'region'   => $region,
        'start'    => $start,
        'end'      => $end,
        'strand'   => $strand,
        'length'   => $f->end-$f->start+1,
        'label'    => $f->display_id." (@{[$f->hstart]}-@{[$f->hend]})",
        'gene_id'  => ["@{[$f->hstart]}-@{[$f->hend]}"],
        'extra' => { 
                    'align'   => $f->alignment_length, 
                    'ori'     => $f->hstrand * $f->strand, 
                    'id'      => $f->percent_id, 
                    'score'   => $f->score, 
                    'p-value' => $f->p_value,
                    }
      };
    } 
  }   
  my $extra_columns = [
                    {'key' => 'align',  'title' => 'Alignment length', 'sort' => 'numeric'}, 
                    {'key' => 'ori',    'title' => 'Rel ori'}, 
                    {'key' => 'id',     'title' => '%id', 'sort' => 'numeric'}, 
                    {'key' => 'score',  'title' => 'Score', 'sort' => 'numeric'}, 
                    {'key' => 'p-value', 'title' => 'p-value', 'sort' => 'numeric'},
  ];
  return [$results, $extra_columns];
}

1;
