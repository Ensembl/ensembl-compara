package Bio::EnsEMBL::GlyphSet::prosite;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;

sub _init {
    my ($this, $protein, $Config) = @_;
    my %hash;
    my $caption = "prosite";


    my $y          = 0;
    my $h          = 4;
    my $highlights = $this->highlights();
    
   foreach my $feat ($protein->each_Protein_feature()) {
	if ($feat->feature2->seqname =~ /^PS\w+/) {
	    print STDERR "FEAT PROSITE: ".$feat->feature2->seqname, "\n";
	    push(@{$hash{$feat->feature2->seqname}},$feat);
	    
	   
	    
	}
    }
    
    foreach my $key (keys %hash) {
	
	print STDERR "VERSION11 PROSITE, prints: $key\n";

	my $Composite = new Bio::EnsEMBL::Glyph::Composite({
	    'id'    => $key,
	    'zmenu' => {
		'caption'  => $key
		},
		});
	
#To be changed
	my $colour = $Config->get($Config->script(), 'prosite','col');
	#$colour    = $Config->get('transview','transcript','hi') if(defined $highlights && $highlights =~ /\|$vgid\|/);
	
	my @row = @{$hash{$key}};

	foreach my $pr (@row) {
	    my $x = $pr->feature1->start();
	    my $w = $pr->feature1->end - $x;
	    my $id = $pr->feature1->id();
	
	    print STDERR "Y: $y\n";
    
	    my $rect = new Bio::EnsEMBL::Glyph::Rect({
		'x'        => $x,
		'y'        => $y,
		'width'    => $w,
		'height'   => $h,
		'id'       => $id,
		'colour'   => $colour,
		'zmenu' => {
		    'caption' => $caption,
		},
	    });
	    
	    
	    $Composite->push($rect) if(defined $rect);

	    
	}
#	push @{$this->{'glyphs'}}, $Composite;
	$this->push($Composite);
	$y = $y + 8;
    }
    
}

1;
