package Bio::EnsEMBL::GlyphSet::ld;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Poly;
use Sanger::Graphics::Glyph::Text;
use POSIX;
use Data::Dumper;

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
  my $only_pop = 0; #$Config->{'_ld_population'};
  my $TAG_LENGTH = 8;
  my $key = $self->_key();
  my $offset = $self->{'container'}->start - 1;
  my $data = $self->{'container'}->get_all_LD_values; 

  #Create array of arrayrefs containing $vf_id => $vf in start order
  my @snps  = sort { $a->[1]->start <=> $b->[1]->start }
    map  { [ $_ => $data->{'variationFeatures'}{$_} ] }
      keys %{ $data->{'variationFeatures'} };

  my $number_of_snps = scalar(@snps);
  $self->errorTrack( "No LD ($key) features in this region" ) unless $number_of_snps;
  return unless $number_of_snps;

  my %pop_LD   = ();
  my %pop_snps = ();
  foreach my $m ( 0 .. ($number_of_snps-2) ) {
    foreach my $n ( ($m+1) .. ($number_of_snps-1) ) {

      #$data->{ldContainer}=>{$vf1_id - $vf2_id}{pop_id}{hash of ld info}
      if ($only_pop) {
#	warn "here is pop $only_pop\n";
	$only_pop = 140;
	my $ld_hash = $data->{'ldContainer'}{ $snps[$m][0].'-'.$snps[$n][0] }{$only_pop};
      }

      my $hr = $data->{'ldContainer'}{ $snps[$m][0].'-'.$snps[$n][0] };
	#warn Data::Dumper::Dumper($hr);
      
      if ($only_pop) {
	$pop_snps{ $only_pop}{ $m } = $pop_snps{ $only_pop }{ $n } = 1;
	$pop_LD{ $only_pop }{ $m }{ $n } = $pop_LD{ $only_pop }{ $n }{ $m } = $hr->{$only_pop}{$key};
      }
      else {
	foreach my $pop_id ( keys %$hr ) {
	  $pop_snps{ $pop_id }{ $m } = $pop_snps{ $pop_id }{ $n } = 1;
	  $pop_LD{ $pop_id }{ $m }{ $n } = $pop_LD{ $pop_id }{ $n }{ $m } = $hr->{$pop_id}{$key};
	}
      }
    } 
  }
  my @colour_gradient = ( 'white', 
    $Config->colourmap->build_linear_gradient( 40, 'pink', 'indianred2', 'red' )
  );
  my $height_ppb      = $Config->transform()->{'scalex'};
  my $text_height     = $Config->texthelper->height('Tiny');
  my $yoffset         = $TAG_LENGTH + $text_height;
  my $variation_db    = $self->{'container'}->adaptor->db->get_db_adaptor('variation');
  my $pa = $variation_db->get_PopulationAdaptor;

  foreach my $pop_id ( $data->_get_populations ) {
    if ($only_pop) {
      next unless $pop_id eq $only_pop;
    }
    my @pop_snps     = sort { $a <=> $b } keys %{$pop_snps{$pop_id}};
    my $snps_per_pop = scalar( @pop_snps );  ## was number_of_snps
    next unless $snps_per_pop >1;

    # Get a Population by its internal identifier
    my $pop     = $pa->fetch_by_dbID($pop_id);
    my $parents = $pop->get_all_super_Populations;
    my $name    = "LD($key): ".$pop->name;
    $name   .= '   ('.(join ', ', map { ucfirst(lc($_->name)) } @{$parents} ).')' if @$parents;
    $name   .= "   $snps_per_pop SNPs"; ## was number_of_snps
    $self->push(new Sanger::Graphics::Glyph::Text({
      'x'         => 0,
      'y'         => $yoffset - $text_height - $TAG_LENGTH,
      'height'    => 0,
      'font'      => 'Tiny',
      'colour'    => 'black',
      'text'      => $name,
      'absolutey' => 1,
      'absolutex' => 1,'absolutewidth'=>1,
    }));

    # Print GlyphSet::variation type bars above ld triangle
    my $colours = $self->my_config( 'colours');
    foreach my $snp ( @pop_snps ) {
      $self->push( Sanger::Graphics::Glyph::Rect->new({
        'title'     => $snps[ $snp ]->[1]->variation->name,
        'height'    => $TAG_LENGTH,
        'x'         => $snps[ $snp ]->[1]->start - $offset,
        'y'         => $yoffset - $TAG_LENGTH,
        'width'     => 1,
        'absolutey' => 1,
        'colour'    => $colours->{$snps[ $snp ]->[1]->consequence_type},
      })); 
    }

    my $first_start =  $snps[ $pop_snps[0] ]->[1]->start;
    my $last_start  = $snps[ $pop_snps[-1]]->[1]->start;
    $self->push( Sanger::Graphics::Glyph::Poly->new({
	'points' => [
		     $last_start + 4 / $height_ppb - $offset, $yoffset -2 ,
		     $first_start - 4 / $height_ppb - $offset, $yoffset -2 , 
		     ($first_start + $last_start)/2 - $offset, 
		     2 + ($last_start - $first_start)/2 * $height_ppb + $yoffset,
		    ],
	'colour'  => 'grey',

						    }));
    foreach my $m ( 0 .. ($snps_per_pop-2) ) {
      my $snp_m1 = $snps[ $pop_snps[$m+1] ];
      my $snp_m  = $snps[ $pop_snps[$m  ] ];
      my $d2 = ( $snp_m1->[1]->start - $snp_m->[1]->start )/2 ; # halfway between m and mth snp
      foreach my $n ( reverse( ($m+1) .. ($snps_per_pop-1) ) ) {
        my $snp_n1 = $snps[ $pop_snps[$n-1] ];
        my $snp_n  = $snps[ $pop_snps[$n  ] ];
        my $x  = ( $snp_m->[1]->start  + $snp_n1->[1]->start )/2 - $offset ; 
        my $y  = ( $snp_n1->[1]->start - $snp_m->[1]->start )/2           ; 
	my $d1 = ( $snp_n->[1]->start  - $snp_n1->[1]->start )/2           ;
        my $flag_triangle = $y-$d2;  # top box is a triangle
        my $value = $pop_LD{ $pop_id }{ $pop_snps[$m] }{ $pop_snps[$n] };
        my $colour = defined($value) ? $colour_gradient[POSIX::floor(40 * $value)] : "grey";
        $self->push( Sanger::Graphics::Glyph::Poly->new({
          'title'  => $value,
          'points' => [ 
		       $x,   $y   * $height_ppb + $yoffset , 
		       $flag_triangle < 0 ? (): ( $x+$d2,     $flag_triangle * $height_ppb + $yoffset ), 
		       $x+$d1+$d2, ($y+$d1-$d2)   * $height_ppb + $yoffset , 
		       $x+$d1,     ($y+$d1)       * $height_ppb + $yoffset   ],
							 'colour' => $colour
							}));
      }
    }
    my $W = $snps[ $pop_snps[$snps_per_pop-1] ][1]->start - $snps[ $pop_snps[0] ][1]->start ;
    $yoffset += $W/2 * $height_ppb + 2 + $TAG_LENGTH + $text_height;
  }  # end pop id
}



1;
