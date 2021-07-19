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

package EnsEMBL::Web::Component::Transcript;

use strict;

use base qw(EnsEMBL::Web::Component::Shared);

## No sub stable_id   <- uses Gene's stable_id
## No sub name        <- uses Gene's name
## No sub description <- uses Gene's description
## No sub location    <- uses Gene's location call

sub non_coding_error {
  my $self = shift;
  return $self->_error('No protein product', '<p>This transcript does not have a protein product</p>');
}

sub get_export_data {
## Get data for export
  my $self = shift;
  my $hub  = $self->hub;
  ## Fetch transcript explicitly, as we're probably coming from a DataExport URL
  my $transcript;
  if ($hub->param('data_type') eq 'LRG') {
    my $object = $self->builder->object('LRG');
    $transcript = $object->get_transcript;
  }
  else {
    $transcript = $hub->core_object('transcript');
  }
  return $transcript->Obj;
}

1;

