package Bio::EnsEMBL::GlyphSet::ld;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);
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

  # Create array of arrayrefs containing $vf_id => $vf in start order
  my $data = $self->{'container'}->get_all_LD_values($only_pop);
  my @snps  = sort { $a->[1]->start <=> $b->[1]->start }
    map  { [ $_ => $data->{'variationFeatures'}{$_} ] }
      keys %{ $data->{'variationFeatures'} };

  my $key = $self->_key();
  my $number_of_snps = scalar(@snps);
  unless( $number_of_snps > 1 ) {
    $self->errorTrack( "No LD ($key) features for this population" );
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
      'colour'    => $colours->{$snp->[1]->get_consequence_type},
    })); 
  }

  my $height_ppb      = $Config->transform()->{'scalex'};

  # Make grey outline big triangle
  # Sanger::Graphics drawing code automatically scales coords on the x axis
  #   but not on the y.  This means y coords need to be scaled by $height_ppb
  my $first_start = $snps[  0 ]->[1]->start;
  my $last_start  = $snps[ -1 ]->[1]->start;
  $self->push( Sanger::Graphics::Glyph::Poly->new({
	'points' => [
		     $last_start + 4 / $height_ppb - $offset, 
		     $yoffset -2 ,
		     $first_start - 4 / $height_ppb - $offset, 
		     $yoffset -2 , 
		     ($first_start + $last_start)/2 - $offset, 
		     2 + ($last_start - $first_start)/2 * $height_ppb + $yoffset,
		    ],
	'colour'  => 'grey',
						    }));

  # Print info line with population details
  my $pop_adaptor = $self->{'container'}->adaptor->db->get_db_adaptor('variation')->get_PopulationAdaptor;
  my $pop_obj     = $pop_adaptor->fetch_by_dbID($only_pop);
  my $parents = $pop_obj->get_all_super_Populations;
  my $name    = "LD($key): ".$pop_obj->name;
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
      my $flag_triangle = $y-$d2;  # top box is a triangle
      my $value = $data->{'ldContainer'}{$snp_m->[0].'-'.$snp_n->[0]}{ $only_pop }{$key};
      my $colour = defined($value) ? $colour_gradient[POSIX::floor(40 * $value)] : "white";
      my $snp_names = $data->{'variationFeatures'}{$snp_m->[0]}->variation_name;
      $snp_names.= "-".$data->{'variationFeatures'}{$snp_n->[0]}->variation_name;

      $self->push( Sanger::Graphics::Glyph::Poly->new({
        'title'  => "$snp_names: ". ($value || "n/a"),
        'points' => [ 
	  $x,   $y   * $height_ppb + $yoffset , 
	  $flag_triangle < 0 ?     (): 
		     ( $x+$d2,  $flag_triangle * $height_ppb + $yoffset ), 
	  $x+$d1+$d2, ($y+$d1-$d2)   * $height_ppb + $yoffset , 
	  $x+$d1,     ($y+$d1)       * $height_ppb + $yoffset   ],
	'colour' => $colour,
	#'bordercolour' => 'grey90',
      }));
    }
  }
  #&eprof_end('triangle');
  #&eprof_dump(\*STDERR);

}



1;
