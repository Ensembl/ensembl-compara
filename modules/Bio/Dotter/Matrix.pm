#
# Ensembl module for Bio::Dotter::Matrix
#
# Cared for by Tony Cox <avc@sanger.ac.uk>
#
# Copyright Tony Cox
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

Bio::Dotter::Matrix -  a drawable version of a dotter matrix.

=head1 SYNOPSIS


my $matrix  = Bio::Dotter::Matrix->new($self->option);
$matrix->render();
     
=head1 DESCRIPTION

=head1 AUTHOR - Tony Cox

=head1 CONTACT

This modules is part of the Ensembl project http://www.ensembl.org

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk

=head1 APPENDIX

=cut


# Let the code begin...

package Bio::Dotter::Matrix;
use strict;
use vars qw($AUTOLOAD $DEBUG);
use GD;
$Bio::Dotter::Matrix::DEBUG = 0;

###############################################################################
# IMPORTANT
# on the plot
# the REFERENCE sequence goes HORIZONTALLY
# the HOMOLOGOUS sequence goes VERTICALLY
###############################################################################

###############################################################################
sub new {
  my ($class, $opt) = @_;
  my $self = bless { 'options'  =>  $opt }, $class;
  if( $self->file($self->option("dotter_bin_file")) ) {
    $self->unpack_matrix();
    $self->{'image'}     = new GD::Image(
      $self->hlen+ $self->option("h_border"),$self->vlen+ $self->option("v_border")
    );
    $self->{'imagemap'}  = '';
    $self->init_colours();
  }
  return $self;
}

 
###############################################################################
sub render {
  my( $self, $type ) = @_;
  return unless $self->{'image'};
  if( $type eq 'imagemap' && $self->{'imagemap'} ) { return $self->{'imagemap'}; }
  $self->draw_greyscale;   ##/
  $self->draw_checkboxes;  ##/
  $self->draw_legends;     ##/
  $self->draw_repeats;     ##/
  $self->draw_exons;       ##/
  $self->draw_matrix;      ##/
  $self->draw_frame;       ##/
  $self->draw_scalebars;
  $self->draw_axis_labels;
  if( $type eq 'imagemap' ) { return $self->{'imagemap'}; }
  return $self->write_image;
}


sub draw_greyscale { ##### Draw the grey scale bar at the bottom of the page
  my $self = shift;

  my $threshold = $self->option("threshold");
  my $hlen      = $self->hlen();
  my $h_border  = $self->option("h_border");

## The greyscale
  for( 0..255 ) {
    my $x1 = $hlen+$h_border - 300+$_;
    my $x2 = $x1+1;
    my $y2 = $hlen + ($h_border)-30;
    my $y1 = $hlen + ($h_border)-40;
    $self->image->rectangle( $x1, $y1, $x1, $y2, $self->colour($_) );
    $self->image_map_push( $x1, $y1, $x2, $y2, $self->self_URL( 't' => $_), "Reset threshold to $_" );
  }

## Greyscale frame
  $self->image->rectangle( $hlen + $h_border - 300, $hlen + $h_border - 30, $hlen + $h_border - 300 + 255, $hlen + $h_border - 40, $self->colour('black') );
  $self->image->string( gdMediumBoldFont, $hlen + $h_border - 500, $hlen + $h_border - 42, "Greyscale Map (threshold:$threshold)", $self->colour('black') );
  $self->image->string( gdSmallFont, $hlen + $h_border - 300, $hlen + $h_border - 55, "0", $self->colour('black') );
  $self->image->string( gdSmallFont, $hlen + $h_border - 300 + $threshold, $hlen + $h_border - 30, "$threshold", $self->colour('black') );
  $self->image->string( gdSmallFont, $hlen + $h_border - 300 + 255 - 12, $hlen + $h_border - 55, "255", $self->colour('black') );
}

sub draw_checkboxes { ##### draw the check boxes for size, grid, hsps
  my $self = shift;

  my $threshold = $self->option("threshold");
  my $hlen      = $self->hlen();
  my $h_border  = $self->option("h_border");
  my $size      = $self->option("size");

  my $box_x = 55;
  my $box_y = 200;
  my $pt = $hlen+$h_border-$box_x;

  my @scales = qw(500 1000 3000 5000 10000 15000 20000 );
  my $flag = 0;
  foreach(@scales) {
    if( abs(($size-$_)/$_) < 0.25 ) { $flag = 1; }
  }
  push @scales, $size unless $flag;

  foreach my $b (sort {$a <=> $b} @scales){
    my $x1 = $pt;
    my $y1 = $box_y;
    my $x2 = $pt-10;
    my $y2 = $box_y+10;
    my $s = ($b/1000);
       $s = sprintf( "%0.1f", $s ) if $s =~ /\./;
    $self->checkbox( $x1, $y1, $self->colour('black'), $size == $b , "$s kb");
    $self->image_map_push( $x2, $y1, $x1, $y2, $self->self_URL( 'w' => $b ), "Resize dotplot to $s kb" );
    $box_y += 25;
  }
  
  ## Draw the gridlines checkbox
  $box_y += 25;
  my $gx1 = $pt;
  my $gy1 = $box_y;
  my $gx2 = $pt-10;
  my $gy2 = $box_y+10;
  $self->checkbox( $gx1, $gy1, $self->colour('black'), $self->option("usegrid") > 0, "Grid");
  
  ## Draw the HSP checkbox
  $box_y += 25;
  my $hspx1 = $pt;
  my $hspy1 = $box_y;
  my $hspx2 = $pt-10;
  my $hspy2 = $box_y+10;
  $self->checkbox( $hspx1, $hspy1, $self->colour('black'), $self->option("usehsp") > 0, "HSPs");
        
  my $t     = $self->option("threshold");
    # The GRID checkbox url/map
  my $hspflag = $self->option("usehsp");  
  $self->image_map_push( $gx2, $gy1, $gx1, $gy2, $self->self_URL( 'g' => -$self->option("usegrid") ), "Toggle gridlines" );
     # The HSP checkbox url/map
  $self->image_map_push( $hspx2, $hspy1, $hspx1, $hspy2, $self->self_URL( 'h' => -$self->option("usehsp") ), "Toggle HSPs" );
}

sub draw_legends { ##### Draw legends on page...
  my $self = shift;

  my $hlen     = $self->hlen();
  my $h_border = $self->option("h_border");

  my $box_x = 55;
  my $box_y = 450;

  $self->image->string( gdSmallFont, $hlen+$h_border - $box_x-10, $box_y -2, "Exons:", $self->colour('black') );
  $box_y += 20;
  my $pt = $hlen+$h_border-$box_x-5;
  my $poly = new GD::Polygon;
     $poly->addPt($pt,$box_y);
     $poly->addPt($pt,$box_y+5);
     $poly->addPt($pt-5,$box_y+5);
     $poly->addPt($pt-5,$box_y);
  $self->image->filledPolygon($poly,$self->colour('black'));
  $self->image->string( gdSmallFont, $pt + 10, $box_y -5, "novel", $self->colour('black') );
  $box_y += 15;
  
  my $poly2 = new GD::Polygon;
     $poly2->addPt($pt,$box_y);
     $poly2->addPt($pt,$box_y+5);
     $poly2->addPt($pt-5,$box_y+5);
     $poly2->addPt($pt-5,$box_y);
  
  $self->image->filledPolygon($poly2,$self->colour('red'));
  $self->image->string( gdSmallFont, $pt + 10, $box_y -5, "known", $self->colour('black') );
  $box_y += 25;
  $self->image->rectangle( $pt, $box_y, $pt-5, $box_y+5, $self->colour('grey1') );
  $self->image->string( gdSmallFont, $pt + 10, $box_y -5, "repeat", $self->colour('black') );
}

sub draw_repeats { ##### Draw repeats at side of page...
  my $self = shift;

  my $hlen      = $self->hlen();
  my $vlen      = $self->vlen();
  my $h_border  = $self->option( "h_border" );
  my $v_border  = $self->option( "v_border" );
  my $size      = $self->option( "size"     );
  my $colour    = $self->colour( 'grey2'    );
  ## Draw the vertical repeats
  foreach my $r ( @{$self->option("hom")->slice()->get_all_RepeatFeatures()} ) {
    my $x1 = 30;
    my $x2 = 35;
    my $y1 = $v_border/2 + $r->start * $vlen/$size;
       $y1 = $v_border/2                            if $y1 < $v_border/2; # trim
    my $y2 = $v_border/2 + $r->end   * $vlen/$size;
       $y2 = $v_border/2+$vlen                      if $y2 > $v_border/2 + $vlen; # trim
    $self->image->rectangle( $x1, $y1, $x2, $y2, $colour );
  }
  ## Draw the horizontal repeats
  foreach my $r ( @{$self->option("ref")->slice()->get_all_RepeatFeatures()} ) {
    my $y1 = 30;
    my $y2 = 35;
    my $x1 = $h_border/2 + $r->start * $hlen/$size;
       $x1 = $h_border/2                            if $x1 < $h_border/2; # trim
    my $x2 = $h_border/2 + $r->end   * $hlen/$size;
       $x2 = $h_border/2+$hlen                      if $x2 > $h_border/2 + $hlen; # trim
    $self->image->rectangle( $x1, $y1, $x2, $y2, $colour );
  }
}

sub draw_exons { ##### Draws exons of ensembl genes.....
  my $self = shift;

  my $hlen     = $self->hlen();
  my $vlen     = $self->vlen();
  my $h_border = $self->option("h_border");
  my $v_border = $self->option("v_border");
  my $size     = $self->option("size");
  my $ref      = $self->option("ref");
  my $hom      = $self->option("hom");
  my $known    = $self->colour( 'red' ); 
  my $novel    = $self->colour( 'black' ); 
  ## Draw the vertical exons
  my @ovly = ();
  my @ovlx = ();

  foreach my $g (@{$hom->slice()->get_all_Genes($hom->species_defs->other_species( $hom->real_species, 'ENSEMBL_AUTHORITY' ))} ) {
    my $gcol = $g->is_known ? $known : $novel;
    my $gid = $g->stable_id();
    my $url = $self->geneview_URL( $hom->real_species, $gid, 'core' );
    foreach my $e (@{ $g->get_all_Exons() }){
      my $x1 = 20;
      my $x2 = 25;
      my $y1 = $v_border/2 + $e->start * $vlen/$size;
      my $y2 = $v_border/2 + $e->end *   $vlen/$size;
      next if $y2 <= $v_border/2;
      next if $y1 >= $v_border/2 + $vlen;
         $y2 = $v_border/2 + $vlen if $y2 > $v_border/2 + $vlen;
         $y1 = $v_border/2         if $y1 < $v_border/2;
      $self->image->filledRectangle(  $x1, $y1, $x2, $y2, $gcol );
      $self->image_map_push(          $x1, $y1, $x2, $y2, $url, "View gene $gid" );
      $self->image->filledRectangle(  $h_border/2, $y1, $h_border/2+$hlen, $y2, $self->colour('yellow1') );
      push(@ovly,$y1);
      push(@ovly,$y2);
    }
  }

  ## Draw the horizontal exons
  foreach my $g (@{$ref->slice()->get_all_Genes($ref->species_defs->other_species( $ref->real_species, 'ENSEMBL_AUTHORITY' ))} ) {
    my $gcol = $g->is_known ? $known : $novel;
    my $gid = $g->stable_id();
    my $url = $self->geneview_URL( $ref->real_species, $gid, 'core' );
    foreach my $e ( @{$g->get_all_Exons()} ) {
      my $y1 = 20;
      my $y2 = 25;
      my $x1 = $h_border/2 + ($e->start() * ($hlen/$size));
      my $x2 = $h_border/2 + ($e->end() * ($hlen/$size));
      next if $x2 <= $h_border/2;
      next if $x1 >= $h_border/2 + $hlen;
         $x2 = $h_border/2 + $hlen if $x2 > $h_border/2 + $hlen;
         $x1 = $h_border/2         if $x1 < $h_border/2;
      $self->image->filledRectangle( $x1, $y1, $x2, $y2, $gcol );
      $self->image_map_push(         $x1, $y1, $x2, $y2, $url, "View gene $gid" );
      $self->image->filledRectangle( $x1, $v_border/2, $x2, $v_border/2+$vlen, $self->colour('yellow1') );
      push(@ovlx,$x1);
      push(@ovlx,$x2);
    }
  }

  ## Draw the darker overlap colour - this is stinky!
  while(@ovly){
    my $y1 = shift @ovly;
    my $y2 = shift @ovly;
    my @tmp = @ovlx;
    while(@tmp){
      my $x1 = shift @tmp;
      my $x2 = shift @tmp;
      $self->image->filledRectangle($x1,$y1,$x2,$y2,$self->colour('yellow3'));
    }
  }
}

sub draw_matrix { ##### Draw the actual shaded pixels....
  my $self = shift;

  my $hlen       = $self->hlen();
  my $h_border   = $self->option( 'h_border' );
  my $v_border   = $self->option( 'v_border' );
  my $threshold  = $self->option("threshold");
  my $row       = 0;
  my $col       = 0;

  my @mat = @{$self->{'matrix'}};
  
  while (@mat){
    my $v = shift(@mat);
    warn "Cannot draw $v\n" unless $self->colour($v);
    if( $v >= $threshold ){ ## optimisation - only draw the non-white pixels!
      $self->image->setPixel($col + $h_border/2,$row + $v_border/2,$self->colour($v));
    }
    $col++;
    if($col == $hlen) {
      $col = 0;
      $row++;
    }
  }
}

sub draw_frame { ##### Draw black box around image....
  my $self = shift;

  my $hlen    = $self->hlen();
  my $vlen    = $self->vlen();
  my $h_border  = $self->option("h_border");
  my $v_border  = $self->option("v_border");
  $self->image->rectangle($h_border/2,$v_border/2,$hlen+$h_border/2,$vlen+$v_border/2,$self->colour('black'));
}

sub draw_scalebars { ##### Draw the ticks around the edge of the frame - and aslo the "major" grid...
  my $self = shift;

  my $hlen        = $self->hlen();
  my $vlen        = $self->vlen();
  my $zoom_factor = int($self->option('size')/500);
  my $h_border    = $self->option("h_border");
  my $v_border    = $self->option("v_border");
  my $usegrid     = $self->option("usegrid");
  my $black       = $self->colour('black');
  my $tot_vlength = $zoom_factor * $vlen;
  my $tot_hlength = $zoom_factor * $hlen;

  my $v_kbtick_interval = int($vlen/($tot_vlength/1000));
  my $h_kbtick_interval = int($hlen/($tot_hlength/1000));

  my $t = 0;
  while(1){
    $self->vtick( $t,$h_border/2,$v_border/2,$black,$t*$zoom_factor,$vlen,$usegrid);
    $t += $h_kbtick_interval;
    last if $t >= $tot_hlength/$zoom_factor;
  }
  
  $t = 0;
  while( $h_kbtick_interval > 50 ){
    $self->minor_vtick( $t,$h_border/2,$v_border/2,$black);
    $t += $h_kbtick_interval/10;
    last if $t >= $tot_hlength/$zoom_factor;
  }
  
  $t = 0;
  my $flip = 1;
  while(1){
    $self->htick( $t,$v_border/2,$h_border/2,$black,$t*$zoom_factor,$flip,$hlen,$usegrid);
    $t += $v_kbtick_interval;
    $flip *= -1;
    last if $t >= $tot_vlength/$zoom_factor;
  }
  $t = 0;
  while( $h_kbtick_interval > 50 ){
    $self->minor_htick( $t,$v_border/2,$h_border/2,$black);
    $t += $v_kbtick_interval/10;
    last if $t >= $tot_vlength/$zoom_factor;
  }
}

sub draw_axis_labels { ##### Draw axis labels...
  my $self = shift;

  my $hlen      = $self->hlen();
  my $vlen      = $self->vlen();
  
  my $h_border  = $self->option("h_border");
  my $v_border  = $self->option("v_border");
  my $size      = $self->option("size");
  my $hom       = $self->option("hom");
  my $ref       = $self->option("ref");

  ## make the axis labels
  my $reflabel1     = $ref->species_defs->other_species( $ref->real_species, 'SPECIES_BIO_NAME' );
  my $reflabel1_len = length($reflabel1);
  my $reflabel2     = $ref->seq_region_type_and_name." ".$ref->thousandify($ref->seq_region_start)." - ".$ref->thousandify($ref->seq_region_end);
  my $reflabel2_len = length($reflabel2);
  my $homlabel1     = $hom->species_defs->other_species( $hom->real_species, 'SPECIES_BIO_NAME' );
  my $homlabel1_len = length($homlabel1);
  my $homlabel2     = $hom->seq_region_type_and_name." ".$hom->thousandify($hom->seq_region_start)." - ".$hom->thousandify($hom->seq_region_end);
  my $homlabel2_len = length($homlabel2);
  
#  font and color.  Your choices of fonts are gdSmallFont,
#  gdMediumBoldFont, gdTinyFont, gdLargeFont and gdGiantFont.

  my $font = GD::Font->MediumBold;
  my( $w,$h ) = ($font->width,gdLargeFont->height);
  my( $x1,$y1,$x2,$y2 );
  
# Draw the horizontal, reference species, label
  $self->image->string( $font, $x1 = (($h_border/2) + ($hlen/2) - (($reflabel1_len+$reflabel2_len)/2 * $w)), $y1 = 0, $reflabel1, $self->colour('black') );
  $self->image->string( $font, $x1 += $w * ($reflabel1_len + 1), $y1 = 0, $reflabel2, $self->colour('red') );
  $x2 = $x1 + $w * ($reflabel2_len);
  $y2 = $y1 + $h;
  $self->image_map_push( $x1,$y1,$x2,$y2, $self->contigview_URL( $ref ), "Jump to contigview" );

# Now the vertical, homologous spp, label
  $self->image->stringUp( $font, $x1 = 0, $y1 = (($v_border/2) + ($vlen/2) + (($homlabel1_len+$homlabel2_len)/2 * $w)), $homlabel1, $self->colour('black') );
  $self->image->stringUp( $font, $x1 = 0, $y1 -= $w * ($homlabel1_len + 1), $homlabel2, $self->colour('red') );
  $x2 = $x1 + $h;
  $y2 = $y1 - $w * ($homlabel2_len);
  $self->image_map_push( $x1,$y2,$x2,$y1, $self->contigview_URL( $hom ), "Jump to contigview" );
}

sub write_image {  
  my $self = shift;
  return $self->image->can('png') ? $self->image->png : $self->image->gif;
}

###############################################################################
sub read_from_buffer { ##### 
  my( $self, $fh, $buffer, $length ) = @_;
  read $fh, $buffer, $length;
  unless( length($buffer) == $length ) {
    warn("The read was incomplete! Trying harder.");
    my $missing_length = $length - length($buffer);
    my $buffer2;
    read $fh, $buffer2, $missing_length;
    $buffer .= $buffer2;
    if( length($buffer) != $length ) {  
      die("Unexpected end of file.Should have read $length but instead got ".length($buffer)."!\n");
    }
  }
  return $buffer;
}

sub get_byte_order_flag {  # Aventis GTP Jack Hopkins 20040112
  return 'N' if unpack( 'xc', pack( 's', 1 ) ); ## Is big endian
  return 'V' if unpack( 'c', pack( 's', 1 ) );  ## Is little endian
  die "Cannot determine byte order for this platform!\n";                                            
}                                                                          

sub unpack_matrix {
  my $self = shift;
  
  my $HEADER_LENGTH = 25;
  my $MATRIX_LENGTH = 24;
  my $infile = $self->file();
  die "No matrix file at: $infile\n" unless ($infile);
  
  my $buffer;
  open(IN, "$infile") or die "open ($infile): $!\n";

  my $fh = \*IN;
  $buffer = $self->read_from_buffer( $fh, $buffer, $HEADER_LENGTH );

  my $byte_flag = $self->get_byte_order_flag;
  
  ( $self->{'file_format'}, $self->{'zoom_factor'},
    $self->{'hlen'},        $self->{'vlen'},
    $self->{'pix_factor'},  $self->{'window_length'},
    $self->{'matrix_name_length'} ) =
  unpack "C $byte_flag $byte_flag $byte_flag $byte_flag $byte_flag $byte_flag", $buffer;

  $buffer = $self->read_from_buffer( $fh, $buffer, $self->{'matrix_name_length'} );
  my $matrix_name = unpack "A$self->{'matrix_name_length'}", $buffer;
     $self->{'matrix_name'} = $matrix_name;
  
  my $mat_bytes  = $MATRIX_LENGTH * $MATRIX_LENGTH;
     $self->{'matrix_bytes'} = $mat_bytes;
  my $mat_length = $mat_bytes * 4;
  
  $buffer = $self->read_from_buffer( $fh, $buffer, $mat_length );
  
  my @matrix_data = unpack "$byte_flag$mat_bytes", $buffer;
  
  $self->{'score_matrix'}    = \@matrix_data;

  $self->{'bytes_remaining'} = (-s "$infile") - tell($fh);
  $buffer = $self->read_from_buffer( $fh, $buffer, $self->{'bytes_remaining'} );
  my @matrix   = unpack "C$self->{'bytes_remaining'}", $buffer;
  $self->{'matrix'} = \@matrix;

  if($Bio::Dotter::Matrix::DEBUG){
    warn "
Dotter file version:        $self->{'file_format'}
Zoom factor,                $self->{'zoom_factor'}
Horizonatal length          $self->{'hlen'}
Vertical length:            $self->{'vlen'}
Pixel factor:               $self->{'pix_factor'}
Window length:              $self->{'window_length'}
Scoring matrix name length: $self->{'matrix_name_length'}
Scoring matrix name:        $self->{'matrix_name'}
Scoring matrix:             $self->{'matrix_bytes'}
Image matrix pixels:        $self->{'bytes_remaining'}
";
  }
}

######## Support functions for creating URLs to dotterview, contigview and geneview

sub contigview_URL { my( $self, $loc ) = @_; return sprintf "/%s/contigview?l=%s:%s-%s", $loc->real_species, $loc->seq_region_name, $loc->seq_region_start, $loc->seq_region_end; }
sub geneview_URL   { my( $self, $sp, $gene, $db ) = @_;    return "/$sp/geneview?gene=$gene;db=".($db||'core'); }

sub self_URL {
  my $self = shift;
  $self->{'base_URL'} ||= sprintf '/%s/dotterview?c=%s:%d;s1=%s;c1=%s:%d',
                             $self->option('ref')->real_species,
                             $self->option('ref')->seq_region_name,
                             $self->option('ref')->centrepoint,
                             $self->option('hom')->real_species,
                             $self->option('hom')->seq_region_name,
                             $self->option('hom')->centrepoint;
  $self->{'parameters'} ||= {
    'w' => $self->option("size"),    ## Size of slice
    't' => $self->option("threshold"), ## Threshold
    'g' => $self->option("usegrid"),   ## Use grid
    'h' => $self->option("usehsp"),    ## Use HSP
  };
  my %pars = ( %{$self->{'parameters'}}, @_ );
  return join '', $self->{'base_URL'}, map { $pars{$_} ? ";$_=".CGI::escape($pars{$_}) : '' } keys %pars;
}

######## Support functions for drawing the axis lines....

sub htick {
  my( $self, $x, $h_border, $v_border, $colour, $label, $flip, $hlen, $add_gridlines ) = @_;
  $self->image->rectangle( $v_border + $x, $h_border - 10, $v_border + $x, $h_border, $colour );
  $self->image->line( $v_border + $x, $h_border, $v_border + $x, $h_border + $hlen, $colour ) if ($add_gridlines>0);
  $self->image->string( gdSmallFont, $v_border + $x - (gdSmallFont->width/2), $h_border - 27 + (5 * $flip), $label, $colour );
}

sub minor_htick {
  my( $self, $x, $h_border, $v_border, $colour ) = @_;
  $self->image->rectangle( $v_border + $x, $h_border-5, $v_border + $x, $h_border, $colour, );
}

sub vtick {
  my( $self, $y, $h_border, $v_border, $colour, $label, $vlen, $add_gridlines ) = @_;
  $self->image->rectangle( $v_border - 10, $h_border + $y, $v_border, $h_border + $y, $colour );
  $self->image->line( $v_border, $h_border + $y, $v_border + $vlen, $h_border + $y, $colour ) if ($add_gridlines>0);
  $self->image->string( gdSmallFont, $v_border - 10 - (length($label) * gdSmallFont->width()), $h_border + $y - 6, $label, $colour );
          
}

sub minor_vtick {
  my( $self, $y, $h_border, $v_border, $colour ) = @_;
  $self->image->rectangle( $v_border-5, $h_border + $y, $v_border, $h_border + $y, $colour );
}

sub image_map_push {
  my( $self, $x1, $y1, $x2, $y2, $url, $tag ) = @_ ;
  $self->{'imagemap'} .= qq(<area shape="rect" coords="$x1 $y1 $x2 $y2" href="$url" alt="$tag" title="$tag" />\n);
}

sub checkbox {
  my( $self, $x1, $y1, $colour, $flag, $label ) = @_;

  my $x2 = $x1 - 10;
  my $y2 = $y1 + 10;
  $self->image->rectangle( $x1, $y1, $x2, $y2, $colour );
  if( $flag > 0 ){
    $self->image->line(    $x1, $y1, $x2, $y2, $colour );
    $self->image->line(    $x2, $y1, $x1, $y2, $colour);
  }
  $self->image->string( gdSmallFont, $x1 + 10, $y1 - 2, $label, $colour );
}

###############################################################################
######################################################################

sub init_colours {
  my( $self ) = @_;

  my $threshold = $self->option('threshold') || 48;
  my @colours = (
    [ 'white'  , 255,255,255], [ 'grey1'  , 183,183,183], [ 'grey2'  , 150,150,150],
    [ 'grey3'  ,  83, 83,83 ], [ 'red'    , 160,  0,  0], [ 'blue'   ,   0,  0,255],
    [ 'yellow1', 255,255,231], [ 'yellow2', 255,255,221], [ 'yellow3', 255,255,190],
    [ 'black'  ,   0,  0,  0]
  );
  foreach (@colours) { $self->{'colourmap'}{$_->[0]} = $self->image->colorAllocate( $_->[1], $_->[2], $_->[3] ); }
  for( 0..$threshold ) {
    $self->{'colourmap'}{$_} = $self->image->colorAllocate(255,255,255);
  }
  for( $threshold+1..245 ){
    my $colour = $_ - $threshold + int(1.2 * $_);
       $colour = 245 if ($colour > 245);
    $self->{'colourmap'}{$_} = $self->image->colorAllocate(245-$colour,245-$colour,245-$colour);
  }
  for( 246..255 ){
    $self->{'colourmap'}{$_} = $self->{'colourmap'}{'black'}; # fake the last 10 colour to black
  }
  warn map { "\t$_ ".$self->{'colourmap'}{$_}."\n" } sort keys %{$self->{'colourmap'}};
}

#### Get and set functions....

sub image  { return $_[0]{'image'}; }
sub colour { return $_[0]{'colourmap'}{$_[1]}||$_[0]{'colourmap'}{'red'}; }
sub hlen   { return $_[0]{'hlen'};  }
sub vlen   { return $_[0]{'vlen'};  }
sub file   { my $self = shift; $self->{'file'} = shift if @_; return( $self->{'file'} ); }
sub option { my $self = shift; $self->{'options'}{$_[0]}=$_[1] if @_>1; return $self->{'options'}{$_[0]}; }

1;
