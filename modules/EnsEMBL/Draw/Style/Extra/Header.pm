=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::Style::Extra::Header;

### 'Helper' module to draw extra header(s) on tracks

use strict;
use warnings;

use EnsEMBL::Draw::Utils::Text;

use parent qw(EnsEMBL::Draw::Style);

sub create_glyphs { 
## Stub - there are no default glyphs, so you need to call your chosen method explicitly
}

sub draw_margin_subhead {
### Draws a subheader in the lefthand margin, e.g. regulatory features
  my ($self, $text, $tracks_on) = @_;

  $self->_draw_track_name($text, 'black', -118, undef);
  if ($tracks_on) {
    $self->_draw_track_name($tracks_on, 'grey40', -118, 0);
  } else {
    $self->_draw_space_glyph;
  }
}

sub draw_margin_sublabels {
  my ($self,$track) = @_;

  foreach my $s (@$track) {
    $s->{'metadata'}{'y'} = $self->_offset;
    $self->_draw_track_name($s->{'metadata'}{'sublabel'}||'',$s->{'metadata'}{'colour'},-118,0);
    $s->{'metadata'}{'height'} = $self->_offset - $s->{'metadata'}{'y'};
  }
}

sub _draw_track_name {
  ### Draws the name of the predicted features track
  ### @param arrayref of Feature objects
  ### @param colour of the track
  ### @return 1
  my ($self, $name, $colour, $x_offset, $y_offset, $no_offset) = @_;
  my $x  = $x_offset || 1;
  my $y  = $self->_offset;
  $y    += $y_offset if $y_offset;

  ## Use smaller text than usual
  my %font_details = EnsEMBL::Draw::Utils::Text::get_font_details($self->image_config, 'innertext', 1);

  ## Truncate name if it's wider than our offset
  my @res_analysis;
  while ($name) {
    @res_analysis = EnsEMBL::Draw::Utils::Text::get_text_width($self->cache, $self->image_config, 0, $name, '', %font_details);
    last if ($res_analysis[2] < -$x_offset);
    $name = substr($name, 0, -1);
  }

  if ($colour) {
    $colour = $self->make_readable($colour);
  }
  else {
    $colour = 'black';
  }

  push @{$self->glyphs}, $self->Text({
                                      x         => $x,
                                      y         => $y,
                                      height    => $res_analysis[3],
                                      width     => $res_analysis[2],
                                      halign    => 'left',
                                      valign    => 'bottom',
                                      text      => $name,
                                      colour    => $colour,
                                      absolutey => 1,
                                      absolutex => 1,
                                      %font_details,
                                    });

  $self->_offset($res_analysis[3]) unless $no_offset;

  return 1;
}

sub _draw_space_glyph {
  ### Draws a an empty glyph as a spacer
  ### @param (optional) integer for space height
  ### @return Void

  my ($self, $space) = @_;
  $space ||= 9;

  push @{$self->glyphs}, $self->Space({
                                        height    => $space,
                                        width     => 1,
                                        y         => $self->_offset,
                                        x         => 0,
                                        absolutey => 1,  # puts in pix rather than bp
                                        absolutex => 1,
                                      });

  $self->_offset($space);
}


sub _offset {
  ### Getter/setter for offset
  ### @param (optional) number to add to offset
  ### @return integer

  my ($self, $offset) = @_;
  $self->{'offset'} += $offset if $offset;
  return $self->{'offset'} || 0;
}

1;  
