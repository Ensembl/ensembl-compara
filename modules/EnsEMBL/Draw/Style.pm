=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::Style;

### Base package for drawing a track in a particular style - this replaces 
### much of the rendering code within a glyphset

### EXAMPLE

### use EnsEMBL::Draw::Style::NameOfStyle;

### sub render_normal {
### ...
###   my $config = $self->track_style_config;
###   my $data = [];
### ... # Munge data
###   my $output = EnsEMBL::Draw::Style::NameOfStyle->new($config, $data);
###   $self->push($output->glyphs);
### } 

use strict;
use warnings;

use GD::Simple;

use EnsEMBL::Draw::Utils::LocalCache;

use EnsEMBL::Draw::Glyph::Arc;
use EnsEMBL::Draw::Glyph::Circle;
use EnsEMBL::Draw::Glyph::Composite;
use EnsEMBL::Draw::Glyph::Intron;
use EnsEMBL::Draw::Glyph::Line;
use EnsEMBL::Draw::Glyph::Poly;
use EnsEMBL::Draw::Glyph::Triangle;
use EnsEMBL::Draw::Glyph::Rect;
use EnsEMBL::Draw::Glyph::Space;
use EnsEMBL::Draw::Glyph::Sprite;
use EnsEMBL::Draw::Glyph::Text;

### Wrappers around low-level drawing code
sub Arc        { my $self = shift; return EnsEMBL::Draw::Glyph::Arc->new(@_);     }
sub Circle     { my $self = shift; return EnsEMBL::Draw::Glyph::Circle->new(@_);     }
sub Composite  { my $self = shift; return EnsEMBL::Draw::Glyph::Composite->new(@_);  }
sub Intron     { my $self = shift; return EnsEMBL::Draw::Glyph::Intron->new(@_);     }
sub Line       { my $self = shift; return EnsEMBL::Draw::Glyph::Line->new(@_);       }
sub Poly       { my $self = shift; return EnsEMBL::Draw::Glyph::Poly->new(@_);       }
sub Rect       { my $self = shift; return EnsEMBL::Draw::Glyph::Rect->new(@_);       }
sub Space      { my $self = shift; return EnsEMBL::Draw::Glyph::Space->new(@_);      }
sub Sprite     { my $self = shift; return EnsEMBL::Draw::Glyph::Sprite->new(@_);     }
sub Text       { my $self = shift; return EnsEMBL::Draw::Glyph::Text->new(@_);       }
sub Triangle   { my $self = shift; return EnsEMBL::Draw::Glyph::Triangle->new(@_);   }


sub new {
  my ($class, $config, $data) = @_;

  my $cache = $config->{'image_config'}->hub->cache || new EnsEMBL::Draw::Utils::LocalCache;

  my $self = {
              'data'    => $data,
              'cache'   => $cache,
              'glyphs'  => [],
              %$config
              };

  bless $self, $class;

  my @text_info = $self->get_text_width(0, 'X', '', 
                                         ptsize => $self->{'font_size'}, 
                                         font => $self->{'font_name'});
  $self->{'label_height'} = $text_info[3];

  return $self;
}
  
sub create_glyphs {
### Method to create the glyphs needed by a given style
### Returns an array of Glyph objects
### Stub - must be implemented in child modules
  my $self = shift;
  warn "!!! MANDATORY METHOD ".ref($self).'::create_glyphs HAS NOT BEEN IMPLEMENTED!';
}

#### BASIC ACCESSORS #################

sub glyphs {
### Accessor
### @return ArrayRef of EnsEMBL::Draw::Glyph objects 
  my $self = shift;
  return $self->{'glyphs'};
}

sub data {
### Accessor
### @return ArrayRef containing the feature(s) to be drawn 
  my $self = shift;
  return $self->{'data'};
}

sub image_config {
### Accessor
### @return the ImageConfig object belonging to the track
  my $self = shift;
  return $self->{'image_config'};
}

sub track_config {
### Accessor
### @return the menu Node object which contains the track configuration
  my $self = shift;
  return $self->{'track_config'};
}

sub strand {
### Accessor
### @return The strand on which we are drawing this set of glyphs
  my $self = shift;
  return $self->{'strand'};
}

sub cache {
### Accessor 
### @return object - either EnsEMBL::Web::Cache or EnsEMBL::Draw::Utils::LocalCache 
  my $self = shift;
  return $self->{'cache'};
}

#### COPIED FROM GlyphSet.pm #########

## TODO - move these methods to a utility module (TextHelper?)

sub get_text_width {
  my ($self, $width, $text, $short_text, %parameters) = @_;
     $text = 'X' if length $text == 1 && $parameters{'font'} =~ /Cour/i;               # Adjust the text for courier fonts
  my $key  = "$width--$text--$short_text--$parameters{'font'}--$parameters{'ptsize'}"; # Look in the cache for a previous entry 
  #warn ">>> KEY $key";

  my @res = @{$self->cache->get($key)||[]};
  return @res if scalar(@res);

  my $gd = $self->_get_gd($parameters{'font'}, $parameters{'ptsize'});

  return unless $gd;

  # Use the text object to determine height/width of the given text;
  $width ||= 1e6; # Make initial width very big by default

  my ($w, $h) = $gd->stringBounds($text);

  if ($w < $width) {
    @res = ($text, 'full', $w, $h);
  } elsif ($short_text) {
    ($w, $h) = $gd->stringBounds($text);
    @res = $w < $width ? ($short_text, 'short', $w, $h) : ('', 'none', 0, 0);
  } elsif ($parameters{'ellipsis'}) {
    my $string = $text;

    while ($string) {
      chop $string;

      ($w, $h) = $gd->stringBounds("$string...");

      if ($w < $width) {
        @res = ("$string...", 'truncated', $w, $h);
        last;
      }
    }
  } else {
    @res = ('', 'none', 0, 0);
  }

  $self->cache->set($key, \@res); # Update the cache

  return @res;
}

sub _get_gd {
  ### Returns the GD::Simple object appropriate for the given fontname
  ### and fontsize. GD::Simple objects are cached against fontname and fontsize.

  my $self     = shift;
  my $font     = shift || 'Arial';
  my $ptsize   = shift || 10;
  my $font_key = "${font}--${ptsize}";

  my $gd = $self->cache->get($font_key);

  return $gd if $gd; 

  my $fontpath = $self->image_config->species_defs->ENSEMBL_STYLE->{'GRAPHIC_TTF_PATH'}. "/$font.ttf";
  $gd = GD::Simple->new(400, 400);

  eval {
    if (-e $fontpath) {
      $gd->font($fontpath, $ptsize);
    } elsif ($font eq 'Tiny') {
      $gd->font(gdTinyFont);
    } elsif ($font eq 'MediumBold') {
      $gd->font(gdMediumBoldFont);
    } elsif ($font eq 'Large') {
      $gd->font(gdLargeFont);
    } elsif ($font eq 'Giant') {
      $gd->font(gdGiantFont);
    } else {
      $font = 'Small';
      $gd->font(gdSmallFont);
    }
  };

  warn $@ if $@;

  $self->cache->set($font_key, $gd); # Update font cache

  return $gd; 
}


1;
