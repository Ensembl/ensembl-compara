package GlyphSet::genscan;
use strict;
use vars qw(@ISA);
use lib "..";
use GlyphSet;
@ISA = qw(GlyphSet);

sub _init {
    my ($this, $VirtualContig, $Config) = @_;
    print STDERR qq(GlyphSet::Gene::_init\n);
    print STDERR qq(GlyphSet::Gene::length = ), $this->length(), "\n";

    #########
    # 1. get all gene objects from this vc
    # 2. create new Glyph::Rects for them
    # 3. create new Glyph::Text labels for them
    # 4. glob or bump them (step 4 or earlier?)
    # 5. keep track of x,y,width,height boundaries
    #

}
1;
