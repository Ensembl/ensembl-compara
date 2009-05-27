package Bio::EnsEMBL::GlyphSet::scalebar;

use strict;

use POSIX qw(ceil floor);

use base qw(Bio::EnsEMBL::GlyphSet);


my %SHORT = qw(
  chromosome Chr.
  supercontig S'ctg
);

sub _init {
    my ($self) = @_;
    #return unless ($self->strand() == -1);

    my $Config         = $self->{'config'};
    my $Container      = $self->{'container'};
    
  my( $fontname, $fontsize ) = $self->get_font_details( 'innertext' );

    my $contig_strand  = $Container->can('strand') ? $Container->strand : 1;
    my $pix_per_bp     = $Config->transform()->{'scalex'};
    my $h              = 0;
    my $highlights     = $self->highlights();

    my $black          = 'black';
    my $highlights     = join('|',$self->highlights());
    $highlights        = $highlights ? ";h=$highlights" : '';
 if( $self->{'config'}->{'compara'} ) { ## this is where we have to add in the other species....
    my $C = 0;
    foreach( @{ $self->{'config'}{'other_slices'}} ) {
      if( $C!= $self->{'config'}->{'slice_number'} ) {
        if( $C ) {
          if( $_->{'location'} ) {
            $highlights .= sprintf( ";s$C=%s;c$C=%s:%s:%s;w$C=%s", $_->{'species'}, 
                         $_->{'location'}->seq_region_name, $_->{'location'}->centrepoint, $_->{'ori'}, $_->{'location'}->length );
          } else {
            $highlights .= sprintf( ";s$C=%s", $_->{'species'} ); 
          }
        } else {
          $highlights .= sprintf( ";c=%s:%s:1;w=%s", 
                         $_->{'location'}->seq_region_name, $_->{'location'}->centrepoint, $_->{'location'}->length );
        }
      }
      $C++;
    }
 } ##
    my $REGISTER_LINE  = $Config->get_parameter( 'opt_lines');
    my $feature_colour = $self->my_config('col');
    my $subdivs        = $self->my_config('subdivs');
    my $max_num_divs   = $self->my_config('max_divisions') || 12;
    my $navigation     = $self->my_config('navigation');
    my $abbrev         = $self->my_config('abbrev');
    my $param_string   = $Container->seq_region_name();

    my $main_width     = $Config->get_parameter(  'main_vc_width');
    my $len            = $Container->length();
    my $global_start   = $contig_strand < 0 ? -$Container->end() : $Container->start();
    my $global_end     = $contig_strand < 0 ? -$Container->start() : $Container->end();

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

    my $start = floor( $global_start / $minor_unit ) * $minor_unit;
    my $filled = 1;
    my $last_text_X = -1e20;
    while( $start <= $global_end ) { 
      my $end       = $start + $minor_unit - 1;
      $filled = 1 - $filled;
      my $box_start = $start < $global_start ? $global_start : $start;
      my $box_end   = $end   > $global_end   ? $global_end   : $end;

      ## Draw the glyph for this box!
      my $t = $self->Rect({
         'x'         => $box_start - $global_start, 
         'y'         => 0,
         'width'     => abs( $box_end - $box_start + 1 ),
         'height'    => 3,
         ( $filled == 1 ? 'colour' : 'bordercolour' )  => 'black',
         'absolutey' => 1,
      });
      if ($navigation eq 'on' && $Config->{'compara'} ne 'secondary' ){
#        ($t->{'href'},$t->{'zmenu'}) = $self->interval( $param_string, $start, $end, $contig_strand, $global_start, $global_end-$global_start+1, $highlights);
      } elsif( $navigation eq 'zoom' ) {
#        ($t->{'href'},$t->{'zmenu'}) = $self->zoom_interval( $param_string, $start, $end, $contig_strand, $global_start, $main_width, $highlights, $global_end-$global_start);
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
        my $LABEL = $minor_unit < 1000 ? $self->commify($box_start * $contig_strand ): $self->bp_to_nearest_unit( $box_start * $contig_strand, 2 );
        my($TXT,$PART,$W,$H) = $self->get_text_width(0,$LABEL,'','font'=>$fontname,'ptsize'=>$fontsize);
        if( $last_text_X + $W/$pix_per_bp * 1.5 < $box_start ) {
          $self->push($self->Text({
            'x'         => $box_start - $global_start,
            'y'         => 5,
            'height'    => $H,
            'font'      => $fontname,
            'ptsize'    => $fontsize,
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
  my ( $self, $chr, $start, $end, $contig_strand, $global_offset, $width, $highlights) = @_;
  my $interval_middle = $contig_strand * ($start + $end)/2;
  return( $self->zoom_URL($chr, $interval_middle, $width,  1  , $highlights, $self->{'config'}->{'slice_number'}, $contig_strand ),
          $self->zoom_zmenu( $chr, $interval_middle, $width, $highlights, $self->{'config'}->{'slice_number'}, $contig_strand ) );
}

sub zoom_interval {
  # Add the recentering imagemap-only glyphs
  my ( $self, $chr, $start, $end, $contig_strand, $global_offset, $width, $highlights, $zoom_width ) = @_;
  my $interval_middle = $contig_strand * ($start + $end)/2;
  return(
    $self->zoom_URL($chr, $interval_middle, $width,  1  , $highlights, $self->{'config'}->{'slice_number'}, $contig_strand ),
    $self->zoom_zoom_zmenu( $chr, $interval_middle, $width, $highlights, $zoom_width, $self->{'config'}->{'slice_number'}, $contig_strand )
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

  my $value = floor( $bp / ( 10 ** ( $power_ranger * 3 ) ) );
    
  $value = sprintf( "%.${dp}f", $bp / ( 10 ** ( $power_ranger * 3 ) ) ) if ($unit ne 'bp');      

  return "$value $unit";
}


1;
