# $Id$

package EnsEMBL::Web::Document::Page::Configurator;

use strict;
use base qw(EnsEMBL::Web::Document::Page::Popup);

sub panel_type {
  return '<input type="hidden" class="panel_type" value="Configurator" />';
}

1;
