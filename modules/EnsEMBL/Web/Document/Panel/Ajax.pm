# $Id$

package EnsEMBL::Web::Document::Panel::Ajax;

use strict;

use base qw(EnsEMBL::Web::Document::Panel);

sub content { return $_[0]->component_content; }
sub _error  { my $self = shift; return sprintf '<h1>AJAX error - %s</h1>%s', @_; }

1;
