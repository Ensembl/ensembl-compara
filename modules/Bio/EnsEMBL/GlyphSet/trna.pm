package Bio::EnsEMBL::GlyphSet::trna;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;

sub init_label {
    my ($self) = @_;

    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'tRNA',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;

    return unless ($self->strand() == 1);

    my $VirtualContig  = $self->{'container'};
    my $Config         = $self->{'config'};
    my $h              = 8;
    my $highlights     = $self->highlights();
    my $feature_colour = $Config->get('trna','col');

    my @allfeatures = $VirtualContig->get_all_SimilarityFeatures_above_score("tRNA",25,$self->glob_bp());  
    
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
