package Bio::EnsEMBL::GlyphSet::prints;
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
    my %hash = undef;
    my $caption = "prints";

    my $y          = 0;
    my $h          = 4;
    my $highlights = $this->highlights();
    
    
    foreach my $feat ($protein->each_Protein_feature()) {
	if ($feat->feature2->seqname =~ /^PR\w+/) {
	    #print STDERR "FEAT: ".$feat->feature2->seqname, "\n";
	    push(@{$hash{$feat->feature2->seqname}},$feat);
	    
	   
	    
	}
    }
    
    foreach my $key (keys %hash) {
       
	my @row = @{$hash{$key}};
       
     
	my $desc = $row[0]->idesc();

	my $Composite = new Bio::EnsEMBL::Glyph::Composite({
	    'id'    => $key,
	    'zmenu' => {
		'caption'  => $key,
		$desc => '',
	    },
	});
	my $colour = $Config->get($Config->script(), 'prints','col');
	

#To be changed
	
	#colour    = $Config->get('transview','transcript','hi') if(defined $highlights && $highlights =~ /\|$vgid\|/);
	
	

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
		'zmenu' => {
		    'caption' => $id,
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
