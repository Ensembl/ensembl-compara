package Bio::EnsEMBL::GlyphSet::alignscalebar;

=head1 NAME

EnsEMBL::Web::GlyphSet::alignscalebar;

=head1 SYNOPSIS

The alignscalebar object handles the detailed display of multiple alignments in alignsliceview

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Eugene Kulesha - ek3@sanger.ac.uk

=cut

use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use POSIX qw(ceil floor);
use Data::Dumper;

sub _init {
    my ($self) = @_;
    #return unless ($self->strand() == -1);
    
    my $Config         = $self->{'config'};
    my $Container      = $self->{'container'};

    my $contig_strand  = $Container->can('strand') ? $Container->strand : 1;
    my $h              = 0;
    my $highlights     = $self->highlights();

  my $pix_per_bp = $self->{'config'}->transform()->{'scalex'};

  my( $fontname, $fontsize ) = $self->get_font_details( 'innertext' );
  my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my $fontheight = $res[3];

    my $black          = 'black';
    my $highlights     = join('|',$self->highlights());
    $highlights        = $highlights ? "&highlight=$highlights" : '';
    my $object = $Config->{_object};
    my $REGISTER_LINE  = $Config->get_parameter( 'opt_lines');
    my $feature_colour = $Config->get('scalebar', 'col');
    my $subdivs        = $Config->get('scalebar', 'subdivs');
    my $max_num_divs   = $Config->get('scalebar', 'max_divisions') || 12;
    my $navigation     = $Config->get('scalebar', 'navigation');
    my $abbrev         = $Config->get('scalebar', 'abbrev');
    
    (my $param_string   = $Container->seq_region_name()) =~ s/\s/\_/g;
    
    
    my $species =  $Container->{web_species};

    my $aslink = $Config->get('alignslice', 'align');
    my $main_width     = $Config->get_parameter(  'main_vc_width');
    my $len            = $Container->length();

    my $global_start   = $contig_strand < 0 ? -$Container->end() : $Container->start();
    my $global_end     = $contig_strand < 0 ? -$Container->start() : $Container->end();

    my $mp = $Container->{slice_mapper_pairs};

# Display gaps in AlignSlices
    $self->align_gap($Container, $global_start, $global_end, 8) if ($self->{strand} > 0);
    $self->align_gap($Container, $global_start, $global_end, 2) if ($self->{strand} < 0);

# Display AlignSlice bars
    $self->align_interval($species, $mp, $global_start, $global_end, 5);

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
    my $yc = $self->{strand} > 0 ? 0 : 20;
    if ($Container->{compara} eq 'primary') {
    if ($self->{strand} < 0) {
        $start = $global_end  +1;
    }
    } else {
    if ($self->{strand} > 0) {
        $start = $global_end  +1;
    }
    }
    
    while( $start <= $global_end ) { 
    my $end       = $start + $minor_unit - 1;
    $filled = 1 - $filled;
    my $box_start = $start < $global_start ? $global_start -1 : $start;
    my $box_end   = $end   > $global_end   ? $global_end      : $end;

      ## Draw the glyph for this box!
    my $t = $self->Rect({
        'x'         => $box_start - $global_start, 
        'y'         => $yc,
        'width'     => abs( $box_end - $box_start + 1 ),
        'height'    => 3,
        ( $filled == 1 ? 'colour' : 'bordercolour' )  => 'black',
        'absolutey' => 1,
        });
    if ($navigation eq 'on'){
        ($t->{'href'},$t->{'zmenu'}) = $self->interval( $species, $aslink, $Container, $start, $end, $contig_strand, $global_start, $global_end-$global_start+1, $highlights);
    }

    $self->push($t);

   ## Vertical lines across all species
   if($REGISTER_LINE && $Container->{compara} ne 'secondary') {
        if($start == $box_start ) { # This is the end of the box!
        $self->join_tag( $t, "ruler_$start", 0, 0 , $start%$major_unit ? 'grey90' : 'grey80'  );
    } elsif( ( $box_end==$global_end ) && !(( $box_end+1) % $minor_unit ) ) {
        $self->join_tag( $t, "ruler_$end", 1, 0 , ($global_end+1)%$major_unit ? 'grey90' : 'grey80'  );
        }
    }

    unless( $box_start % $major_unit ) { ## Draw the major unit tick 
        $self->push($self->Rect({
        'x'         => $box_start - $global_start,
        'y'         => $yc, 
        'width'     => 0,
        'height'    => 5,
        'colour'    => 'black',
        'absolutey' => 1,
        }));
        my $LABEL = $minor_unit < 250 ? $object->commify($box_start * $contig_strand ): $self->bp_to_nearest_unit( $box_start * $contig_strand, 2 );
        my @res = $self->get_text_width( ($box_start-$last_text_X)*$pix_per_bp*1.5, $LABEL, '', 'font'=>$fontname, 'ptsize' => $fontsize );

        if( $res[0]) {
        $self->push($self->Text({
            'x'         => $box_start - $global_start,
            'y'         => $yc - $fontheight - 1,
            'height'    => $fontheight,
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
        'y'         => $yc,
        'width'     => 0,
        'height'    => 5,
        'colour'    => 'black',
        'absolutey' => 1,
    }));
    }


    if ($self->{strand} > 0 && $Container->{compara} ne 'primary') {
    my $line = $self->Rect({
        'x' => -120,
        'y' => 0, # 22,
        'colour' => 'black',
        'width' => 20000,
        'height' => 0,
        'absolutex'     => 1,
        'absolutewidth' => 1,
        'absolutey'     => 1,
    });
      
    $self->push($line);
    }
}

sub align_interval {
    my $self = shift;
    my ($species, $mp, $global_start, $global_end, $yc) = @_;

    my $Config          = $self->{'config'};
    my $pix_per_bp     = $Config->transform()->{'scalex'};
    my $last_end = -1;
    my $last_chr = -1;
    my $zc = -20;
    my $last_s2s = -1;
    my $last_s2e = -1;
    my $last_s2st = 0;

    my %colour_map = ();
    my %colour_map2 = ();
    my @colours2 = qw(antiquewhite3 brown gray rosybrown1 blue green red gray yellow);
    my @colours = qw(antiquewhite1 mistyrose1 burlywood1 khaki1 cornsilk1 lavenderblush1 lemonchiffon2 darkseagreen2  lightcyan1 papayawhip seashell1);

    foreach my $s (sort {$a->{start} <=> $b->{start}} @$mp) {
    my $s2 = $s->{slice};

    my $ss = $s->{start};
    my $sst = $s->{strand};
    my $se = $s->{end};

    my $s2s = $s2->{start};
    my $s2e = $s2->{end};
    my $s2st = $s2->{strand};
    my $s2t = $s2->{seq_region_name};

    my $box_start = $ss;
    my $box_end   = $se;
    my $filled = $sst;
    my $s2l = abs($s2e - $s2s)+1;
    my $sl = abs($se - $ss)+1;

    my $cview = sprintf("/%s/contigview?l=%s:%ld-%ld", $species, $s2t, $s2s, $s2e);
    my $zmenu;
    if ($s2t eq 'GAP') {
      $zmenu = {
		'caption' => "AlignSlice",
		'01:Gap in the alignment' => "",
	       };
    }
    elsif ($species eq "Ancestral_sequences") {
      my $simple_tree = $s2->{_tree};
      $zmenu = {
		'caption' => "AlignSlice",
		"01:ID: $s2t" => "",
		'02:'.$simple_tree => '',
	       };
    }
    else {
      $zmenu = {
        'caption' => "AlignSlice",
        "01:Chromosome: $s2t" => "",
        "05:Strand: $s2st" => "",
        "10:Start: $s2s" => "", 
        "15:End: $s2e" => "", 
        "20:Length: $s2l" => '', 
        "23:View in contigview" => $cview,
        "25:----------------" => '',
        "30:Interval Start:$ss" => '', 
        "35:Interval End: $se" => '', 
        "40:Interval Length: $sl" => '', 
	       };
    }
    $colour_map{$s2t} or $colour_map{$s2t} = shift (@colours) || 'grey';
    $colour_map2{$s2t} or $colour_map2{$s2t} =  'darksalmon' ;#shift (@colours2) || 'grey';

    my $col2 = $colour_map2{$s2t};
    my $t = $self->Rect({
        'x'         => $box_start - $global_start, 
        'y'         => $yc,
        'width'     => abs( $box_end - $box_start + 1 ),
        'height'    => 3,
        ( $filled == 1 ? 'colour' : 'bordercolour' )  => $col2,
        'absolutey' => 1,
        'zmenu' => $zmenu
        });

    $self->push($t);

    my $col = $colour_map{$s2t};

    if ($self->{strand} < 0) {
        $self->join_tag( $t, "alignslice_${box_start}", 0,0, $col, 'fill', $zc );
        $self->join_tag( $t, "alignslice_${box_start}", 1,0, $col, 'fill', $zc );
    } else {
        $self->join_tag( $t, "alignslice_${box_start}", 1,1, $col, 'fill', $zc );
        $self->join_tag( $t, "alignslice_${box_start}", 0,1, $col, 'fill', $zc );
    }

    ## This happens when we have two contiguous underlying slices
    if ($last_end == $ss - 1) {
      my $s3l = $s2s - $last_s2e - 1;
      if ($s2st == -1 and $last_s2st == -1) {
        $s3l = $s2e - $last_s2s + 1;
      }
      my $xc = $box_start - $global_start;
      my $h = $yc - 2;

      my $zmenu2;
      my $colour;
      if ($last_chr ne $s2t) {
        ## Different chromosomes
        $colour = "black";
        $zmenu2 = {
            'caption' => "AlignSlice Break",
            "00:Info: There is a breakpoint" => "",
            "01:in the alignment between chromosome" => "",
            "02:$last_chr and $s2t" => "",
          };
      } elsif ($last_s2st ne $s2st) {
        ## Same chromosome, different strand (inversion)
        $colour = "3333ff"; #"seagreen4";
        $zmenu2 = {
            'caption' => "AlignSlice Break",
            "00:Info: There is an inversion" => "",
            "01:in chromosome $s2t" => "",
          };
      } elsif ($s3l > 0) {
        ## Same chromosome, same strand, gap between the two underlying
        ## slices
        $colour = "red";
        my ($from, $to); 
        if ($s2st == 1) {
          $from = $last_s2e;
          $to = $s2s;
        } else {
          $from = $s2e;
          $to = $last_s2s;
        }
        my $cview = sprintf("/%s/contigview?l=%s:%ld-%ld", $species, $s2t, ($from+1), ($to-1));
        $zmenu2 = {
            'caption' => "AlignSlice Break",
            "00:Info: There is a gap in the original"=>"",
            "01:chromosome between these two alignments" => "",
            "02:Chromosome: $s2t" => "",
            "03:From: $from" => "",
            "04:To: $to" => "",
            "05:Length: $s3l bp" => "",
            "06:View in ContigView" => $cview,
          };
      } else {
        ## Same chromosome, same strand, no gap between the two underlying
        ## slices (BreakPoint in another species)
        $colour = "indianred3";
        $zmenu2 = {
            'caption' => "AlignSlice Break",
            "00:Info: There is a breakpoint in the" => "",
            "01:alignment on chromosome: $s2t" => "",
          };
      }

      $self->push( $self->Poly({
      'points'    => [ $xc - 2/$pix_per_bp, $h,
              $xc, $h+6,
              $xc + 2/$pix_per_bp, $h  ],
      'colour'    => $colour,
      'absolutey' => 1,
      'zmenu' => $zmenu2
      }));
    }
    $last_end = $se;
    $last_s2s = $s2s;
    $last_s2e = $s2e;
    $last_s2st = $s2st;
    $last_chr = $s2t;
    }

}

sub align_gap {
    my $self = shift;
    my ($Container, $global_start, $global_end, $yc) = @_;

    my $mp = $Container->{slice_mapper_pairs};
    my $si = 0;
    my $hs = $mp->[$si];
    my $gs = $hs->{start} - 1;
    my $ge = $hs->{end};

    my $cigar_line = $Container->get_cigar_line();
    my $Config          = $self->{'config'};

# Display only those gaps that amount to more than 1 pixel on screen, otherwise screen gets white when you zoom out too much .. 
    my $pix_per_bp     = $Config->transform()->{'scalex'};
    my $min_length = 1 / $pix_per_bp;

    my @inters = split (/([MDG])/, $cigar_line);

    my $ms = 0;
    my $ds = 0;
    my $box_start = 0;
    my $box_end = 0;
    my $colour = 'white';
    my $zc = -10;

    while (@inters) {
    $ms = (shift (@inters) || 1);
    my $mtype = shift (@inters);

    $box_end = $box_start + $ms -1;

    if ($mtype =~ /G|M/) {
# Skip normal alignment and gaps in alignments
        $box_start = $box_end + 1;
        next;
    }

    if ($box_start > $ge) {
        $si++;
        $hs = $mp->[$si] or return;
        $gs = $hs->{start} - 1;
        $ge = $hs->{end};
    }
    if ($ms > $min_length && $box_start >=  $gs && $box_end < $ge) { 
        my $t = $self->Rect({
        'x'         => $box_start,
        'y'         => $yc,
        'z'         => $zc,
        'width'     => abs( $box_end - $box_start + 1 ),
        'height'    => 3,
        'colour' => $colour, 
        'absolutey' => 1,
        });

        $self->push($t);
        
        if ($self->{strand} < 0) {
        $self->join_tag( $t, "alignsliceG_${box_start}", 0,0, $colour, 'fill', $zc );
        $self->join_tag( $t, "alignsliceG_${box_start}", 1,0, $colour, 'fill', $zc );
        } else {
        $self->join_tag( $t, "alignsliceG_${box_start}", 1,1, $colour, 'fill', $zc );
        $self->join_tag( $t, "alignsliceG_${box_start}", 0,1, $colour, 'fill', $zc );
        }
    }

    $box_start = $box_end + 1;

    }
}

sub real_location {
    my ($self, $as, $coord) = @_;
    my ($slice, $pos) = $as->get_original_seq_region_position($coord);
    my ($chr, $x) = (0, 0);

    if ($pos != $coord) {
    $chr = $slice->seq_region_name();
    $x = $pos;
    }

    return ($chr, $x);
}


sub interval {
    # Add the recentering imagemap-only glyphs
    my ( $self, $species, $aslink, $as, $start, $end, $contig_strand, $global_offset, $width, $highlights) = @_;
    my ($chr, $interval_middle) = $self->real_location($as, $contig_strand * ($start+1));
    
    return if (!$chr);
    
    $width = $self->{config}->{_object}->length;

    return( $self->zoom_URL($species, $aslink, $chr, $interval_middle, $width,  1  , $highlights, $self->{'config'}->{'slice_number'}, $contig_strand),
        $self->zoom_zmenu( $species, $aslink, $chr, $interval_middle, $width, $highlights, $self->{'config'}->{'slice_number'}, $contig_strand ) );
}

sub zoom_zmenu {
    my ($self, $species, $aslink, $chr, $interval_middle, $width, $highlights, $config_number, $ori ) = @_;
    $chr =~s/.*=//;

    $config_number or $config_number = 1;

    my $link = qq{/$species/$ENV{'ENSEMBL_SCRIPT'}?c=$chr:$interval_middle&w=$width&align=$aslink};
    my $zmenu = {
    'caption' => "Navigation",
    "10:Centre on this scale interval" => "$link", 

    };
          
    return $zmenu;

    return qq(zn('/$species/$ENV{'ENSEMBL_SCRIPT'}', '$chr', '$interval_middle', '$width', '$highlights','$ori','$config_number', '@{[$self->{container}{web_species}]}' ));
}

sub zoom_URL {
  my( $self, $species, $aslink, $PART, $interval_middle, $width, $factor, $highlights, $config_number, $ori) = @_;
  my $extra = "";
#  warn("URL: $species, $PART");
  if( $config_number ) {
    $extra = "o$config_number=c$config_number=$PART:$interval_middle:$ori&w$config_number=$width"; 
  } else {
    $extra = "c=$PART:$interval_middle&w=$width";
  }

  $extra .= "&align=$aslink";

  return qq(/$species/$ENV{'ENSEMBL_SCRIPT'}?$extra$highlights);
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


1;
