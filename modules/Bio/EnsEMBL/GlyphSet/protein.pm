package Bio::EnsEMBL::GlyphSet::protein;
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
    
    my $y          = 0;
    my $h          = 8;
    my $highlights = $this->highlights();
   
#Draw the protein
    my $length = $protein->length();

    my $xp = 0;
    my $wp = $lenght;
	
    my $rect = new Bio::EnsEMBL::Glyph::Rect({
			'x'        => $xp,
			'y'        => $y,
			'widtph'    => $wp,
			'height'   => $h,
			'id'       => $protein->id(),
			'colour'   => $colour,
			'zmenu' => {
			    'caption' => $protein->id(),
			},
		    });
    
    push @{$this->{'glyphs'}}, $Composite;
    $y+=$h;

    my @pfam;
    my @prints;
    my @prosite;
    my @pf;


#Draw each features
    foreach my $feat ($protein->each_Protein_feature()) {
	if ($feat->hdbname =~ /^PF\w+/) {
	    push (@pfam,$feat);
	}

	if ($feat->hdbname =~ /^PR\w+/) {
	    push (@prints,$feat);
	}

	if ($feat->hdbname =~ /^PS\w+/) {
	    push (@prosite,$feat);
	}

	my @features = ("Pfam","PRINTS","PROSITE");

	foreach my $ft(@features) {
	    if ($ft eq "Pfam") {
		@pf = @pfam;
	    }

	    if ($ft eq "PRINTS") {
		@pf = @prints;
	    }
	    
	    if ($ft eq "PROSITE") {
		@pf = @prosite;
	    }
	    
	    if (@pf) {
      	    
		my $Composite = new Bio::EnsEMBL::Glyph::Composite({
		    'id'    => $feat->hdbname(),
		    'zmenu' => {
			'caption'  => $feat->hdbname(),
			'01:kung'     => 'opt1',
			'02:foo'      => 'opt2',
			'03:fighting' => 'opt3'
			},
			});
		
	    #########
		# set colour for transcripts and test if we're highlighted or not
		# 
		
#Do some changes here...
		my $colour = $Config->get('transview','transcript','col');
		$colour    = $Config->get('transview','transcript','hi') if(defined $highlights && $highlights =~ /\|$vgid\|/);
		
		

		foreach my $pf (@pfam) {
		    my $x = $feat->feature1->start();
		    my $w = $feat->feature1->end - $x;
		    
		    my $rect = new Bio::EnsEMBL::Glyph::Rect({
			'x'        => $x,
			'y'        => $y,
			'width'    => $w,
			'height'   => $h,
			'id'       => $exon->id(),
			'colour'   => $colour,
			'zmenu' => {
			    'caption' => $feat->seqname->id(),
			},
		    });
		    
		    
		    $Composite->push($rect) if(defined $rect);
		
		}
		#########
		# replace this with bumping!
		#
		push @{$this->{'glyphs'}}, $Composite;
		$y+=$h;
	    }
	    
	}
    }
}
1;






















