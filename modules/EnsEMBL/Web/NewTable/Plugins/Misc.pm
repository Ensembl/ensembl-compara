use strict;
use warnings;

package EnsEMBL::Web::NewTable::Plugins::Misc;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub children { return [qw(Export Search Columns PageSizer Styles)]; }
sub requires { return [qw(Export Search Columns)]; }

package EnsEMBL::Web::NewTable::Plugins::Export;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "newtable_export"; }

package EnsEMBL::Web::NewTable::Plugins::Search;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "new_table_search"; }

package EnsEMBL::Web::NewTable::Plugins::Columns;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "new_table_columns"; }

package EnsEMBL::Web::NewTable::Plugins::PageSizer;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "new_table_pagesize"; }
sub js_config {
  return {
    sizes => [0,10,100],
  };
}

package EnsEMBL::Web::NewTable::Plugins::Styles;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "new_table_style"; }
sub js_config {
  return {
    styles => [["tabular","Tabular"],["paragraph","Paragraph"]]
  };
}

1;
