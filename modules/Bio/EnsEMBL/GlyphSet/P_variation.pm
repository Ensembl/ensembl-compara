package Bio::EnsEMBL::GlyphSet::P_variation;
use strict;
no warnings "uninitialized";
use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;
  my $protein = $self->{'container'};
  my $snps    = $self->cache('image_snps');
  my $x       = 0;
  my $y       = 0;
  my $h       = $self->my_config('height')||4;
  my $key        = "Prot SNP";    
  my $last_indel = '##############';
  my $pix_per_bp = $self->scalex;
  my $t_width    = $h*3/4/$pix_per_bp;
  $self->_init_bump( undef,  $self->my_config('depth')||1e6 );

  return unless $snps;
  foreach my $int (@$snps) {
    $x++;
    next if $last_indel eq $int->{'indel'};
    my $id     = $int->{'type'}; 
    if( $int->{'type'} eq 'insert' || $int->{'type'} eq 'delete' ) {
      my( $in,$out,$end ) = $int->{'type'} eq 'insert' ? ($h,0,1) : (0,$h, length $int->{'allele'});
      my $glyph = $self->Poly({
        'x'             => $x-$t_width,
        'y'        => 0,
        'width'         => $t_width * 2,
        'points'        => [ $x-$t_width, $out, $x, $in, $x+$t_width, $out  ],
        'colour'        => $self->my_colour( 'insert' ),
        'absolutey'     => 1,
        'href'          => $self->_url({ 'type' => 'Variation', 'action' => 'Variation', 'v' => $int->{'snp_id'}, 'vf' => $int->{'vdbid'}, 'snp_fake' => 1 }),
        'title'         => sprintf( '%sion %s; %s: %s; Position: %d-%d; Length: %d',
          uc($int->{'type'}), $int->{'snp_id'},
          uc($int->{'type'}), $int->{'allele'}, $x, $x+$end, length( $int->{'allele'} )
        ),
      });
      my $bump_start = int( $glyph->x() * $pix_per_bp );
      my $bump_end   = $bump_start + $glyph->width() + 3;
      my $row        = $self->bump_row( $bump_start, $bump_end );
      $glyph->y_transform(1.5 * $row * ($h+2));
      $self->push( $glyph );
      $last_indel =  $int->{'indel'};
    } elsif( $int->{'type'} eq 'snp' || $int->{'type'} eq 'syn' ){  
      my $type = $int->{'type'} eq 'snp' ? 'Non-synonymous' : 'Synonymous' ;
      my $snp  = '';
      my $type = 'Synonymous';
      if( $int->{'type'} eq 'snp' ) {
        $type = 'Non-synonymous';
        $snp  = "Alternative Residues: ". $int->{'pep_snp'}."; ";
      }
      $snp .= "Codon: ";
      for my $letter ( 0..2 ){
        $snp .= $int->{'ambigcode'}[$letter]  ? '['.$int->{'ambigcode'}[$letter].']' : $int->{'nt'}[$letter];   
      }
      my $glyph = $self->Rect({
        'x'        => $x-$h/2,
        'y'        => 0,
        'width'    => $h,
        'height'   => $h,
        'colour'   => $self->my_colour( $int->{'type'} ),
        'absolutey' => 1,
        'absolutewidth' => 1,
        'href'          => $self->_url({ 'type' => 'Variation', 'action' => 'Variation', 'v' => $int->{'snp_id'}, 'vf' => $int->{'vdbid'}, 'snp_fake' => 1 }),
        'title'         => sprintf( '%s SNP %s; Type: %s; Residue: %d; %s; Alleles: %s',
          $type, $int->{'snp_id'}, $int->{'allele'}, $x, $snp, $int->{'allele'}
        )
      });
      my $bump_start = int( $glyph->x() * $pix_per_bp );
      my $bump_end   = $bump_start + $glyph->width() + 3;
      my $row        = $self->bump_row( $bump_start, $bump_end );
      $glyph->y($glyph->y + 1.5 * $row * ($h+2) );
      $self->push( $glyph );
    } else {
      next;
    }
  }
}
1;




















