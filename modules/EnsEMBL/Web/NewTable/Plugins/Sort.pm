use strict;
use warnings;

package EnsEMBL::Web::NewTable::Plugins::Sort;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub children { return [qw(ClientSort ServerSort)]; }
sub requires { return children(); }

sub filter_saved {
  my ($config,$data) = @_;

  delete $data->{'sort'};
}

package EnsEMBL::Web::NewTable::Plugins::ClientSort;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "new_table_clientsort"; }

1;
