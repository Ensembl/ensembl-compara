package Bio::EnsEMBL::GlyphSet::protein;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Intron;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;

sub _init {
    my ($this, $protein, $Config) = @_;

    my $y          = 0;
    my $h          = 8;
    my $highlights = $this->highlights();
   
    my $protid = $protein->id();
    
    
    my $Composite = new Bio::EnsEMBL::Glyph::Composite({
	'id'    => $protein->id(),
	'zmenu' => {
	'caption'  => $protein->id(),
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


#Fetch here by signature id, get all pfam,... For each kind of signature, create a Glyph composite. 
	    FEATURE: foreach my $feat ($protein->each_Protein_feature()) {
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

1;






















