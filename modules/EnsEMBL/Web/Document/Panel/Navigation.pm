# $Id$

package EnsEMBL::Web::Document::Panel::Navigation;

use strict;

use base qw(EnsEMBL::Web::Document::Panel);

sub _error {
  my ($self, $caption, $body) = @_;
  return "<h3>$caption</h3>$body";
}

1;
