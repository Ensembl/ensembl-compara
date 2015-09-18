use strict;
use warnings;

package EnsEMBL::Web::NewTable::Plugins::Decorate;

sub children { return [qw(DecorateIconic DecorateLink DecorateEditorial
                          DecorateAlso DecorateToggle)]; }
sub requires { return children(); }
sub js_plugin { return "newtable_decorate"; }

use parent qw(EnsEMBL::Web::NewTable::Plugin);

package EnsEMBL::Web::NewTable::Plugins::DecorateIconic;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "newtable_decorate_iconic"; }
sub requires { return [qw(Decorate)]; }

package EnsEMBL::Web::NewTable::Plugins::DecorateLink;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "newtable_decorate_link"; }
sub requires { return [qw(Decorate)]; }

package EnsEMBL::Web::NewTable::Plugins::DecorateEditorial;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "newtable_decorate_editorial"; }
sub requires { return [qw(Decorate)]; }

package EnsEMBL::Web::NewTable::Plugins::DecorateAlso;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "newtable_decorate_also"; }
sub requires { return [qw(Decorate)]; }

package EnsEMBL::Web::NewTable::Plugins::DecorateToggle;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "newtable_decorate_toggle"; }
sub requires { return [qw(Decorate)]; }

1;
