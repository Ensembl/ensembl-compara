use strict;
use warnings;

package EnsEMBL::Web::NewTable::Plugins::Filter;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub children { return [qw(FilterClass FilterRange FilterEnum)]; }
sub requires { return children(); }
sub js_plugin { return "new_table_filter"; }

package EnsEMBL::Web::NewTable::Plugins::FilterClass;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "newtable_filter_class"; }
sub requires { return [qw(Filter)]; }

package EnsEMBL::Web::NewTable::Plugins::FilterRange;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "newtable_filter_range"; }
sub requires { return [qw(Filter)]; }

package EnsEMBL::Web::NewTable::Plugins::FilterEnum;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "newtable_filter_enumclient"; }
sub requires { return [qw(Filter)]; }

1;
