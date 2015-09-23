use strict;
use warnings;

package EnsEMBL::Web::NewTable::Plugins::Filter;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub children { return [qw(FilterClass FilterRange)]; }
sub requires { return [@{children()},'Types']; }
sub js_plugin { return "new_table_filter"; }
sub position{ return [qw(top-full-inner)]; }

package EnsEMBL::Web::NewTable::Plugins::FilterClass;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "newtable_filter_class"; }
sub requires { return [qw(Filter)]; }
sub for_types {
  return {
    class => [qw(string html iconic)],
  };
}

package EnsEMBL::Web::NewTable::Plugins::FilterRange;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "newtable_filter_range"; }
sub requires { return [qw(Filter)]; }
sub for_types {
  return {
    range => [qw(numeric integer)],
    position => [qw(position)],
  };
}

1;
