# $Id$

package EnsEMBL::Web::Document::Configurator;

use strict;
use base qw(EnsEMBL::Web::Document::Popup);

sub panel_type {
  return '<input type="hidden" class="panel_type" value="Configurator" />';
}

1;
