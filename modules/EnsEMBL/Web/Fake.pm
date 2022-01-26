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

package EnsEMBL::Web::Fake;

use strict;
## Module used by CoreObjects to create an ersatz core object for pages that aren't 
## based on an actual location, gene or transcript (e.g. the whole genome)

sub new {
  my( $class, $self ) = @_;
  bless $self, $class;
  return $self;
}

sub adaptor { return $_[0]->{'adaptor'}; }
sub type {    return $_[0]->{'type'};    }
sub view {    return $_[0]->{'view'};    }
sub stable_id { return $_[0]->{'id'};    }
sub name {    return $_[0]->{'name'};    }
sub description { return $_[0]->{'description'}; }

1;
