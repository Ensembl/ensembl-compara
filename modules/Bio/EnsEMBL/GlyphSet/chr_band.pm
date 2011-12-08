package Bio::EnsEMBL::GlyphSet::chr_band;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my $self = shift;

  return $self->render_text if $self->{'text_export'};
  
  ########## only draw contigs once - on one strand
  
  my ($fontname, $fontsize) = $self->get_font_details('innertext');
  my $bands      = $self->{'container'}->get_all_KaryotypeBands; # fetch the chromosome bands that cover this VC.
  my $h          = [ $self->get_text_width(0, 'X', '', font => $fontname, ptsize => $fontsize) ]->[3];
  my $pix_per_bp = $self->{'config'}->transform->{'scalex'};
  my @t_colour   = qw(gpos25 gpos75);
  my $chr        = scalar @$bands ? $bands->[0]->slice->seq_region_name : '';
  my @bands      = sort { $a->start <=> $b->start } @$bands;
  
  foreach my $band (@bands) {
    my $bandname      = $band->name;
       $bandname      =~ /(\d+)\w?/;
    my $band_no       = $1;
    my $start         = $band->start;
    my $end           = $band->end;
    my $stain         = $band->stain;
    my $vc_band_start = $start;
       $vc_band_start = 1 if $vc_band_start < 1;
    my $vc_band_end   = $end;
       $vc_band_end   = $self->{'container'}->length if $vc_band_end > $self->{'container'}->length;
    my $vc_adjust     = 1 - $self->{'container'}->start;
    my $band_start    = $start - $vc_adjust;
    my $band_end      = $end   - $vc_adjust;
    my $col           = $self->my_colour($stain);
    my $fontcolour    = $self->my_colour($stain, 'label') || 'black';
    
    if (!$stain) {
      $stain      = shift @t_colour;
      $col        = $self->my_colour($stain);
      $fontcolour = $self->my_colour($stain, 'label');
      
      push @t_colour, ($stain = shift @t_colour);
    }
    
    $self->push($self->Rect({
      x            => $vc_band_start - 1 ,
      y            => 0,
      width        => $vc_band_end - $vc_band_start + 1 ,
      height       => $h + 4,
      colour       => $col || 'white',
      absolutey    => 1,
      title        => "Band: $bandname",
      href         => $self->_url({ r => "$chr:$band_start-$band_end" }),
      bordercolour => 'black'
    }));
    
    if ($fontcolour ne 'invisible') {
      my @res = $self->get_text_width(($vc_band_end - $vc_band_start + 1) * $pix_per_bp, $bandname, '', font => $fontname, ptsize => $fontsize);
      
      # only add the lable if the box is big enough to hold it
      if ($res[0]) {
        $self->push($self->Text({
          x         => ($vc_band_end + $vc_band_start - 1 - $res[2]/$pix_per_bp) / 2,
          y         => 1,
          width     => $res[2] / $pix_per_bp,
          textwidth => $res[2],
          font      => $fontname,
          height    => $h,
          ptsize    => $fontsize,
          colour    => $fontcolour,
          text      => $res[0],
          absolutey => 1,
        }));
      }
    }
  }
  
  $self->no_features unless @bands;
}

sub render_text {
  my $self  = shift;
  my @bands = sort { $a->start <=> $b->start } @{$self->{'container'}->get_all_KaryotypeBands||[]};
  my $export;
  
  foreach (@bands) {
    $export .= $self->_render_text($_, 'Chromosome band', { 
      headers => [ 'name' ], 
      values  => [ $_->name ] 
    });
  }
  
  return $export;
}

1;
