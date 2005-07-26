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

