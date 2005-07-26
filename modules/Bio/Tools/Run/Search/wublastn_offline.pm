
# Let the code begin...
package Bio::Tools::Run::Search::wublastn_offline;
use strict;
use Storable qw(dclone);

use vars qw( @ISA );
use Bio::Tools::Run::Search::wublastn;
#use Bio::Tools::Run::OfflineDispatcher;

@ISA = qw( Bio::Tools::Run::Search::wublastn );

#----------------------------------------------------------------------
sub dispatch{
  my $self = shift;
  my $pid;
  if( $pid = fork ){
    # PARENT
    return 1;
  }
  else{
    # CHILD
    $self->SUPER::dispatch(@_);
    $self->store;
    exit;
  }
}

#----------------------------------------------------------------------
1;
