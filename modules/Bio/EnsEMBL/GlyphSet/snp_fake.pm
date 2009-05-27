package Bio::EnsEMBL::GlyphSet::snp_fake;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;

  my $Config  = $self->{'config'}; 
  my $colours = $self->my_config('colours');

  my( $fontname, $fontsize ) = $self->get_font_details( 'innertext' );
  my @res = $self->get_text_width( 0, 'A', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my $w = $res[2];
  my $th = $res[3];
  my $pix_per_bp = $self->{'config'}->transform()->{'scalex'}; 
  my $snps = $Config->{'snps'};
  return unless ref $snps eq 'ARRAY'; 

  my $length    = exists $self->{'container'}{'ref'} ? $self->{'container'}{'ref'}->length : $self->{'container'}->length; 
  my $tag2 = $self->my_config('tag') + ($self->strand == -1 ? 1 : 0); 


  foreach my $snp_ref ( @$snps ) { 
    my $snp = $snp_ref->[2]; 
    my( $start,$end ) = ($snp_ref->[0], $snp_ref->[1] );
    $start = 1 if $start < 1;
    $end = $length if $end > $length;

    my $label = $snp->allele_string; 
    my @alleles = split "\/", $label;
    my  $h = 4 + ($th+2) * scalar @alleles;
    my @res = $self->get_text_width( ($end-$start+1)*$pix_per_bp, $label =~ /\w\/\w/ ? 'A/A' : $label, 'A', 'font'=>$fontname, 'ptsize' => $fontsize );
    if( $res[0] eq $label || $res[0] eq 'A/A' ) {
      $h = 8 + $th*2;
      my $tmp_width = ($w*2+$res[2]) / $pix_per_bp;
      if ( ($end - $start + 1) > $tmp_width ) {
	      $start = ( $end + $start-$tmp_width )/2;
	      $end =  $start+$tmp_width ;
      }
      if( $res[0] ne $label ) {
        @res = $self->get_text_width( ($end-$start+1)*$pix_per_bp, $label,'', 'font'=>$fontname, 'ptsize' => $fontsize );
      } 
      my $textglyph = $self->Text({
        'x'          => ( $end + $start - 1 - $res[2]/$pix_per_bp)/2,
        'y'          => ($h-$th)/2,
        'width'      => $res[2]/$pix_per_bp,
        'textwidth'  => $res[2],
        'height'     => $th,
        'font'       => $fontname,
        'ptsize'     => $fontsize,
        'colour'     => 'black',
        'text'       => $label,
        'absolutey'  => 1,
      }); ;
      $self->push( $textglyph );
    } elsif( $res[0] eq 'A' && $label =~ /^[-\w](\/[-\w])+$/ ) { ;
      for (my $i = 0; $i < 3; $i ++ ) {
        my @res = $self->get_text_width( ($end-$start+1)*$pix_per_bp, $alleles[$i],'', 'font'=>$fontname, 'ptsize' => $fontsize );
        my $tmp_width = $res[2]/$pix_per_bp;
	      my $textglyph = $self->Text({
          'x'          => ( $end + $start  - 1 - $tmp_width)/2,
          'y'          => 3 + ($th+2) * $i,
          'width'      => $tmp_width,
          'textwidth'  => $res[2],
          'height'     => $th,
          'font'       => $fontname,
          'ptsize'     => $fontsize,
          'colour'     => 'black',
          'text'       => $alleles[$i],
          'absolutey'  => 1,
				});
	      $self->push( $textglyph );
      }
    }
    my $type = lc($snp->display_consequence); 
    my $colour = $colours->{$type}->{'default'}; 
    my $tglyph = $self->Rect({
      'x' => $start-1,
      'y' => 0,
      'bordercolour' => $colour,
      'absolutey' => 1,
      'href' => $self->href($snp),
      'height' => $h,
      'width'  => $end-$start+1,
    });

    my $tag_root = $snp->dbID; 
    $self->join_tag( $tglyph, "X:$tag_root=$tag2", .5, 0, $colour,'',-3 );
    $self->push( $tglyph );

    # Colour legend stuff 
    unless($Config->{'variation_types'}{$type}) {
      push @{ $Config->{'variation_legend_features'}->{'variations'}->{'legend'}}, $colours->{$type}->{'text'},   $colours->{$type}->{'default'};
      $Config->{'variation_types'}{$type} = 1;
    }
  }
  push @{ $Config->{'variation_legend_features'}->{'variations'}->{'legend'}}, $colours->{"sara"}->[1],   $colours->{"sara"}->[0] if  $ENV{'ENSEMBL_SCRIPT'} eq 'transcriptsnpview';
}

sub href {
  my ($self, $f ) = @_;
  my $variation_id = $f->variation_name;
  my $transcript;
  foreach my $tvf (@{$f->{'transcriptVariations'}}){
   $transcript = $tvf->transcript->stable_id;
  } 
  my $dbid = $f->dbID; 
  my $href = $self->_url({'action'  => 'Variation', 'v'  => $variation_id, 'vf' => $dbid, 'vt' => $transcript, 'snp_fake' => 1});

  return $href;
}

1;
