package Bio::EnsEMBL::GlyphSet::ld2;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);
use POSIX;

sub _key { return $_[0]->my_config('key') || 'r2'; }

sub _init {
  my ($self) = @_;
  return unless ($self->strand() == -1);
  my $Config   = $self->{'config'};
  my @pops     = @{ $Config->{'_ld_population'} ||[] };
  unless (scalar @pops) {
    warn "****[WARNING]: No population defined in config";
    return;
  }

  my $Container = $self->{'container'};
  # Auxiliary data
  my $key = $self->_key();
  my $pop_adaptor = $self->{'container'}->adaptor->db->get_db_adaptor('variation')->get_PopulationAdaptor;
  my $max_ld_range = 100000;
  my( $fontname, $fontsize ) = $self->get_font_details( 'innertext' );
  my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my $h = $res[3];
  
  my $TAG_LENGTH      = 10;
  
  my $height_ppb      = $Config->transform()->{'scalex'};

  my $window         = POSIX::ceil( $self->my_config( 'window_size' ) ||
                       ($self->my_config( 'height' )/$height_ppb) ||
                       5000 );
  my $extra          = defined( $self->my_config( 'flanking') ) ? $self->my_config( 'flanking') : ($window * 2);
  my $seq            = $Container->expand($extra,$extra);

  my $yoffset         = 0;
  my $offset          = $self->{'container'}->start - 1 - $extra;
  my $colours         = $self->my_config( 'colours');
  my @colour_gradient = $Config->colourmap->build_linear_gradient( 41,'mistyrose', 'pink', 'indianred2', 'red' );
  my $len             = $Container->length;
  my $length           = int(($self->{'container'}->length -1)/1000 + 0.5);

  warn "\n";
  
  warn "... $window - $extra ...";
  
  warn "\n";
  # Foreach population
  foreach my $pop_name ( sort  @pops ) {
    next unless $pop_name;

    # Create array of arrayrefs containing $vf_id => $vf in start order
    my $pop_obj = $pop_adaptor->fetch_by_name($pop_name);
    next unless $pop_obj;
    my $pop_id =  $pop_obj->dbID;
    my $data = $seq->get_all_LD_values($pop_obj); 
    foreach( sort keys %{$data->{'ldContainer'}} ) {
      warn "LD:  $_ ::: ",$data->{'ldContainer'}{$_},"\n";
    }
    my @snps  = sort { $a->[1]->start <=> $b->[1]->start }
      map  { [ $_ => $data->{'variationFeatures'}{$_} ] }
      keys %{ $data->{'variationFeatures'} };
    foreach( @snps ) {
      warn "SNP: $_->[0] ::: ",$_->[1]->start,"\n";
    }
    my $number_of_snps = scalar(@snps);
    ## If there is no data....
    warn @snps;
    if( ( $number_of_snps < 2 )
#     || ( $snps[-1][1]->start  < $extra-$window )
#     || ( $snps[0][1]->start > $extra + 2 * $window + $len )
    ) {
      $yoffset += $h*1.5;
      $self->errorTrack( "No $key linkage data in $length kb window for population $pop_name", undef, $yoffset);
      $yoffset += $h*1.5;
      next;
    }

    $yoffset += $TAG_LENGTH + $h;
    # Print GlyphSet::variation type bars above ld triangle
    foreach my $snp ( @snps ) {
      my $x = $snp->[1]->start - $offset - $extra;
      next if $x < 0 || $x > $len;
              
      my $type =  lc ($snp->[1]->display_consequence);
      $self->push( Sanger::Graphics::Glyph::Rect->new({
        'title'     => $snp->[1]->variation_name,
        'height'    => $TAG_LENGTH,
        'x'         => $x,
        'y'         => $yoffset - $TAG_LENGTH,
        'width'     => 1,
        'absolutey' => 1,
        'colour'    => $colours->{$type}->{'default'},
      })); 
    }
    
    # Print info line with population details
    my $pop_obj = $pop_adaptor->fetch_by_name($pop_name);
    my $parents = $pop_obj->get_all_super_Populations;
    my $name    = "LD($key): $pop_name";
    $name   .= '   ('.(join ', ', map { ucfirst(lc($_->name)) } @{$parents} ).')' if @$parents;
    $name   .= "   $number_of_snps SNPs";
    $self->push( Sanger::Graphics::Glyph::Text->new({
      'x'         => 0,
      'y'         => $yoffset - $h - $TAG_LENGTH,
      'height'    => $h,
      'halign'    => 'left',
      'font'      => $fontname,
      'ptsize'    => $fontsize,
      'colour'    => 'black',
      'text'      => $name,
      'absolutey' => 1,
      'absolutex' => 1,
      'absolutewidth'=>1,
    }));

    # Create triangle
    foreach my $m ( 0 .. ($number_of_snps-2) ) {
      my $snp_m1 = $snps[ $m+1 ];
      my $snp_m  = $snps[ $m   ];
      my $d2 = ( $snp_m1->[1]->start - $snp_m->[1]->start )/2; # m & mth SNP midpt
       
      foreach my $n ( reverse( ($m+1) .. ($number_of_snps-1) ) ) {
        my $snp_n1 = $snps[ $n-1 ];  # SNP m
        my $snp_n  = $snps[ $n   ];
        my $x  = ( $snp_m->[1]->start  + $snp_n1->[1]->start )/2 - $offset;
        my $y  = ( $snp_n1->[1]->start - $snp_m->[1]->start )/2 ;
        my $d1 = ( $snp_n->[1]->start  - $snp_n1->[1]->start )/2;

        my @points = ( [$x, $y] , [$x + $d2, $y - $d2 ] , [$x + $d1 + $d2, $y + $d1 - $d2 ] , [$x + $d1, $y + $d1 ] );

        next if( $points[2][0] <= $extra || $points[0][0] >= $len+$extra || $points[3][1] <= 0 || $points[1][1] >= $window );
        warn "---- ",$snp_m->[1]->start, "....", $snp_m1->[1]->start, ' :::: ',$snp_n->[1]->start, ' .... ', $snp_n1->[1]->start,"   [ $x $y ] [ $d1 $d2 ]";
        warn '(',join( '),(', map { "$_->[0],$_->[1]" } @points),")\n";

        @points = $self->intersect( $len, $extra, $window, @points )
          unless( $points[0][0] >= $extra && $points[2][0] <= $len+$extra && $points[1][1] >= 0 && $points[3][1] <= $window );
        warn '`-> (',join( '),(', map { "$_->[0],$_->[1]" } @points),")\n";
        warn "\n";
        next unless @points > 2 ;
        my @p2 = map { $_->[0] - $extra, $_->[1]*$height_ppb +$yoffset } @points;
        my $flag_triangle = $y-$d2;  # top box is a triangle
        my $value  = $data->{'ldContainer'}{$snp_m->[0].'-'.$snp_n->[0]}{ $pop_id }{$key};
        my $value1 = $data->{'ldContainer'}{$snp_n->[0].'-'.$snp_m->[0]}{ $pop_id }{$key};
warn " [[[ $value, $value1 ]]] ";
        my $colour = defined($value) ? $colour_gradient[POSIX::floor(40 * $value)] : "blue";
        my $snp_names = $snp_m->[1]->variation_name;
        $snp_names.= "-".$snp_n->[1]->variation_name;
        $self->push( Sanger::Graphics::Glyph::Poly->new({
          'title'  => "$snp_names: ". ($value || "n/a"),
          'points' => \@p2,
          'colour' => $colour,
          'bordercolour' => 'black'
        }));
      }
    }
    my $max_height; #$last_start - $first_start + 1;
    $max_height = $max_ld_range;# if $max_height > $max_ld_range;
    $yoffset += $max_height/2*$height_ppb;
  } # end foreach pop
}


sub intersect {
  my( $self, $len, $extra, $window, @points ) = @_;
  ## cut off less than X
  my @flags = ( $points[0][0] < $extra, $points[2][0]>$len+$extra, $points[1][1] < 0, $points[3][1] > $window );
  if( $flags[0] ) { ## left ... ( > offset )
    my @PP = @points;
    my $old = $PP[-1];
       @points = ();
    my $edge = $extra;
    foreach my $point ( @PP ) {
      push @points, [ $edge, $old->[1] + ( $edge - $old->[0] ) / ( $point->[0] - $old->[0] ) * ( $point->[1] - $old->[1] ) ]
        if ( $old->[0] < $edge && $point->[0] > $edge ) || ( $old->[0] > $edge && $point->[0] < $edge );
      push @points, $point if $point->[0] >= $edge;
      $old = $point;
    }
    return () unless @points > 2;
  }
  if( $flags[1] ) { ## right ... ( < length + offset )
    my @PP = @points;
    my $old = $points[-1];
       @points = ();
    my $edge = $extra + $len;
    foreach my $point ( @PP ) {
      push @points, [ $edge, $old->[1] + ( $edge - $old->[0] ) / ( $point->[0] - $old->[0] ) * ( $point->[1] - $old->[1] ) ]
        if ( $old->[0] < $edge && $point->[0] > $edge ) || ( $old->[0] > $edge && $point->[0] < $edge );
      push @points, $point if $point->[0] <= $edge;
      $old = $point;
    }
    return () unless @points > 2;
  }
  if( $flags[3] ) { ## BOTTOM ... ( < window )
    my @PP = @points;
    my $old = $points[-1];
       @points = ();
    my $edge = $window;
    foreach my $point ( @PP ) {
      push @points, [ $old->[0] + ( $edge - $old->[1] ) / ( $point->[1] - $old->[1] ) * ( $point->[0] - $old->[0] ) , $edge ]
        if ( $old->[1] < $edge && $point->[1] > $edge ) || ( $old->[1] > $edge && $point->[1] < $edge );
      push @points, $point if $point->[1] <= $edge;
      $old = $point;
    }
    return () unless @points > 2;
  }
  if( $flags[2] ) { ## TOP... ( > 0 )
    my @PP = @points;
    my $old = $points[-1];
       @points = ();
    my $edge = 0;
    foreach my $point ( @PP ) {
      push @points, [ $old->[0] + ( $edge - $old->[1] ) / ( $point->[1] - $old->[1] ) * ( $point->[0] - $old->[0] ) , $edge ]
        if ( $old->[1] < $edge && $point->[1] > $edge ) || ( $old->[1] > $edge && $point->[1] < $edge );
      push @points, $point if $point->[1] >= $edge;
      $old = $point;
    }
    return () unless @points > 2;
  }
  return @points;
}
1;
