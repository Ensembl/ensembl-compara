use strict;
use warnings;

package EnsEMBL::Web::NewTable::Plugins::Paging;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub children { return [qw(PagingPager)]; }
sub requires { return children(); }

package EnsEMBL::Web::NewTable::Plugins::PagingPager;
use parent qw(EnsEMBL::Web::NewTable::Plugins::Filter);

sub js_plugin { return "newtable_pager"; }
sub requires { return [qw(Paging)]; }
sub position { return [qw(top-left)]; }

sub initial { return { pagerows => [0,10] }; }
sub init { $_[0]->config->size_needed(1); }

1;
