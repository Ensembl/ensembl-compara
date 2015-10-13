use strict;
use warnings;

package EnsEMBL::Web::NewTable::Plugins::Frame;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub children { return [qw(FrameDefault)]; }
sub requires { return children(); }

package EnsEMBL::Web::NewTable::Plugins::FrameDefault;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub js_plugin { return "newtable_frame_default"; }

1;
