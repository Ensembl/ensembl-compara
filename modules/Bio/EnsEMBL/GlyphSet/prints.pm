package Bio::EnsEMBL::GlyphSet::prints;
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
	'text'      => 'prints',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $this->label($label);
}

sub _init {
    my ($this) = @_;
    my %hash = undef;
    my $caption = "prints";

    my $protein = $this->{'container'};
    my $Config = $this->{'config'};

    my $y          = 0;
    my $h          = 4;
    my $highlights = $this->highlights();
    
    
    foreach my $feat ($protein->each_Protein_feature()) {
	if ($feat->feature2->seqname =~ /^PR\w+/) {
	    push(@{$hash{$feat->feature2->seqname}},$feat);
	    
	   
	    
	}
    }
    
    foreach my $key (keys %hash) {
       
	my @row = @{$hash{$key}};
       
     
	my $desc = $row[0]->idesc();

	my $colour = $Config->get($Config->script(), 'prints','col');

	my $Composite = new Bio::EnsEMBL::Glyph::Composite({
	    'id'    => $key,
	    'zmenu' => {
		'caption'  => $key,
		$desc => '',
	    },
	    'bordercolour' => $colour,
	});

	my $prsave;
	foreach my $pr (@row) {
	    my $x = $pr->feature1->start();
	    my $w = $pr->feature1->end() - $x;
	    my $id = $pr->feature2->seqname();
	    
	    my $rect = new Bio::EnsEMBL::Glyph::Rect({
		'x'        => $x,
		'y'        => $y,
		'width'    => $w,
		'height'   => $h,
		'id'       => $id,
		'colour'   => $colour,
#		'zmenu' => {
#		    'caption' => $id,
#		},
	    });
	    
	    
	    $Composite->push($rect) if(defined $rect);
	    $prsave = $pr;
	}

	#########
	# add a label
	#
	my $font = "Small";
	my $text = new Bio::EnsEMBL::Glyph::Text({
	    'font'   => $font,
	    'text'   => $prsave->idesc,
	    'x'      => $row[0]->feature1->start(),
	    'y'      => $h,
	    'height' => $Config->texthelper->height($font),
	    'colour' => $colour,
	});

	$this->push($text);

	$this->push($Composite);
	$y = $y + 8;
    }
    
}

1;
