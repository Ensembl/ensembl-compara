package Bio::EnsEMBL::GlyphSet::intron;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;

sub init_label {
    my ($self) = @_;

    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'introns',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;

    my $protein = $self->{'container'};
    my $Config = $self->{'config'}; 
    
    my $y          = 0;
    my $h          = 4;
    my $highlights = $self->highlights();
    my $key = "Intron";
    
    my $x = 0;
    my $w = 0;

    my $colour = $Config->get( 'intron','col');

    my @introns = $protein->each_Intron_feature();

    if (@introns) {
	my $composite = new Bio::EnsEMBL::Glyph::Composite({
	    'id'    => $key,
	    'zmenu' => {
		'caption'  => $key,
	    },
	});
	my $colour = $Config->get( 'prints','col');
	
	foreach my $int (@introns) {
	    my $x      = $int->feature1->start();
	    my $w      = $int->feature1->end() - $x;
	    my $id     = $int->feature2->seqname();
	    my $start  = $int->feature2->start();
	    my $end    = $int->feature2->end();
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
	$self->push($composite);
    }
}
1;




















