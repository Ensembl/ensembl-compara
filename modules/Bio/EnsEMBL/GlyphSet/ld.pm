package Bio::EnsEMBL::GlyphSet::ld;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Poly;
use Sanger::Graphics::Glyph::Text;
use POSIX;

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
  
  my $TAG_LENGTH = 8;
  my $key = $self->_key();

  my $offset = $self->{'container'}->start - 1;
  my $data = $self->{'container'}->get_all_LD_values ;  ## returns arrayref of hashes with all the data
 
  my @snps  = sort { $a->[1]->start <=> $b->[1]->start }
              map  { [ $_ => $data->{'variationFeatures'}{$_} ] }
              keys %{ $data->{'variationFeatures'} };

  my %pop_LD   = ();
  my %pop_snps = ();
  my $number_of_snps = scalar(@snps);
  return unless $number_of_snps;
  foreach my $m ( 0 .. ($number_of_snps-2) ) {
    foreach my $n ( ($m+1) .. ($number_of_snps-1) ) {
      my $hr = $data->{'ldContainer'}{ $snps[$m][0].'-'.$snps[$n][0] };
      foreach my $pop_id ( keys %$hr ) {
        $pop_snps{ $pop_id }{ $m } = $pop_snps{ $pop_id }{ $n } = 1;
        $pop_LD{ $pop_id }{ $m }{ $n } = $pop_LD{ $pop_id }{ $n }{ $m } = $hr->{$pop_id}{$key};
      }
    } 
  }
  my @colour_gradient = ( 'green', 
    $self->{'config'}->colourmap->build_linear_gradient( 40, 'white', 'indianred2', 'red' )
  );
  my $height_ppb      = $self->{'config'}->transform()->{'scalex'};
  my $text_height     = $self->{'config'}->texthelper->height('Tiny');
  my $yoffset         = $TAG_LENGTH + $text_height;
  my $variation_db = $self->{'container'}->adaptor->db->get_db_adaptor('variation');
  my $pa = $variation_db->get_PopulationAdaptor;
  foreach my $pop_id ( $data->_get_populations ) {
    my @pop_snps = sort { $a <=> $b } keys %{$pop_snps{$pop_id}};
    my $number_of_snps = scalar( @pop_snps );

  # Get a Population by its internal identifier
    my $pop     = $pa->fetch_by_dbID($pop_id);
    my $parents = $pop->get_all_super_Populations;
    my $name    = "LD($key): ".$pop->name;
       $name   .= '   ('.(join ', ', map { ucfirst(lc($_->name)) } @{$parents} ).')' if @$parents;
       $name   .= "   $number_of_snps SNPs";
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

    foreach my $snp ( @pop_snps ) {
      $self->push( Sanger::Graphics::Glyph::Rect->new({
        'height'    => $TAG_LENGTH,
        'x'         => $snps[ $snp ]->[1]->start - $offset,
        'y'         => $yoffset - $TAG_LENGTH,
        'width'     => 1,
        'absolutey' => 1,
        'colour'    => 'black'
      })); 
    }
    foreach my $m ( 0 .. ($number_of_snps-2) ) {
      my $snp_m1 = $snps[ $pop_snps[$m+1] ];
      my $snp_m  = $snps[ $pop_snps[$m  ] ];
      my $d2 = ( $snp_m1->[1]->start - $snp_m->[1]->start )/2 ; # halfway between m and mth snp
      foreach my $n ( reverse( ($m+1) .. ($number_of_snps-1) ) ) {
        my $snp_n1 = $snps[ $pop_snps[$n-1] ];
        my $snp_n  = $snps[ $pop_snps[$n  ] ];
        my $x  = ( $snp_m->[1]->start  + $snp_n1->[1]->start )/2 - $offset ; 
        my $y  = ( $snp_n1->[1]->start - $snp_m->[1]->start )/2           ; 
	my $d1 = ( $snp_n->[1]->start  - $snp_n1->[1]->start )/2           ;
        my $flag_triangle = $y-$d2;  # top box is a triangle
        my $value = $pop_LD{ $pop_id }{ $pop_snps[$m] }{ $pop_snps[$n] };
        my $colour = defined($value) ? $colour_gradient[POSIX::floor(40 * $value)] : "blue";
           $colour ||= 'olive';
        $self->push( Sanger::Graphics::Glyph::Poly->new({
          'points' => [                           $x,         $y             * $height_ppb + $yoffset , 
		       $flag_triangle < 0 ? (): ( $x+$d2,     $flag_triangle * $height_ppb + $yoffset ), 
		                                  $x+$d1+$d2, ($y+$d1-$d2)   * $height_ppb + $yoffset , 
		                                  $x+$d1,     ($y+$d1)       * $height_ppb + $yoffset   ],
          'colour' => $colour
        }));
      }
    }
    my $W = $snps[ $pop_snps[$number_of_snps-1] ][1]->start - $snps[ $pop_snps[0] ][1]->start ;
    $yoffset += $W/2 * $height_ppb + 2 + $TAG_LENGTH + $text_height;
  }
}


1;
