package Bio::EnsEMBL::GlyphSet::intron;
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
	'text'      => 'introns',
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
    my $key = "Intron";
    
    my $x = 0;
    my $w = 0;

    my $colour = $Config->get($Config->script(), 'intron','col');

    my @introns = $protein->each_Intron_feature();

    if (@introns) {
	my $composite = new Bio::EnsEMBL::Glyph::Composite({
	    'id'    => $key,
	    'zmenu' => {
		'caption'  => $key
		},
		});
	my $colour = $Config->get($Config->script(), 'prints','col');
	
	foreach my $int (@introns) {
	    my $x = $int->feature1->start();
	    my $w = $int->feature1->end() - $x;
	    my $id = $int->feature2->seqname();
	    
	    my $start = $int->feature2->start();
	    my $end = $int->feature2->end();

	    my $length = $end - $start;
	    
	    my $rect = new Bio::EnsEMBL::Glyph::Rect({
		'x'        => $x,
		'y'        => $y,
		'width'    => $w,
		'height'   => $h,
		'id'       => $id,
		'colour'   => $colour,
	    });
	    $composite->push($rect) if(defined $rect);
	}
	$this->push($composite);
    }
}
1;




















