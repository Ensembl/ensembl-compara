package Bio::EnsEMBL::GlyphSet::_ditag;

use strict;
use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_helplink    { return $_[0]->my_config('helplink') || "markers"; }

1;
