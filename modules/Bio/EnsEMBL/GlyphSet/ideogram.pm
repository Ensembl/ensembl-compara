package Bio::EnsEMBL::GlyphSet::ideogram;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

my %SHORT = qw(
  chromosome Chr.
  supercontig S'ctg
);

sub _init {
  my ($self) = @_;

  #########
  # only draw contigs once - on one strand
  #
  my $col    = undef;
  my $white  = 'white';
  my $black  = 'black';
  my $red    = 'red';

  
  my $im_width = $self->image_width();
  my $chr      = $self->{'container'}->seq_region_name();
  my $len      = $self->{'container'}->length();

  # fetch the chromosome bands that cover this VC.
  my $bands    = $self->{'container'}->adaptor()->db()->get_KaryotypeBandAdaptor()->fetch_all_by_chr_name($chr);
  my $chr_length  = $self->{'container'}->length();
  
  # get rid of div by zero...
  $chr_length ||= 1;

  # over come a bottom border/margin problem....
  $self->push($self->Rect({
    'x'            => 1,
    'y'            => 0,
    'width'        => 1,
    'height'       => 20,
    'bordercolour' => $white,
    'absolutey'    => 1,
  }));
    
  my $done_one_acen = 0;      # flag for tracking place in chromsome

  my( $fontname, $fontsize ) = $self->get_font_details( 'innertext' );
  my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my $h = $res[3];
  my $pix_per_bp = $self->scalex;

  my @bands =  sort{$a->start <=> $b->start } @$bands;
  my @t_stains = qw(gpos25 gpos75);
  if(@bands) {
    $done_one_acen = 1 if @bands>1 && lc($bands[0]->stain) eq 'acen' && lc($bands[1]->stain) ne 'acen';
    foreach my $band (@bands){
      my $bandname       = $band->name();
      my $vc_band_start  = $band->start();
      my $vc_band_end    = $band->end();
      my $stain          = lc($band->stain());
      push @t_stains, $stain = shift @t_stains unless $stain;

#  print STDERR "$chr band:$bandname stain:$stain start:$vc_band_start end:$vc_band_end\n";    
      my $colour = $self->my_colour( $stain );
      if ($stain eq "acen"){ ## Two centromeres - link together to make a bowtie...
        my $points = $done_one_acen
                   ? [ $vc_band_start-1, 2+($h+2)/2, $vc_band_end, 2, $vc_band_end,   2+$h+2 ]
                   : [ $vc_band_start-1, 2, $vc_band_end, 2+($h+2)/2, $vc_band_start, 2+$h+2 ]
                   ;
        $done_one_acen = 1 - $done_one_acen;
        $self->push($self->Poly({
          'points'       => $points,
          'colour'       => $colour,
          'absolutey'    => 1
        }));
      } elsif ($stain eq "stalk"){ ## Is a bow-tie with a box in the middle...
        $self->push($self->Poly({
          'points'    => [ $vc_band_start-1,2, 
            $vc_band_end,4+$h,
            $vc_band_end,2,
            $vc_band_start-1,4+$h, 
          ],
          'colour'    => $colour,
          'absolutey' => 1,
        }));
        $self->push($self->Rect({
          'x'         => $vc_band_start-1,
          'y'         => ($h+2)/4 + 2,
          'width'     => $vc_band_end - $vc_band_start + 1,
          'height'    => ($h+2)/2 - 1,
          'colour'    => $colour,
          'absolutey' => 1,
        }));
      } else {
        $self->push($self->Rect({
          'x'      => $vc_band_start -1,
          'y'      => 2,
          'width'  => $vc_band_end - $vc_band_start + 1,
          'height' => $h+2,
          'colour' => $colour,
          'absolutey' => 1,
        }));
        $self->push($self->Line({
          'x'      => $vc_band_start,
          'y'      => 2,
          'width'  => $vc_band_end - $vc_band_start + 1,
          'height' => 0,
          'colour' => $black,
          'absolutey' => 1,
        }));
        $self->push($self->Line({
          'x'      => $vc_band_start,
          'y'      => $h+4,
          'width'  => $vc_band_end - $vc_band_start + 1,
          'height' => 0,
          'colour' => $black,
          'absolutey' => 1,
        }));
      }
      my $font_colour = $self->my_colour( $stain, 'label' ) || 'black';  
      next if $font_colour eq 'invisible';
  #################################################################
  # only add the band label if the box is big enough to hold it...
  #################################################################
      my @res = $self->get_text_width( ($vc_band_end-$vc_band_start)*$pix_per_bp, $bandname, '', 'font'=>$fontname, 'ptsize' => $fontsize );
      if( $res[0] ) {
        $self->push($self->Text({
          'x'         => int(($vc_band_end + $vc_band_start-$res[2]/$pix_per_bp)/2),
          'y'         => ($h-$res[3])/2+1,
          'width'     => $res[2]/$pix_per_bp,
          'textwidth' => $res[2],
          'font'      => $fontname,
          'height'    => $res[3],
          'ptsize'    => $fontsize,
          'colour'    => $font_colour,
          'text'      => $res[0],
          'absolutey' => 1,
        }));
      }
    }
  } else {
    $self->push($self->Line({
      'x'      => 0,
      'y'      => 2,
      'width'  => $chr_length,
      'height' => 0,
      'colour' => $black,
      'absolutey' => 1,
    }));
    $self->push($self->Line({
      'x'      => 0,
      'y'      => $h + 6,
      'width'  => $chr_length,
      'height' => 0,
      'colour' => $black,
      'absolutey' => 1,
    }));
  }

    ##############################################
    # Draw the ends of the ideogram
    ##############################################
  foreach my $end (qw(0 1)) {
    my %partials = map { uc($_) => 1 } @{ $self->species_defs->PARTIAL_CHROMOSOMES || [] };
    if( $partials{ uc($chr) } ) {
    # draw jagged ends for partial chromosomes
      my $direction = $end ? 1 : -1;
      my $bpperpx = $chr_length/$im_width;
      foreach my $i (1..4) {
        my $x = $chr_length * $end + 4 * (($i % 2) - 1) * $direction * $bpperpx;
        my $y = 2 + ($h+2)/4 * ($i - 1);
        my $width = 4 * (1 - 2 * ($i % 2)) * $direction * $bpperpx;
        my $height = ($h+2)/4;
        # overwrite karyotype bands with appropriate triangles to
        # produce jags
        $self->push($self->Poly({
          'points'    => [
            $x, $y,
            $x + $width * (1 - ($i % 2)),$y + $height * ($i % 2),
            $x + $width, $y + $height,
          ],
          'colour'    => $white,
          'absolutey' => 1,
          'absoluteheight' => 1,
        }));
        # the actual jagged line
        $self->push($self->Line({
          'x'         => $x,
          'y'         => $y,
          'width'     => $width,
          'height'    => $height,
          'colour'    => $black,
          'absolutey' => 1,
          'absoluteheight' => 1,
        }));
      }
      # black delimiting lines at each side
      foreach (0, 10) {
        $self->push($self->Line({
          'x'                => 0,
          'y'                => 2 + $_,
          'width'            => 4,
          'height'           => 0,
          'colour'           => $black,
          'absolutey'        => 1,
          'absolutewidth'    => 1,
        }));
      }
    } else {
    # draw blunt ends for full chromosomes
      $self->push($self->Line({
        'x'      => $chr_length * $end,
        'y'      => 2,
        'width'  => 0,
        'height' => $h+2,
        'colour' => $black,
        'absolutey' => 1,
      }));
    }
  }
}

1;
