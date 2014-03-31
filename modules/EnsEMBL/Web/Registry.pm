=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Registry;

use strict;

use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::Timer;

sub new {
  my $class = shift;
  
  my $self = {
    timer        => undef,
    species_defs => undef
  };
  
  bless $self, $class;
  return $self;
}

sub species_defs { return $_[0]{'species_defs'} ||= EnsEMBL::Web::SpeciesDefs->new; }
sub timer        { return $_[0]{'timer'}        ||= EnsEMBL::Web::Timer->new;       }
sub timer_push   { shift->timer->push(@_); }

1;
