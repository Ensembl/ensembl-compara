package Bio::EnsEMBL::GlyphSet::superfamily;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use Bump;

sub init_label {
    my ($self) = @_;
	return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'SCOP Superfamily',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;
    my %hash;
    my $y             = 0;
    my $h             = 4;
    my @bitmap        = undef;
    my $protein       = $self->{'container'};
    my $Config        = $self->{'config'};
    my $pix_per_bp    = $Config->transform->{'scalex'};
    my $bitmap_length = int($protein->length() * $pix_per_bp);
    my $colour        = $Config->get('superfamily','col');
    my $font          = "Small";
    my ($fontwidth, $fontheight)  = $Config->texthelper->real_px2bp($font);

    my @ps_feat = $protein->get_all_SuperfamilyFeatures();
    foreach my $feat(@ps_feat) {
	print STDERR $feat;
	push(@{$hash{$feat->feature2->seqname}},$feat);
    }
    
    my $PID = $self->{'container'}->id;
    foreach my $key (keys %hash) {
	my @row = @{$hash{$key}};
       	my $desc = $row[0]->idesc();
        my $KK = substr($key,-7);
	my $Composite = new Bio::EnsEMBL::Glyph::Composite({
	    'x' => $row[0]->feature1->start(),
	    'y' => 0,
	    'zmenu' => {
		'caption' => "Super family",
		"SCOP: $KK" => "http://scop.mrc-lmb.cam.ac.uk/scop/search.cgi?sid=$KK&tlev=sf"
	    },
	});

	my @row = @{$hash{$key}};

	my $prsave;
	my ($minx, $maxx);

	foreach my $pr (@row) {
	    my $x  = $pr->feature1->start();
	    $minx  = $x if ($x < $minx || !defined($minx));
	    my $w  = $pr->feature1->end() - $x;
	    $maxx  = $pr->feature1->end() if ($pr->feature1->end() > $maxx || !defined($maxx));
	    my $id = $pr->feature2->seqname();
	    
	    my $rect = new Bio::EnsEMBL::Glyph::Rect({
		'x'        => $x,
		'y'        => $y,
		'width'    => $w,
		'height'   => $h,
		'colour'   => $colour,
	    });
			
	    $Composite->push($rect);
	    $prsave = $pr;
	}

	#########
	# add a domain linker
	#
	my $rect = new Bio::EnsEMBL::Glyph::Rect({
	    'x'        => $minx,
	    'y'        => $y + 2,
	    'width'    => $maxx - $minx,
	    'height'   => 0,
	    'colour'   => $colour,
	    'absolutey' => 1,
	});
	$Composite->push($rect);

	#########
	# add a label
	#
#	my $desc = $prsave->id();
#        print STDERR "$fontwidth\n";
#	my $text = new Bio::EnsEMBL::Glyph::Text({
#	    'font'   => $font,
#	    'text'   => $desc,
#	    'x'      => $row[0]->feature1->start(),
#	    'y'      => $h + 1,
#	    'height' => $fontheight,
#	    'width'  => $fontwidth * length($desc),
#	    'colour' => $colour,
#            'absolutey' => 1
#	});
#	$Composite->push($text);

	if ($Config->get('superfamily', 'dep') > 0){ # we bump
            my $bump_start = int($Composite->x() * $pix_per_bp);
            $bump_start = 0 if ($bump_start < 0);

            my $bump_end = $bump_start + int($Composite->width() * $pix_per_bp);
            print STDERR "BUMP: $bump_start $bump_end\n";
            print STDERR "XX: ".$Composite->width()." - $pix_per_bp\n";
            if ($bump_end > $bitmap_length){$bump_end = $bitmap_length};
            my $row = &Bump::bump_row(      
				      $bump_start,
				      $bump_end,
				      $bitmap_length,
				      \@bitmap
            );
            #$Composite->y($Composite->y() + (1.5 * $row * ($h + $fontheight)));
            $Composite->y($Composite->y() + (2 * $row * ($h )));
        }
	
	$self->push($Composite);
    }
}

1;
