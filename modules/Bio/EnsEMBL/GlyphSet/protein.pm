package Bio::EnsEMBL::GlyphSet::protein;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;

sub init_label {
    my ($this) = @_;

    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'Peptide',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $this->label($label);
}

sub _init {
    my ($this) = @_;

    my $protein = $this->{'container'};
    my $Config = $this->{'config'};

    my $y          = 0;
    my $h          = 4;
   
    my $colour = $Config->get($Config->script(), 'protein','col');

    my $rect = new Bio::EnsEMBL::Glyph::Rect({
			'x'        => 0,
			'y'        => $y,
			'width'    => $protein->length(),
			'height'   => $h,
			'id'       => $protein->id(),
			'colour'   => $colour,
	});
    
    $this->push($rect);
    
   
}
1;




















