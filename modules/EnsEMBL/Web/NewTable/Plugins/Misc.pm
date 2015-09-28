use strict;
use warnings;

package EnsEMBL::Web::NewTable::Plugins::Misc;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub children { return [qw(Export Search Columns Styles HelpTips)]; }
sub requires { return [qw(Export Search Columns)]; }

package EnsEMBL::Web::NewTable::Plugins::Export;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "newtable_export"; }
sub position { return [qw(top-right top)]; }

package EnsEMBL::Web::NewTable::Plugins::Search;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "new_table_search"; }
sub position { return [qw(top-right)]; }

package EnsEMBL::Web::NewTable::Plugins::Columns;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "new_table_columns"; }
sub position { return [qw(top-middle)]; }

package EnsEMBL::Web::NewTable::Plugins::PageSizer;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub position { return [qw(top-left)]; }
sub js_plugin { return "new_table_pagesize"; }
sub js_config {
  return {
    %{$_[0]->SUPER::js_config()},
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

package EnsEMBL::Web::NewTable::Plugins::HelpTips;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "newtable_helptip"; }

1;
