package Bio::EnsEMBL::GlyphSet::marker;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Intron;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use Bump;

sub init_label {
    my ($this) = @_;

    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'Markers',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $this->label($label);
}

sub _init {
    my ($self) = @_;

    return unless ($self->strand() == -1);

    my $VirtualContig = $self->{'container'};
    my $Config = $self->{'config'};

    my $h          = 8;
    if ($Config->script() eq "contigviewtop"){ $h =4;}

    my $highlights = $self->highlights();

    my $feature_colour 	= $Config->get($Config->script(),'marker','col');

  	foreach my $f ($VirtualContig->get_landmark_MarkerFeatures()){
		my $fid = $f->id();
		my $glyph = new Bio::EnsEMBL::Glyph::Rect({
			'x'      	=> $f->start(),
			'y'      	=> 0,
			'width'  	=> $f->length(),
			'height' 	=> $h,
			'colour' 	=> $feature_colour,
			'absolutey' => 1,
			'zmenu'     => { 
				'caption' => $fid,
				'Marker info' => "/perl/markerview?marker=$fid",
			},
		});
		$self->push($glyph);
	}	
}

1;
