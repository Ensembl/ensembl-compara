package Bio::EnsEMBL::GlyphSet::pfam;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use ColourMap;
use Bump;

sub init_label {
    my ($this) = @_;

    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'Pfam',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $this->label($label);
}

sub _init {
    my ($this) = @_;
    my %hash;
    my $caption         = "Pfam";
    my @bitmap         	= undef;
    my $protein         = $this->{'container'};
    my $Config          = $this->{'config'};
    my $pix_per_bp  	= $Config->transform->{'scalex'};
    my $bitmap_length 	= int($this->{'container'}->length * $pix_per_bp);
    my $y               = 0;
    my $h               = 4;
    my $cmap            = new ColourMap;
    my $black           = $cmap->id_by_name('black');
    my $red             = $cmap->id_by_name('red');
    my $font            = "Small";
    my $colour          = $Config->get($Config->script(), 'pfam','col');
    my ($fontwidth,
	$fontheight)    = $Config->texthelper->px2bp($font);

    foreach my $feat ($protein->each_Protein_feature()) {
       if ($feat->feature2->seqname =~ /^PF\w+/) {
	   push(@{$hash{$feat->feature2->seqname}},$feat);
       }
    }
    
    foreach my $key (keys %hash) {
	my @row  = @{$hash{$key}};
	my $desc = $row[0]->idesc();
		
	my $Composite = new Bio::EnsEMBL::Glyph::Composite({
	    'x'     => $row[0]->feature1->start(),
	    'y'     => $y,
	    'zmenu' => {
		'caption' => "Pfam domain",
		$key      => "http://www.sanger.ac.uk/cgi-bin/Pfam/getacc?$key"
	    },
	});

	my $pfsave;
	my ($minx, $maxx);
		
	foreach my $pf (@row) {
	    my $x  = $pf->feature1->start();
	    $minx  = $x if ($x < $minx || !defined($minx));
	    my $w  = $pf->feature1->end() - $x;
	    $maxx  = $pf->feature1->end() if ($pf->feature1->end() > $maxx || !defined($maxx));
	    my $id = $pf->feature2->seqname();

	    my $rect = new Bio::EnsEMBL::Glyph::Rect({
		'x'        => $x,
		'y'        => $y,
		'width'    => $w,
		'height'   => $h,
		'colour'   => $colour,
	    });
	    $Composite->push($rect);
	    $pfsave = $pf;
	}

	#########
	# add a domain linker
	#
	my $rect = new Bio::EnsEMBL::Glyph::Rect({
	    'x'         => $minx,
	    'y'         => $y + 2,
	    'width'     => $maxx - $minx,
	    'height'    => 0,
	    'colour'    => $colour,
	    'absolutey' => 1,
	});
	$Composite->push($rect);

	my $desc = $pfsave->idesc();
	my $len = length($desc) + 1;
	my $text = new Bio::EnsEMBL::Glyph::Text({
	    'font'   => $font,
	    'text'   => $desc,
	    'x'      => $row[0]->feature1->start(),
	    'y'      => $h + 1,
	    'height' => $fontheight,
	    'width'  => $fontwidth * $len * 1.1,
	    'colour' => $black,
	});
	$Composite->push($text);
	
	if ($Config->get($Config->script(), 'pfam', 'dep') > 0){ # we bump
            my $bump_start = int($Composite->x() * $pix_per_bp);
            $bump_start = 0 if ($bump_start < 0);
	    
            my $bump_end = $bump_start + int($Composite->width()*$pix_per_bp);
            if ($bump_end > $bitmap_length){$bump_end = $bitmap_length};
            my $row = &Bump::bump_row(      
				      $bump_start,
				      $bump_end,
				      $bitmap_length,
				      \@bitmap
				      );
            $Composite->y($Composite->y() + (1.5 * $row * ($h + $fontheight)));
        }
	
	$this->push($Composite);
    }

}

1;


