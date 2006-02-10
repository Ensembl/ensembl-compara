package Bio::EnsEMBL::GlyphSet::ld;
use strict;
use Bio::EnsEMBL::GlyphSet;
our @ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Poly;
use Sanger::Graphics::Glyph::Text;
use POSIX;
use Data::Dumper;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump); 

use Time::HiRes qw( time );

sub init_label {
  my $self = shift;
  my $key = $self->_key();
  $self->label(new Sanger::Graphics::Glyph::Text({
    'text'      => "LD ($key)",
    'font'      => 'Small',
    'absolutey' => 1,
  }));
}

sub _key { return $_[0]->my_config('key') || 'r2'; }

sub _init {
  my ($self) = @_;
  return unless ($self->strand() == -1);
  my $Config   = $self->{'config'};
  my $only_pop = $Config->{'_ld_population'};
  warn "****[ERROR]: No population defined in config $0" unless $only_pop;
  return;

  # Create array of arrayrefs containing $vf_id => $vf in start order
  my $data = $self->{'container'}->get_all_LD_values($only_pop);
  my @snps  = sort { $a->[1]->start <=> $b->[1]->start }
    map  { [ $_ => $data->{'variationFeatures'}{$_} ] }
      keys %{ $data->{'variationFeatures'} };

  my $key = $self->_key();
  my $number_of_snps = scalar(@snps);
  my $pop_adaptor = $self->{'container'}->adaptor->db->get_db_adaptor('variation')->get_PopulationAdaptor;
  my $pop_obj     = $pop_adaptor->fetch_by_dbID($only_pop);
  my $pop_name    = $pop_obj->name if $pop_obj;
  my $length      = ($self->{'container'}->length -1)/1000;
  my $max_ld_range = 100000;

  unless( $number_of_snps > 1 ) {
    $self->errorTrack( "No $key linkage data in $length kb window for population $pop_name" );
    return;
  }

  # Print GlyphSet::variation type bars above ld triangle
  my $text_height     = $Config->texthelper->height('Tiny');
  my $TAG_LENGTH      = 10;
  my $yoffset         = $TAG_LENGTH + $text_height;
  my $offset          = $self->{'container'}->start - 1;
  my $colours         = $self->my_config( 'colours');
  foreach my $snp ( @snps ) {
     $self->push( Sanger::Graphics::Glyph::Rect->new({
      'title'     => $snp->[1]->variation_name,
      'height'    => $TAG_LENGTH,
      'x'         => $snp->[1]->start - $offset,
      'y'         => $yoffset - $TAG_LENGTH,
      'width'     => 1,
      'absolutey' => 1,
      'colour'    => $colours->{$snp->[1]->get_consequence_type}->[0],
    })); 
  }

  my $height_ppb      = $Config->transform()->{'scalex'};

  # Make grey outline big triangle
  # Sanger::Graphics drawing code automatically scales coords on the x axis
  #   but not on the y.  This means y coords need to be scaled by $height_ppb
  my $first_start = $snps[  0 ]->[1]->start;
  my $last_start  = $snps[ -1 ]->[1]->start;
  my @points = (  $last_start + 4 / $height_ppb - $offset,  $yoffset -2 ,
                     $first_start - 4 / $height_ppb - $offset, $yoffset -2 );
  if( $max_ld_range < ($last_start-$first_start)) {
    push @points,  $first_start + $max_ld_range/2 - $offset, 2 + $max_ld_range/2 * $height_ppb + $yoffset;
    push @points,  $last_start - $max_ld_range/2 - $offset, 2 + $max_ld_range/2 * $height_ppb + $yoffset;
  } else {
    push @points,  ($first_start + $last_start)/2 - $offset,
                     2 + ($last_start - $first_start)/2 * $height_ppb + $yoffset
  }
  $self->push( Sanger::Graphics::Glyph::Poly->new({
	'points' => \@points,
	'colour'  => 'grey',
						    }));

  # Print info line with population details
  my $parents = $pop_obj->get_all_super_Populations;
  my $name    = "LD($key): $pop_name";
  $name   .= '   ('.(join ', ', map { ucfirst(lc($_->name)) } @{$parents} ).')' if @$parents;
  $name   .= "   $number_of_snps SNPs";
  $self->push( Sanger::Graphics::Glyph::Text->new({
      'x'         => 0,
      'y'         => $yoffset - $text_height - $TAG_LENGTH,
      'height'    => 0,
      'font'      => 'Tiny',
      'colour'    => 'black',
      'text'      => $name,
      'absolutey' => 1,
      'absolutex' => 1,'absolutewidth'=>1,
						  }));

  #  &eprof_start('triangle');
  # Create triangle
  my @colour_gradient = $Config->colourmap->build_linear_gradient( 41,'mistyrose', 'pink', 'indianred2', 'red' );
  foreach my $m ( 0 .. ($number_of_snps-2) ) {
    my $snp_m1 = $snps[ $m+1 ];
    my $snp_m  = $snps[ $m   ];
    my $d2 = ( $snp_m1->[1]->start - $snp_m->[1]->start )/2; # m & mth SNP midpt
    foreach my $n ( reverse( ($m+1) .. ($number_of_snps-1) ) ) {
      my $snp_n1 = $snps[ $n-1 ];  # SNP m
      my $snp_n  = $snps[ $n   ];
      my $x  = ( $snp_m->[1]->start  + $snp_n1->[1]->start )/2 - $offset ;
      my $y  = ( $snp_n1->[1]->start - $snp_m->[1]->start )/2           ;
      my $d1 = ( $snp_n->[1]->start  - $snp_n1->[1]->start )/2           ;
      my @points = ( [$x, $y ] , [$x + $d2, $y - $d2 ] , [$x + $d1 + $d2, $y + $d1 - $d2 ] , [$x + $d1, $y + $d1 ] );
      next if $points[1][1] >= $max_ld_range / 2; # Off the top!!
      if( $points[1][1]<=0 || $points[3][1]>= $max_ld_range / 2 ) {
        @points = $self->intersect( $max_ld_range/2, @points );
      }
      next unless @points > 2; 
      my @p2 = map { $_->[0], $_->[1]*$height_ppb +$yoffset } @points;
      my $flag_triangle = $y-$d2;  # top box is a triangle
      my $value = $data->{'ldContainer'}{$snp_m->[0].'-'.$snp_n->[0]}{ $only_pop }{$key};
      my $colour = defined($value) ? $colour_gradient[POSIX::floor(40 * $value)] : "white";
      my $snp_names = $data->{'variationFeatures'}{$snp_m->[0]}->variation_name;
      $snp_names.= "-".$data->{'variationFeatures'}{$snp_n->[0]}->variation_name;

      $self->push( Sanger::Graphics::Glyph::Poly->new({
        'title'  => "$snp_names: ". ($value || "n/a"),
        'points' => \@p2,
	'colour' => $colour,
	#'bordercolour' => 'grey90',
      }));
    }
  }
  #&eprof_end('triangle');
  #&eprof_dump(\*STDERR);

}

sub intersect {
  my( $self, $height, @points ) = @_;
  ## cut off less than X
  my @PP = @points;
  if( $points[1][1]<0 ) {
    my $old = $points[-1];
       @points = ();
    my $edge = 0;
    foreach my $point ( @PP ) {
      next if $point->[1] < 0;
      push @points, $point;
    }
    return () unless @points > 2;
  }
  if( $PP[3][1] > $height ) {
    my @PP = @points;
    my $old = $points[-1];
       @points = ();
    my $edge = $height;
    foreach my $point ( @PP ) {
      push @points, [ $old->[0] + ( $edge - $old->[1] ) / ( $point->[1] - $old->[1] ) * ( $point->[0] - $old->[0] ) , $edge ]
        if ( $old->[1] < $edge && $point->[1] > $edge ) || ( $old->[1] > $edge && $point->[1] < $edge );
      push @points, $point if $point->[1] <= $edge;
      $old = $point;
    }
    return () unless @points > 2;
  }
  return @points;
}


1;
