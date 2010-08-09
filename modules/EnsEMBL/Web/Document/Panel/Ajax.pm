package EnsEMBL::Web::Document::Panel::Ajax;

use strict;

use base qw(EnsEMBL::Web::Document::Panel);

sub render { $_[0]->content; }
sub _error { shift->printf('<h1>AJAX error - %s</h1>%s', @_); }

1;
