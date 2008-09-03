package Bio::EnsEMBL::GlyphSet::ld2;
use strict;
use Bio::EnsEMBL::GlyphSet;
our @ISA = qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;
  return unless ($self->strand() == -1);
  my $Container      = $self->{'container'};
    
  my $contig_strand  = $Container->can('strand') ? $Container->strand : 1;
  my $h              = 0;
  my $pix_per_bp     = $self->{'config'}->transform()->{'scalex'};
  my $window         = $self->my_config( 'window_size' ) || ($self->my_config( 'pixel_height' )/$pix_per_bp) || 5000;
  my $extra          = defined( $self->my_config( 'flanking') ) ? $self->my_config( 'flanking') : ($window * 2);
  my $seq            = $Container->expand($extra,$extra);
  my $len            = $Container->length;

  my @snps = map { $_->start } sort { $a->start <=> $b->start } grep { $_->score < 4 } 
     @{ $self->my_config( 'source') eq 'genotyped' ? $seq->get_all_genotyped_SNPs() : $seq->get_all_SNPs() };
  return unless @snps;          ## No SNPs at all...

  my $start_snp = 0;
  my $end_snp   = 0;
  foreach (@snps) {
    $start_snp ++ if( $_ < $extra - $window );
    $end_snp   ++;
    last          if( $_ > $extra + 2 * $window + $len );
  }
  return unless $end_snp;          ## SNPS but all to the right of the interval...
  return if $end_snp == $start_snp; ## SNPS but all to the left of the interval...
  $start_snp-- if $start_snp;
  $end_snp-- ;
  my $number_of_colours = $self->my_config('colourmapsize') || 40;
  my @colours           = @{$self->my_config('colours')||[]};
     @colours = qw(blue green yellow orange red) unless @colours;
  my @range      = $self->{'config'}->colourmap->build_linear_gradient( $number_of_colours, @colours );

  warn "0 - $start_snp - $end_snp - ",scalar(@snps);
  foreach my $m ( $start_snp .. $end_snp ) {
    my $d2 = ( $snps[$m+1] - $snps[$m] )/2;
    foreach my $n ( reverse ($m .. $end_snp) ) {
      my( $x, $y, $d1 ) = ( 
        ( $snps[$n]+    $snps[$m] )/2,
        ( $snps[$n]   - $snps[$m] )/2,
        ( $snps[$n+1] - $snps[$n] )/2
      );
      my @points = ( [$x, $y ] , [$x + $d2, $y - $d2 ] , [$x + $d1 + $d2, $y + $d1 - $d2 ] , [$x + $d1, $y + $d1 ] );
      next if( $points[2][0] <= $extra || $points[0][0] >= $len+$extra || $points[3][1] <= 0 || $points[1][1] >= $window );
      @points = $self->intersect( $len, $extra, $window, @points )
        unless( $points[0][0] >= $extra && $points[2][0] <= $len+$extra && $points[1][1] >= 0 && $points[3][1] <= $window );
      next unless @points > 2 ;
      my @p2 = map { ( $_->[0]-$extra, $_->[1] * $pix_per_bp ) } @points;
      $self->push( Sanger::Graphics::Glyph::Poly->new({
        'points' => \@p2,
        'colour' => $range[int( 1 + ($number_of_colours-2) * rand() )],
      }));
    }
  }
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
