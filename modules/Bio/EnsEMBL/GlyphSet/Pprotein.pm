package Bio::EnsEMBL::GlyphSet::Pprotein;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;

sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Sanger::Graphics::Glyph::Text({
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
    my $colour  = $Config->get('Pprotein','col');

    my $rect = new Sanger::Graphics::Glyph::Rect({
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




















