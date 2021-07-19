=head1 sLICENSE

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

package EnsEMBL::Web::NewTable::Column::Integer;

use strict;
use warnings;
use parent qw(EnsEMBL::Web::NewTable::Column::Numeric);

sub js_type { return 'numeric'; }
sub js_range { return 'range'; }

sub configure {
  my ($self,$mods,$args) = @_;

  $args->{'filter_integer'} = 1 unless exists $args->{'filter_integer'};
  $self->SUPER::configure($mods,$args);
}

1;
