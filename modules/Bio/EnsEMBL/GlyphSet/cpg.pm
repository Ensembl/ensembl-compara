package Bio::EnsEMBL::GlyphSet::cpg;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;

sub init_label {
    my ($self) = @_;
	return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'CpG island',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;

    return unless ($self->strand() == -1);

    my $feature_colour = $self->{'config'}->get('cpg','col');
    my @allfeatures    = $self->{'container'}->get_all_SimilarityFeatures_above_score("cpg",25,$self->glob_bp());  
	
    foreach my $f (@allfeatures){
	my $glyph = new Bio::EnsEMBL::Glyph::Rect({
	    'x'      	=> $f->start(),
	    'y'      	=> 0,
	    'width'  	=> $f->length(),
	    'height' 	=> 8,
	    'colour' 	=> $feature_colour,
	    'absolutey' => 1,
	});
	$self->push($glyph);
    }	
}

1;
