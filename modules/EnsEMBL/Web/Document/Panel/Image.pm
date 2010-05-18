package EnsEMBL::Web::Document::Panel::Image;

use strict;

use base qw(EnsEMBL::Web::Document::Panel);

sub _start { $_[0]->print(qq(<div class="autocenter_wrapper"><div class="autocenter">)); }
sub _end   { $_[0]->print(qq(</div></div>)); }

1;
