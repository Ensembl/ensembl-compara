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

package EnsEMBL::Web::Factory::ImageExport;

### Factory for the ImageExport pages

### STATUS: Stable

### DESCRIPTION - see parent module for general description and usage

use strict;

use parent qw(EnsEMBL::Web::Factory);

sub createObjects {
### Creates an empty ImageExport object - the data to be exported
### is fetched from the individual glyphsets
  my $self = shift;
  $self->DataObjects($self->new_object('ImageExport', undef, $self->__data));
}


1;
