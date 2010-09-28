# $Id$

package EnsEMBL::Web::Document::Panel::Image;

use strict;

use base qw(EnsEMBL::Web::Document::Panel);

sub _start { return '<div class="autocenter_wrapper"><div class="autocenter">'; }
sub _end   { return '</div></div>'; }

1;
