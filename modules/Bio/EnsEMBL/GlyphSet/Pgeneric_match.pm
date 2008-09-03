package Bio::EnsEMBL::GlyphSet::Pgeneric_match;
use strict;
use Data::Dumper qw( Dumper );

use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Bump;

sub _init {
    my ($self) = @_;
    my %hash;
    my @bitmap        = undef;
    my $protein       = $self->{'container'};
    my $Config        = $self->{'config'};
    my $pix_per_bp    = $Config->transform->{'scalex'};
    my $bitmap_length = int($Config->container_width() * $pix_per_bp);
    my $y             = 0;
    my $h             = 4;
    my $black         = 'black';
    my $red           = 'red';
    my $font          = "Small";
    my $colour        = $self->my_config('col') || 'black';
    my ($fontwidth,
	$fontheight)  = $Config->texthelper->px2bp($font);

    $protein->dbID || return; # Non-database translation

    my $logic_name    = $self->my_config('LOGIC_NAME'); 
    my $url_key       = $self->my_config('URL_KEY');
    my $zmenu_caption = $self->my_config('caption');
    my $compact       = $self->my_config('compact'); # For Seg/Coil etc
                                                     # No label/grouping

    my @pf_feat = @{$protein->get_all_ProteinFeatures($logic_name)};

    foreach my $feat(@pf_feat) {
	push(@{$hash{$feat->hseqname}},$feat);
    }
    foreach my $key (keys %hash) {
	my @row  = @{$hash{$key}};
	my $desc = $row[0]->idesc();
		
	my $Composite = $self->Composite({
	    'x'     => $row[0]->start(),
	    'y'     => $y,
	    'href'  => $self->ID_URL( $url_key, $key ),
            'zmenu' => {
              'caption' => $zmenu_caption,
              $key      => $self->ID_URL( $url_key, $key )
	    },
	});

	my $pfsave;
	my ($minx, $maxx);
		
	foreach my $pf (@row) {
	    my $x  = $pf->start();
	    $minx  = $x if ($x < $minx || !defined($minx));
	    my $w  = $pf->end() - $x;
	    $maxx  = $pf->end() if ($pf->end() > $maxx || !defined($maxx));
	    my $id = $pf->hseqname();

	    my $rect = $self->Rect({
		'x'        => $x,
		'y'        => $y,
		'width'    => $w,
		'height'   => $h,
		'colour'   => $colour,
	    });
	    $Composite->push($rect);
	    $pfsave = $pf;
	}

        unless( $compact ){

          # add a domain linker
          my $rect = $self->Rect({
	    'x'         => $minx,
	    'y'         => $y + 2,
	    'width'     => $maxx - $minx,
	    'height'    => 0,
	    'colour'    => $colour,
	    'absolutey' => 1,
          });
          $Composite->push($rect);
          
          # Add a feature label
          my $desc = $pfsave->idesc() || $key;
          my $text = $self->Text({
	    'font'   => $font,
	    'text'   => $desc,
	    'x'      => $row[0]->start(),
	    'y'      => $h + 1,
	    'height' => $fontheight,
	    'width'  => $fontwidth * length($desc),
	    'colour' => $black,
          });
          $Composite->push($text);
        }

	if ($self->my_config('dep') > 0){ # we bump
            my $bump_start = int($Composite->x() * $pix_per_bp);
            $bump_start = 0 if ($bump_start < 0);
			
            my $bump_end = $bump_start + int($Composite->width()*$pix_per_bp);
            if ($bump_end > $bitmap_length){$bump_end = $bitmap_length};
	my $row = & Sanger::Graphics::Bump::bump_row(
		      $bump_start,
            	      $bump_end,
		      $bitmap_length,
		      \@bitmap
           );
            $Composite->y($Composite->y() + (1.5 * $row * ($h + $fontheight)));
        }
	
	$self->push($Composite);
    }

}

1;


