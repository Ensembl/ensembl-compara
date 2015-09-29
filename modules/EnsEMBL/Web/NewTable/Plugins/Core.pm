use strict;
use warnings;

package EnsEMBL::Web::NewTable::Plugins::Core;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub children { return [qw(Tabular Paragraph Loading ClientSort Types Ancient)]; }
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
sub position { return [qw(top-middle)]; }

package EnsEMBL::Web::NewTable::Plugins::ClientSort;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "new_table_clientsort"; }

package EnsEMBL::Web::NewTable::Plugins::Types;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "newtable_types"; }

package EnsEMBL::Web::NewTable::Plugins::Ancient;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "newtable_ancient"; }

1;
