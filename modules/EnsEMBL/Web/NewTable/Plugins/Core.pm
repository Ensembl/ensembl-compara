use strict;
use warnings;

package EnsEMBL::Web::NewTable::Plugins::Core;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub children { return [qw(Tabular Paragraph Loading ClientSort)]; }
sub requires { return children(); }

package EnsEMBL::Web::NewTable::Plugins::Tabular;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "new_table_tabular"; }

package EnsEMBL::Web::NewTable::Plugins::Paragraph;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "new_table_paragraph"; }

package EnsEMBL::Web::NewTable::Plugins::Loading;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "new_table_loading"; }

package EnsEMBL::Web::NewTable::Plugins::ClientSort;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "new_table_clientsort"; }

1;
