package Bio::EnsEMBL::GlyphSet::protein;
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
	'text'      => 'Peptide',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;

    my $protein = $self->{'container'};
    my $Config  = $self->{'config'};
    my $y       = 0;
    my $h       = 4;
    my $colour  = $Config->get('protein','col');

    my $rect = new Bio::EnsEMBL::Glyph::Rect({
	'x'        => 0,
	'y'        => $y,
	'width'    => $protein->length(),
	'height'   => $h,
	'id'       => $protein->id(),
	'colour'   => $colour,
    });
    
    $self->push($rect);
}

1;




















