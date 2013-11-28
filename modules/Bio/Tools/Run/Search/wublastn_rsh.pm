=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

# Extension to wublastn search method;	
# runs blast searches in the  background.
package Bio::Tools::Run::Search::wublastn_rsh;
use strict;

use vars qw( @ISA );

use Bio::Tools::Run::Search::wublastn_offline;

@ISA = qw( Bio::Tools::Run::Search::wublastn_offline );

sub dispatch{
  my $self = shift;

  #Aventis GTP Jack Hopkins 2004.02.9
  my $blast_machine = $ENV{BLAST_HOST};
  $self->warn( "BLAST_HOST not set. Using localhost" ) unless $blast_machine;
  $blast_machine ||= "localhost";

  my $rsh_command = "rsh $blast_machine @_";

  $self->SUPER::dispatch($rsh_command);
  $self->store;
}

1;

