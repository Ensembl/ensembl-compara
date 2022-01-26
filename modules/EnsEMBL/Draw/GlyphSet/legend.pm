=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::legend;

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

# Example
#   $self->init_legend(3); # number of columns
#   $self->add_to_legend($data); # see below for data
#   $self->add_vgroup_to_legend([$data,$data,...],$title,$common_data);
#                                # add vertical group (see below for data)
#   $self->newline; # start new line in legend
#   $self->newline(1); # start new line if not at start of one already
#
# Pass data hash-refs containing the following keys
#
#   legend => "text"     : the legend
#   colour => "a colour" : the colour
#
# optionally:
#
#   style  => 'box'      : regular box type legend (default)
#             'line'     : line type legend (eg joins)
#             'triangle' : (downward-pointing) triangle
#             'text'     : text
#             <yours>      (see below)
#   name => "key"        : if you don't want legend/colour to be used as
#                          the determining key for duplication of rows
#
# icon-specific:
#
#   text => "text"       : text to use (text)
#   stripe => "colour"   : make stripey by alternating this colour with
#                          the main colour (box)
#   border => "colour"   : include a border (box,triangle)
#   overlay => "text"    : text to overlay (box)
#   overlay_colour => "colour" : colour of overlay text (box)
#   direction => 'up'/'down' : pointing (deafult down) (triangle)
#   width/height => num  : non-default width/height (box, triangle)
#   envelop => 1         : envelop effect (surround with membrane),
#                          used on ancestor node in gene trees (box)
#   dashed => 1          : dashed line
#
# (eg [{ legend => "Type A", colour => "green"                    },
#      { legend => "Type B", colour => "red",   style => 'line'   },
#      { legend => "Type Z", colour => "black", envelop => 1      }]) 
#
# If colour is an array reference it will be used to draw a %age scale,
# each scale element will be of the style specified below (or box).
#
# You can add your own styles by defining a method called _icon_mystyle
# in your class and then passing style => 'mystyle'. See _icon_* in this
# class for examples. Add here if generally useful, to your own class if
# specialist.

# $c is only passed as a stop-gap until auto-columning is sorted.
# There will also be auto column widthing coming shortly which will affect
# this API.

use POSIX qw(ceil);
use List::Util qw(max);

# Would be better to caluclate this at the end, but we calculate (x,y)
#   before all the data is in.
my $MAX_WIDTH = 350;

# USEFUL UTILITIES

my %abs = map {; $_ => 1 } qw(absolutex absolutey absolutewidth);
sub _colourmap { $_[0]->{'config'}->hub->colourmap; }

# GENERALLY USEFUL ICONS

sub _icon_text {
  my ($self,$x,$y,$k) = @_;
  
  my %font = %{$self->{'font'}};
  $font{'font'} = 'MediumBold' if $k->{'bold'};

  my $width_text = $k->{'width_text'} || $k->{'text'};
  my @text_props = $self->get_text_width(0,$width_text,'',%font);

  $self->push($self->Text({
    x => $x,
    y => $y,
    width => $text_props[2],
    height => $self->{'text_height'},
    text => $k->{'text'},
    colour => $k->{'colour'},
    halign => 'left',
    valign => 'center',
    %abs, %font
  }));
  return @text_props[2,3];
}

sub _icon_triangle {
  my ($self,$x,$y,$k) = @_;

  my $up = ($k->{'direction'} eq 'up');
  my $height = $k->{'height'}||6;
  $self->push($self->Triangle({
    colour => $k->{'colour'},
    %abs,
    mid_point => [$x+$self->{'box_width'}/2,$y+$height*($up?0.5:1.5)],
    direction => $up?'up':'down',
    width => $k->{'width'}||4,
    height => $height,
    bordercolour => $k->{'border'},
    no_rectangle => 1,
  }));
  return (max($self->{'box_width'},$k->{'width'},4),
          max($self->{'text_height'},$height));
}

sub _icon_box {
  my ($self,$x,$y,$k) = @_;

  my $width  = $k->{'width'} || $self->{'box_width'};
  my $height = $k->{'height'} || ($self->{'text_height'} - 2);

  my $icon = {
    x             => int($x + ($self->{'box_width'}-$width)/2),
    y             => int($y + 2 + ($self->{'text_height'}-2-$height)/2),
    width         => $width,
    height        => $height,
    colour        => $k->{'colour'},
    %abs,
  };

  # Envelopes, borders, stripes, oh my!
  $icon->{'bordercolour'} = $k->{'border'} if $k->{'border'};
  if($k->{'stripe'}) {
    my ($stripe,$pattern) = ($k->{'stripe'},'hatch_thick');
    $pattern = $1 if $stripe =~ s/^(.*?)\|//;
    $icon->{'pattern'} = $pattern;
    $icon->{'patterncolour'} = $stripe;
  }
  if($k->{'envelop'}) { # grow box so it can be inscribed
    $icon->{'x'} -= 1;
    $icon->{'y'} -= 1;
    $icon->{'width'} +=2;
    $icon->{'height'} += 2;
  }

  $self->push($self->Rect($icon));

  # Envelope inscription
  if($k->{'envelop'}) {
    $self->push($self->Rect({
      x => $icon->{'x'} + 1,
      y => $icon->{'y'} + 1,
      width => $icon->{'width'} - 2,
      height => $icon->{'height'} - 2,
      bordercolour => 'white',
      %abs,
    }));
  }

  # Overlay text
  if($k->{'overlay'}) {
    my $text_width = [ $self->get_text_width(0,$b->{'overlay'},'', 
                                             %{$self->{'font'}}   )]->[2];

    $self->push($self->Text({
      x           => $x + $self->{'box_width'}/2 - $text_width,
      y           => $y - 2,
      height      => $self->{'text_height'},
      valign      => 'center',
      halign      => 'left',
      colour      => $k->{'overlay_colour'} ||
                     $self->_colourmap->contrast($self->{'colour'}),
      text        => $k->{'overlay'},
      %abs,
      %{$self->{'font'}}, 
    }));
  }

  return ($self->{'box_width'},$self->{'text_height'});
}

sub _icon_line {
  my ($self,$x,$y,$k) = @_;

  my %data = (
    x             => $x,
    y             => $y + ($self->{'text_height'} / 2),
    width         => $self->{'box_width'}, 
    colour        => $k->{'colour'},
    height        => 0.5,
    %abs,
  );
  if($k->{'height'}) {
    $self->push($self->Rect({ %data, height => $k->{'height'} }));
  } else {
    $self->push($self->Line({ %data, dotted => $k->{'dashed'} }));
  }
  return ($self->{'box_width'},$self->{'text_height'});
}

sub _icon_scale { # %age scale, like on meth tracks
  my ($self,$x,$y,$k) = @_;

  my $gradient_settings = $k->{'gradient'} || {'boxes' => 10, 'labels' => 1};

  my $style = $k->{'style'} || 'box';
  my @cg = $self->_colourmap->build_linear_gradient($gradient_settings->{'boxes'},
                                                    $k->{'colour'});
  for my $i (0..@cg) {
    if($i<@cg) {
      my $method = $self->can("_icon_$style");
      die "Unknown style '$k->{'style'}" unless $method;
      $k->{'colour'} = $cg[$i];
      $self->$method($x+$i*$self->{'box_width'},$y,$k);
    }
    if ($gradient_settings->{'labels'}) {
      $self->push($self->Text({
        x => $x + $i*$self->{'box_width'} -($i?$self->{'text_width'}*2/3:0),
        y => $y + $self->{'text_height'},
        height => $self->{'text_height'},
        valign => 'center',
        halign => 'center',
        colour => 'black',
        text   => ($i*10)." ",
        font   => 'Small',
        %abs,
      }));
    }
  }
  $self->{'max_height'} += $self->{'text_height'};
  return ($self->{'box_width'} * $gradient_settings->{'boxes'}, $self->{'text_height'});
}

# MAIN METHODS

sub _legend { # draw the text label
  my ($self,$x,$y,$h,$k) = @_;

  $self->push($self->Text({
    x             => $x,
    y             => $y + $h/2 - $self->{'text_height'}/2,
    height        => $self->{'text_height'},
    halign        => 'left',
    colour        => 'black',
    valign        => 'top',
    text          => ' '.$k->{'legend'},
    %abs,
    %{$self->{'font'}},
  }));
}

sub _add_here { # common internal method for adding whether alone or group
  my ($self,$xo,$yo,$k) = @_;

  my $legend_gap = $self->{'box_width'} / 4;
  my $style = $k->{'style'} || 'box';
  $style = "scale" if ref($k->{'colour'}) eq 'ARRAY';
  my $method_name = "_icon_$style";
  my $method = $self->can($method_name);
  die "No such method '$method_name" unless $method;
  my ($w,$h) = $self->$method($xo,$yo,$k);
  $self->{'max_height'} = $yo unless $yo < $self->{'max_height'};
  my ($lw,$lh) = $self->_legend($xo+$w+$legend_gap,$yo,$h,$k);
  return ($w+$lw,$h);
}

sub _start { # where should we start drawing this icon?
  my ($self) = @_;

  return ($self->{'col'}*$self->{'xm'},$self->{'y'});
}

sub _reset { # reset position following init
  my ($self) = @_;

  $self->newline if $self->{'h'}; # not first time
  $self->{'y'} ||= 4; # 4px is a nice gap at start
  $self->{'h'} = 0;
  $self->{'col'} = 0;
}

sub newline { # force newline (maybe only $ifnotatstart of line)
  my ($self,$ifnotatstart) = @_;

  return if $ifnotatstart and $self->{'col'} == 0;
  $self->{'y'} += $self->{'h'} + $self->{'text_height'}/2;
  $self->{'h'} = 0;
  $self->{'col'} = 0;
}

sub _advance { # Move pointer on to location for next icon
  my ($self,$w,$h) = @_;

  $self->{'col'}++;
  $self->{'h'} = $h if $h > $self->{'h'};
  $self->newline() if($self->{'col'} == $self->{'columns'});
}

sub add_to_legend { # add single legend member
  my ($self,$k) = @_;

  return unless $self->strand == -1;
  my $name = $k->{'name'} || join(':',$k->{'legend'},$k->{'colour'});
  
  next if $self->{'seen'}{$name};
  $self->{'seen'}{$name} = 1;

  my ($xo,$yo) = $self->_start();
  $yo += 12;
  my ($w,$h) = $self->_add_here($xo,$yo,$k);
  $self->_advance($w,$h);
  return ($w,$h);
}

sub add_vgroup_to_legend { # add vertical group of members
  my ($self,$group,$title,$all) = @_;

  return unless $self->strand == -1;
  # XXX check for seen here, too

  $all ||= {};
  # Add in "alls"
  foreach my $g (@$group) {
    $g->{$_} = $all->{$_} for keys %$all;
  }

  my ($xo,$yo) = $self->_start();
  # title 
  my $title_height = $self->{'text_height'} * 2 + 4;
  my $gap = $self->{'text_height'}/2;
  $self->push($self->Text({
    x             => $xo,
    y             => $yo,
    height        => $title_height,
    valign        => 'top',
    halign        => 'left',
    colour        => 'black',
    text          => $title,
    %abs,
    %{$self->{'font'}},
    ptsize        => $self->{'font'}{'ptsize'} + 0.6,
  }));
  $yo += $title_height+$gap;

  my ($w,$h) = (0,0);
  foreach my $k (@$group) {
    my ($aw,$ah) = $self->_add_here($xo,$yo+$h,$k);
    $w = $aw if $aw > $w;
    $h += $ah + $gap;
  }
  $self->_advance($w,$h+$title_height+2*$gap);
  return ($w,$h+$title_height+2*$gap);
}

sub init_legend { # begin (or reset)
  my ($self,$c) = @_;

  my $config = $self->{'config'};

  return unless $self->strand == -1;

  $self->{'box_width'} = 20;
  my $im_width = $self->image_width;

  $self->{'columns'} =  $c || int($im_width / $MAX_WIDTH) || 1;

  $self->{'font'} = { $self->get_font_details('legend', 1) };

  my @sizes = $self->get_text_width(0,'X','',%{$self->{'font'}});
  $self->{'text_width'}  = $sizes[2];
  $self->{'text_height'} = $sizes[3];
  
  $self->{'max_height'} = 0;

  # n is legend number, going across then down 
  $self->{'seen'} = {};
  $self->_reset();
  $self->{'xm'} = $im_width/$self->{'columns'};
  
  # Set up a separating line
  $self->push($self->Rect({
    x             => 0,
    y             => 0,
    width         => $im_width,
    height        => 0,
    colour        => 'grey50',
    %abs,
  }));
  $self->{'max_height'} += 12;
}

sub add_space {
  my $self = shift;
  my $im_width = $self->image_width;
  my $space = 4;

  $self->push($self->Rect({
    x             => 0,
    y             => $self->{'max_height'} + $self->{'text_height'} + $space,
    width         => $im_width,
    height        => $space,
    colour        => 'white',
  }));
}


1;
        
