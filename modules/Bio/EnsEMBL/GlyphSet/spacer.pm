package Bio::EnsEMBL::GlyphSet::spacer;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Space;
use Sanger::Graphics::Glyph::Rect;

sub _init {
    my ($self) = @_;
    my $Config      = $self->{'config'};
    my $height  = $Config->get('spacer','height') || 20; # In Kbases...
#    $self->push( new Sanger::Graphics::Glyph::Rect({
#        'x'      	=> 0,
#   	'y'      	=> $height/2,
#   	'width'  	=> $Config->container_width()+1,
#    	'height' 	=> 0,
#        'colour'         => 'background0',
#    	'absolutey' => 1,
#    	'absolutex' => 1,
#        'z' => -99999,
#    }));
    $self->push( new Sanger::Graphics::Glyph::Space({
        'x'      	=> 1,
   	'y'      	=> 0,
   	'width'  	=> 1,
    	'height' 	=> $height,
    	'absolutey' => 1,
    	'absolutex' => 1,
    }));
}
1;
