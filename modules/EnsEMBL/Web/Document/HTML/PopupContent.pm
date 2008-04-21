package EnsEMBL::Web::Document::HTML::PopupContent;
use strict;

use EnsEMBL::Web::Document::HTML::Content;

our @ISA = qw(EnsEMBL::Web::Document::HTML::Content);

sub _start { $_[0]->print( qq(\n<div id="page"><div id="i3"><div id="i2">)); return 1; }
sub _end {   $_[0]->print( qq(\n<div class="sp">&nbsp;</div></div></div></div>)); }

1;

