package Bio::EnsEMBL::GlyphSet::HSP_scalebar;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use  Sanger::Graphics::Bump;

sub _init {
    my ($self) = @_;
    #return unless ($self->strand() == -1);
    my $Config         = $self->{'config'};
    my $Container      = $self->{'container'};
    my $h              = 0;
    my( $fontname, $fontsize ) = $self->get_font_details( 'innertext' );
    my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
    my $th = $res[3];
    my $pix_per_bp = $self->{'config'}->transform()->{'scalex'};
    my $black          = 'black';
    my $highlights     = join('|',$self->highlights());
    $highlights        = $highlights ? ";h=$highlights" : '';
    my $REGISTER_LINE  = $Config->get_parameter( 'opt_lines');
    my $feature_colour = $self->my_config('col');
    my $subdivs        = $self->my_config('subdivs');
    my $max_num_divs   = $self->my_config('max_divisions') || 12;
    my $navigation     = $self->my_config('navigation')    || "off";
    my $abbrev         = $self->my_config('abbrev');
    my $clone_based    = $Config->get_parameter( 'clone_based') && ($Config->get_parameter( 'clone_based') eq 'yes');
    my $param_string   = "";
    $param_string      = $Config->get_parameter(  'clone') if($clone_based);
    $param_string      = "chr=" . $Container->chr_name() if($Container->can("chr_name"));
    my $main_width     = $Config->get_parameter(  'main_vc_width');
    my $len            = $Container->length();
    my $global_start   = $Container->start() if($Container->can("start"));
    $global_start      = $Config->get_parameter( 'clone_start') if($clone_based);
    $global_start      = $Container->chr_start() if($Container->can("chr_start"));
    my $global_end     = $global_start + $len - 1;

    #print STDERR "VC half length = $global_offset\n";
    #print STDERR "VC start = $global_start\n";
    #print STDERR "VC end = $global_end\n";

    ## Lets work out the major and minor units...

    my( $major_unit, $minor_unit );

    if( $len <= 51 ) {
       $major_unit = 10;
       $minor_unit = 1; 
    } else {
       my $exponent = 10 ** int( log($len)/log(10) );
       my $mantissa  = $len / $exponent;
       if( $mantissa < 1.2 ) {
          $major_unit = $exponent / 10 ;
          $minor_unit = $major_unit / 5 ;
       } elsif( $mantissa < 2.5 ) {
          $major_unit = $exponent / 5 ;
          $minor_unit = $major_unit / 4 ;
       } elsif( $mantissa < 5 ) {
          $major_unit = $exponent / 2 ;
          $minor_unit = $major_unit / 5 ;
       } else {
          $major_unit = $exponent;
          $minor_unit = $major_unit / 5 ;
       }
    }

    ## Now lets draw these....

    my $start = int( $global_start / $minor_unit ) * $minor_unit;
    my $filled = 1;
    my $last_text_X = -1e30;
    while( $start <= $global_end ) { 
      $filled = 1 - $filled;
      my $end       = $start + $minor_unit - 1;
      my $box_start = $start < $global_start ? $global_start -1 : $start;
      my $box_end   = $end   > $global_end   ? $global_end      : $end;

      ## Draw the glyph for this box!
      my $t = $self->Rect({
         'x'         => $box_start - $global_start, 
         'y'         => 0,
         'width'     => $box_end - $box_start + 1,
         'height'    => 3,
         ( $filled == 1 ? 'colour' : 'bordercolour' )  => 'black',
         'absolutey' => 1,
      });
      if ($navigation eq 'on'){
        ($t->{'href'},$t->{'zmenu'}) = $self->interval( $param_string, $start, $end, $global_start, $global_end-$global_start+1, $highlights);
      } elsif( $navigation eq 'zoom' ) {
        ($t->{'href'},$t->{'zmenu'}) = $self->zoom_interval( $param_string, $start, $end, $global_start, $main_width, $highlights, $global_end-$global_start);
      }
      $self->push($t);
      if($start == $box_start ) { # This is the end of the box!
        $self->join_tag( $t, "ruler_$start", 0, 0 , $start%$major_unit ? 'grey90' : 'grey80'  ) if($REGISTER_LINE);
      }
      if( ( $box_end==$global_end ) && !( ( $box_end+1) % $minor_unit ) ) {
        $self->join_tag( $t, "ruler_end", 1, 0 , ($global_end+1)%$major_unit ? 'grey90' : 'grey80'  ) if($REGISTER_LINE);
      }
      unless( $box_start % $major_unit ) { ## Draw the major unit tick 
        $self->push($self->Rect({
            'x'         => $box_start - $global_start,
            'y'         => 0,
            'width'     => 0,
            'height'    => 5,
            'colour'    => 'black',
            'absolutey' => 1,
        }));
        my $LABEL = $box_start;#$minor_unit < 250 ? $self->commify($box_start): $self->bp_to_nearest_unit( $box_start, 2 );
        my @res = $self->get_text_width( 0, $LABEL, '', 'font'=>$fontname, 'ptsize' => $fontsize );
        if( $last_text_X + $res[2] * 1.5 / $pix_per_bp < $box_start ) {
          $self->push($self->Text({
            'x'         => $box_start - $global_start,
            'y'         => 8,
            'height'    => $th,
            'font'      => $fontname,
            'ptsize'      => $fontsize,
            'halign'    => 'left',
            'colour'    => $feature_colour,
            'text'      => $LABEL,
            'absolutey' => 1,
          }));
          $last_text_X = $box_start;
        }
      } 
      $start += $minor_unit;
    }
    unless( ($global_end+1) % $major_unit ) { ## Draw the major unit tick 
      $self->push($self->Rect({
        'x'         => $global_end - $global_start + 1,
        'y'         => 0,
        'width'     => 0,
        'height'    => 5,
        'colour'    => 'black',
        'absolutey' => 1,
      }));
    }
}

sub interval {
    # Add the recentering imagemap-only glyphs
    my ( $self, $chr, $start, $end, $global_offset, $width, $highlights) = @_;
    my $interval_middle = ($start + $end)/2;
    return( $self->zoom_URL($chr, $interval_middle, $width,  1  , $highlights),
            $self->zoom_zmenu( $chr, $interval_middle, $width, $highlights ) );
}

sub zoom_interval {
    # Add the recentering imagemap-only glyphs
    my ( $self, $chr, $start, $end, $global_offset, $width, $highlights, $zoom_width ) = @_;
    my $interval_middle = ($start + $end)/2;
    return( $self->zoom_URL($chr, $interval_middle, $width,  1  , $highlights),
           $self->zoom_zoom_zmenu( $chr, $interval_middle, $width, $highlights, $zoom_width )
    );
}

sub bp_to_nearest_unit_by_divs {
    my ($self,$bp,$divs) = @_;

    return $self->bp_to_nearest_unit($bp,0) if (!defined $divs);

    my $power_ranger = int( ( length( abs($bp) ) - 1 ) / 3 );
    my $value = $divs / ( 10 ** ( $power_ranger * 3 ) ) ;

    my $dp = $value < 1 ? length ($value) - 2 : 0; # 2 for leading "0."
    return $self->bp_to_nearest_unit ($bp,$dp);
}

sub bp_to_nearest_unit {
    my ($self,$bp,$dp) = @_;
    $dp = 1 unless defined $dp;
    
    my @units = qw( bp Kb Mb Gb Tb );
    my $power_ranger = int( ( length( abs($bp) ) - 1 ) / 3 );
    my $unit = $units[$power_ranger];

    my $value = int( $bp / ( 10 ** ( $power_ranger * 3 ) ) );
      
    $value = sprintf( "%.${dp}f", $bp / ( 10 ** ( $power_ranger * 3 ) ) ) if ($unit ne 'bp');      

    return "$value $unit";
}

sub zoom_URL {
  return "";
}

1;
