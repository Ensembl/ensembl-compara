package Bio::EnsEMBL::GlyphSet::trna;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Intron;
use Bio::EnsEMBL::Glyph::Line;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use Bump;

sub init_label {
    my ($this) = @_;

    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'tRNA',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $this->label($label);
}

sub _init {
    my ($self) = @_;

    return unless ($self->strand() == 1);

    my $VirtualContig = $self->{'container'};
    my $Config = $self->{'config'};
    my $h          = 8;
    my $highlights = $self->highlights();
    my @bitmap      	= undef;
    my $bitmap_length 	= $VirtualContig->length();
    my $feature_colour 	= $Config->get($Config->script(),'trna','col');
    my %id = ();

    my $glob_bp = 100;
    my @allfeatures = $VirtualContig->get_all_SimilarityFeatures_above_score("tRNA",25,$glob_bp);  
	
	foreach my $f (@allfeatures){
		my $glyph = new Bio::EnsEMBL::Glyph::Rect({
			'x'      	=> $f->start(),
			'y'      	=> 0,
			'width'  	=> $f->length(),
			'height' 	=> $h,
			'colour' 	=> $feature_colour,
			'absolutey' => 1,
		});
		$self->push($glyph);
	}
	
}

1;
