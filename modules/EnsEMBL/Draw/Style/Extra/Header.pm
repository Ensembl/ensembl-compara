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

package EnsEMBL::Draw::Style::Extra::Header;

### 'Helper' module to draw extra header(s) on tracks

use strict;
use warnings;

use EnsEMBL::Draw::Utils::Text;

use parent qw(EnsEMBL::Draw::Style::Extra);

our $x_offset = -118;

sub draw_margin_subhead {
### Draws a subheader in the lefthand margin, e.g. regulatory features
  my ($self, $text, $tracks_on) = @_;

  my $height = $self->_draw_name($text, 'black', $x_offset);
  if ($tracks_on) {
    $height += $self->_draw_name($tracks_on, 'grey40', $x_offset);
  } else {
    $height += $self->_draw_space_glyph;
  }
  return $height;
}

sub draw_margin_sublabels {
  my ($self, $track, $offset) = @_;
  $offset ||= 0;
  my $y_offset = 0;
  foreach my $s (@$track) {
    next if (scalar @{$s->{'features'}} == 0 && $self->image_config->get_option('opt_empty_tracks') == 0);
    $self->_draw_name($s->{'metadata'}{'sublabel'}, $s->{'metadata'}{'colour'}, $x_offset, $y_offset);
    $y_offset += $offset;
  }
}

sub draw_sublegend {
  my ($self,$args) = @_;

  my $zmenu = $self->_sublegend_zmenu($args);
  $self->_draw_sublegend_box($args,$zmenu);
}

sub _draw_name {
  ### Draws the name of the track
  ### @param arrayref of Feature objects
  ### @param colour of the track
  ### @return 1
  my ($self, $name, $colour, $x_offset, $y_offset, $no_offset) = @_;
  $name ||= '';
  $colour ||= 'black';

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
  my $text_height  = $res_analysis[3];
  
  ## Fix colour
  if ($colour) {
    $colour = $self->make_readable($colour);
  }
  else {
    $colour = 'black';
  }

  push @{$self->glyphs}, $self->Text({
                                      x         => $x,
                                      y         => $y,
                                      height    => $text_height,
                                      width     => $res_analysis[2],
                                      halign    => 'left',
                                      valign    => 'middle',
                                      text      => $name,
                                      colour    => $colour,
                                      absolutey => 1,
                                      absolutex => 1,
                                      %font_details,
                                    });

  ## Make sure this label is the same overall height as the feature
  my $feature_height = $self->track_config->get('real_feature_height') || 0;
  my $offset = $feature_height > $text_height ? $feature_height : $text_height;
  $self->_offset($offset) unless $no_offset;

  return $offset;
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
  return $space;
}

sub _sublegend_zmenu_text {
  my ($self,$args) = @_;

  my @out;
  foreach my $label (sort keys %{$args->{'colour_legend'}||{}}) {
    push @out, sprintf '<span style="width:24px;height:12px;background-color:#%s;margin-right:8px;display:inline-block"></span>%s', $args->{'colour_legend'}{$label}, $label;;
  }
  if ($args->{'show_peaks'}) {
    push @out, '<img src="/i/16/collapse.png" style="margin-right:4px">Peak';
  }
  return @out;
}

## Contents of the ZMenu of the special box found on reg. multi-wiggles
sub _sublegend_zmenu {
  my ($self,$args) = @_;

  my @entries = $self->_sublegend_zmenu_text($args);
  my $title = $args->{'title'} || 'Info';
  $title =~ s/&/and/g; # amps problematic; not just a matter of encoding
  foreach my $link (@{$args->{'sublegend_links'}||[]}) {
    push @entries, qq(<a href="$link->{'href'}" class="$link->{'class'}" rel="$link->{'rel'}">$link->{'text'}</a>);
  }
  return [$title, @entries];
}

sub _draw_sublegend_box {
  my ($self,$args,$zmenu) = @_;

  my $offset = $self->_offset;
  $offset   += $args->{'y_offset'} || 0;
 
  my $click_text = $args->{'label'} || 'Details';
  my %font_details = EnsEMBL::Draw::Utils::Text::get_font_details($self->image_config,'innertext', 1);
  my ($width,$height) = $self->get_text_dimensions($click_text, \%font_details);

  push @{$self->glyphs}, $self->Rect({
    width         => $width + 15,
    absolutewidth => $width + 15,
    height        => $height + 2,
    y             => $offset + 13,
    x             => -117,
    absolutey     => 1,
    absolutex     => 1,
    title         => join('; ',@$zmenu),
    class         => 'coloured',
    bordercolour  => '#336699',
    colour        => 'white',
  }), $self->Text({
    text      => $click_text,
    height    => $height,
    halign    => 'left',
    valign    => 'bottom',
    colour    => '#336699',
    y         => $offset + 10,
    x         => -116,
    absolutey => 1,
    absolutex => 1,
    %font_details,
  }), $self->Triangle({
    width     => 6,
    height    => 5,
    direction => 'down',
    mid_point => [ -123 + $width + 10, $offset + 23 ],
    colour    => '#336699',
    absolutex => 1,
    absolutey => 1,
  });
  return $height;
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
