package Bio::EnsEMBL::GlyphSet::protein;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;

sub init_label {
    my ($this) = @_;

    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'protein',
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
    my $highlights = $this->highlights();
   
#Draw the protein
    my $length = $protein->length();

    my $xp = 0;
    my $wp = $length;

    print STDERR "PROT VERSION001\n";

   
    my $colour = $Config->get($Config->script(), 'protein','col');

    my $rect = new Bio::EnsEMBL::Glyph::Rect({
			'x'        => $xp,
			'y'        => $y,
			'width'    => $wp,
			'height'   => $h,
			'id'       => $protein->id(),
			'colour'   => $colour,
			'zmenu' => {
			    'caption' => $protein->id(),
			},
		    });
    
#    push @{$this->{'glyphs'}}, $rect;   
    $this->push($rect);
    
   
}
1;




















