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

package EnsEMBL::Web::Data::Bio::ProbeFeature;

### NAME: EnsEMBL::Web::Data::Bio::ProbeFeature
### Base class - wrapper around a Bio::EnsEMBL::ProbeFeature API object 

### STATUS: Under Development
### Replacement for EnsEMBL::Web::Object::ProbeFeature

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
  my $results = [];

  foreach my $probe_feature (@$data) {
    if (ref($probe_feature) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($probe_feature);
      push(@$results, $unmapped);
    }
    else {
      my $names = join ' ', map { /^(.*):(.*):\2/? "$1:$2" : $_ } sort @{$probe_feature->probe->get_all_complete_names()};
      foreach my $f (@{$probe_feature->probe->get_all_ProbeFeatures()}) {
        push @$results, {
          'region'   => $f->seq_region_name,
          'start'    => $f->start,
          'end'      => $f->end,
          'strand'   => $f->strand,
          'length'   => $f->end-$f->start+1,
          'label'    => $names,
          'gene_id'  => [$names],
          'extra'    => {
                        'mismatches'  => $f->mismatchcount, 
                        'cigar'       => $f->cigar_string,
          },
        };
      }
    }
  }
  my $extra_columns = [
                        {'key' => 'mismatches', 'title' => 'Mismatches'}, 
                        {'key' => 'cigar',      'title' => 'Cigar string'},
  ];
  return [$results, $extra_columns];

}

1;
