package Bio::EnsEMBL::GlyphSet::genscan;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub _init {
    my ($this, $VirtualContig, $Config) = @_;
    print STDERR qq(Bio::EnsEMBL::GlyphSet::Gene::_init\n);
    print STDERR qq(Bio::EnsEMBL::GlyphSet::Gene::length = ), $this->length(), "\n";

    #########
    # 1. get all gene objects from this vc
    # 2. create new Bio::EnsEMBL::Glyph::Rects for them
    # 3. create new Bio::EnsEMBL::Glyph::Text labels for them
    # 4. glob or bump them (step 4 or earlier?)
    # 5. keep track of x,y,width,height boundaries
    #

}
1;
