package EnsEMBL::Web::Document::Panel::Image;

use strict;
use EnsEMBL::Web::Document::Panel;
use Data::Dumper qw(Dumper);

@EnsEMBL::Web::Document::Panel::Image::ISA = qw(EnsEMBL::Web::Document::Panel);

sub _start { $_[0]->print(qq(<div class="autocenter">)); }
sub _end   { $_[0]->print(qq(</div>)); }


1;
