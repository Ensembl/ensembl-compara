package Bio::EnsEMBL::GlyphSet::gsv_variations;

use strict;

use Sanger::Graphics::Bump;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my $self = shift;
  my $type = $self->type;
  
  return unless defined $type;
  return unless $self->strand == -1;

  my $config                  = $self->{'config'}; 
  my $transcript              = $config->{'transcript'}->{'transcript'};
  my ($fontname, $fontsize)   = $self->get_font_details( 'innertext');
  my $pix_per_bp              = $config->transform->{'scalex'};
  my @res                     = $self->get_text_width(0, 'M', '', font => $fontname, ptsize => $fontsize);
  my ($font_w_bp, $font_h_bp) = ($res[2] / $pix_per_bp, $res[3]);
  my $h                       = $res[3] + 4; 
  my $colour_map              = $self->my_config('colours');  
  my $offset                  = $self->{'container'}->strand > 0 ? $self->{'container'}->start - 1 :  $self->{'container'}->end + 1; 
  my $extent                  = $config->get_parameter( 'context'); 
     $extent                  = 1e6 if $extent eq 'FULL'; 
  my $seq_region_name         = $self->{'container'}->seq_region_name; 
  my $bitmap_length           = int($config->container_width * $pix_per_bp);
  my $voffset                 = 0;
  my $max_row                 = -1;
  my @bitmap;

  foreach my $snpref (@{$config->{'snps'}} ) { 
    my $snp     = $snpref->[2];
    my $dbID    = $snp->dbID;
    my $cod_snp = $config->{'transcript'}->{'snps'}->{$dbID};
    
    next unless $cod_snp;
    
    next if $snp->end < $transcript->start - $extent - $offset;
    next if $snp->start > $transcript->end + $extent - $offset;
    
    my $snp_type  = lc $cod_snp->display_consequence; 
    my $colour    = $colour_map->{$snp_type}->{'default'};
    my $aa_change = $cod_snp->pep_allele_string || '';
    my $S         = ($snpref->[0] + $snpref->[1]) / 2;
    my @res       = $self->get_text_width(0, $aa_change, '', font => $fontname, ptsize => $fontsize);
    my $width     = $res[2] / $pix_per_bp;
    my $tglyph    = $self->Text({
      x         => $S - $width /2,
      y         => $h + 4,
      height    => $font_h_bp,
      width     => $res[2] / $pix_per_bp,
      textwidth => $res[2],
      font      => $fontname,
      ptsize    => $fontsize,
      colour    => 'black',
      text      => $aa_change,
      absolutey => 1,
    });
    
    $width    += 4 / $pix_per_bp;  
    $aa_change = '-' unless $aa_change =~ /^\w+/;
    
    my $bglyph = $self->Rect({
      x         => $S - $width / 2,
      y         => $h + 2,
      height    => $h,
      width     => $width,
      colour    => $colour,
      absolutey => 1,
      href      => $self->_url({
        action  => 'Variation',
        v       => $snp->variation_name,
        vf      => $dbID,
        var_box => $aa_change,
        t_id    => $transcript->stable_id,
      })
    });
    
    my $bump_start = int($bglyph->{'x'} * $pix_per_bp);
       $bump_start = 0 if $bump_start < 0;
    my $bump_end   = $bump_start + int($bglyph->width * $pix_per_bp) + 1;
       $bump_end   = $bitmap_length if $bump_end > $bitmap_length;
       
    my $row  = Sanger::Graphics::Bump::bump_row($bump_start, $bump_end, $bitmap_length, \@bitmap);
    $max_row = $row if $row > $max_row;
    
    $tglyph->y($voffset + $tglyph->{'y'} + ($row * (2 + $h)) + 1);
    $bglyph->y($voffset + $bglyph->{'y'} + ($row * (2 + $h)) + 1);
    $self->push($bglyph, $tglyph);
  }
}

sub error_track_name { return $_[0]->species_defs->AUTHORITY . ' transcripts'; }

1;
