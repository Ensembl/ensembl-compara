package Bio::EnsEMBL::GlyphSet::cpg;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Intron;
use Bio::EnsEMBL::Glyph::Line;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use Bump;

sub _init {
    my ($self, $VirtualContig, $Config) = @_;

	return unless ($self->strand() == 1);
    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'CpG',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $self->label($label);

    my $h          = 8;
    my $highlights = $self->highlights();
    my @bitmap      	= undef;
    my $bitmap_length 	= $VirtualContig->length();
    my $feature_colour 	= $Config->get($Config->script(),'cpg','col');
    my %id = ();

    my $glob_bp = 100;
    my @allfeatures = $VirtualContig->get_all_SimilarityFeatures_above_score("cpg",25,$glob_bp);  
	
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
