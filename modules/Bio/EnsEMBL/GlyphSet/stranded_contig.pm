package Bio::EnsEMBL::GlyphSet::stranded_contig;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::contig;
@ISA = qw(Bio::EnsEMBL::GlyphSet::contig);
use Bio::EnsEMBL::Glyph::Poly;


## We inherit from normal strand-agnostic contig module
## but add arrows when we want to draw in stranded form.
 
sub add_arrows {   
    my ($self, $im_width, $black, $ystart) = @_;
    my $gtriag;    
    
    $gtriag = new Bio::EnsEMBL::Glyph::Poly({
	'points'       => [$im_width-10,$ystart-4, $im_width-10,$ystart, $im_width,$ystart],
	'colour'       => $black,
	'absolutex'    => 1,
	'absolutey'    => 1,
    });
    
    $self->push($gtriag);
    $gtriag = new Bio::EnsEMBL::Glyph::Poly({
	'points'       => [0,$ystart+14, 10,$ystart+14, 10,$ystart+18],
	'colour'       => $black,
	'absolutex'    => 1,
	'absolutey'    => 1,
    });
    $self->push($gtriag);
 }   


1;
