package Bio::EnsEMBL::GlyphSet::marker;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Intron;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use Bump;

sub _init {
    my ($self, $VirtualContig, $Config) = @_;

    return unless ($self->strand() == -1);

    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'markers',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $self->label($label);

    my $h          = 8;
    my $highlights = $self->highlights();

    my $feature_colour 	= $Config->get($Config->script(),'marker','col');

  	foreach my $f ($VirtualContig->get_landmark_MarkerFeatures()){
		my $glyph = new Bio::EnsEMBL::Glyph::Rect({
			'x'      	=> $f->start(),
			'y'      	=> 0,
			'width'  	=> $f->length(),
			'height' 	=> $h,
			'colour' 	=> $feature_colour,
			'absolutey' => 1,
			'zmenu'     => { 'caption' => $f->id() },
		});
		$self->push($glyph);
	}	
}

1;
