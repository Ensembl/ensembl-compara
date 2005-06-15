package Bio::EnsEMBL::GlyphSet::missing;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub init_label {
    return;
}

sub _init {
    my ($self) = @_;
    return unless ($self->strand() == -1);
    my $tracks   = $self->{'config'}->{'missing_tracks'};
    my ($w,$h)   = $self->{'config'}->texthelper()->real_px2bp('Tiny');
    my ($w2,$h2) = $self->{'config'}->texthelper()->real_px2bp('Small');
    $self->push( new Sanger::Graphics::Glyph::Text({
        'x'         => 1, 
        'y'         => int( ($h2-$h)/2 ),
        'height'    => $h2,
        'font'      => 'Tiny',
        'colour'    => 'black',
        'text'      => 
	    $tracks == 0 ? "All tracks are currently switched on" : (
		$tracks == 1 ?
		"There is currently 1 track switched off, use the menus above the image to turn this on." :
		"There are currently $tracks tracks switched off, use the menus above the image to turn these on."
        ),
        'absolutey' => 1,
    }) );
}

1;
        
