package Bio::EnsEMBL::GlyphSet::protein;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;

sub _init {
    my ($this, $protein, $Config) = @_;
    
    my $y          = 0;
    my $h          = 8;
    my $highlights = $this->highlights();
   
#Draw the protein
    my $length = $protein->length();

    my $xp = 0;
    my $wp = $lenght;
	
    my $rect = new Bio::EnsEMBL::Glyph::Rect({
			'x'        => $xp,
			'y'        => $y,
			'widtph'    => $wp,
			'height'   => $h,
			'id'       => $protein->id(),
			'colour'   => $colour,
			'zmenu' => {
			    'caption' => $protein->id(),
			},
		    });
    
    push @{$this->{'glyphs'}}, $rect;
    
}
1;






















