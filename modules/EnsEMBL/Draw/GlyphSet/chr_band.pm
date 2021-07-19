=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Draw::GlyphSet::chr_band;

### Draws chromosome band track on horizontal Location images

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Draw::GlyphSet);

sub label_overlay   { return 1; }
sub default_colours { return $_[0]{'default_colours'} ||= [ 'gpos25', 'gpos75' ]; }

sub colour_key {
  my ($self, $f) = @_;
  my $key = $self->{'colour_key'}{$f} || $f->stain;
  
  if (!$key) {
    $self->{'colour_key'}{$f} = $key = shift @{$self->default_colours};
    push @{$self->default_colours}, $key;
  }
  
  return $key;
}

sub _init {
  my $self = shift;

  return $self->render_text if $self->{'text_export'};
  
  ########## only draw contigs once - on one strand
  
  my ($fontname, $fontsize) = $self->get_font_details('innertext');
  my $bands      = $self->features;
  my $h          = [ $self->get_text_width(0, 'X', '', font => $fontname, ptsize => $fontsize) ]->[3];
  my $pix_per_bp = $self->scalex;
  my @t_colour   = qw(gpos25 gpos75);
  my $length     = $self->{'container'}->length;
  
  foreach my $band (@$bands) {
    my $label      = $self->feature_label($band);
    my $colour_key = $self->colour_key($band);
    my $start      = $band->start;
    my $end        = $band->end;
       $start      = 1       if $start < 1;
       $end        = $length if $end   > $length;
    
    $self->push($self->Rect({
      x            => $start - 1 ,
      y            => 0,
      width        => $end - $start + 1 ,
      height       => $h + 4,
      colour       => $self->my_colour($colour_key) || 'white',
      absolutey    => 1,
      title        => $label ? "Band: $label" : '',
      href         => $self->href($band),
      bordercolour => 'black'
    }));
    
    if ($label) {
      my @res = $self->get_text_width(($end - $start + 1) * $pix_per_bp, $label, '', font => $fontname, ptsize => $fontsize);
      
      # only add the lable if the box is big enough to hold it
      if ($res[0]) {
        $self->push($self->Text({
          x         => ($end + $start - 1 - $res[2]/$pix_per_bp) / 2,
          y         => 1,
          width     => $res[2] / $pix_per_bp,
          textwidth => $res[2],
          font      => $fontname,
          height    => $h,
          ptsize    => $fontsize,
          colour    => $self->my_colour($colour_key, 'label') || 'black',
          text      => $res[0],
          absolutey => 1,
        }));
      }
    }
  }
  
  $self->no_features unless scalar @$bands;
}

sub render_text {
  my $self = shift;
  my $export;
  
  foreach (@{$self->features}) {
    $export .= $self->_render_text($_, 'Chromosome band', { 
      headers => [ 'name' ], 
      values  => [ $_->name ] 
    });
  }
  
  return $export;
}

sub features {
  my $self = shift;
  return [ sort { $a->start <=> $b->start } @{$self->{'container'}->get_all_KaryotypeBands || []} ];
}

sub href {
  my ($self, $band) = @_;
  my $slice = $band->project('toplevel')->[0]->to_Slice;
  return $self->_url({ r => sprintf('%s:%s-%s', map $slice->$_, qw(seq_region_name start end)) });
}

sub feature_label {
  my ($self, $f) = @_;
  return $self->my_colour($self->colour_key($f), 'label') eq 'invisible' ? '' : $f->name;
}

1;
