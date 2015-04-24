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
###   my $style = EnsEMBL::Draw::Style::NameOfStyle->new($config, $data);
###   $self->push($style->glyphs);
### } 

use strict;
use warnings;

use POSIX qw(ceil);

use EnsEMBL::Draw::Utils::Bump qw(bump);
use EnsEMBL::Draw::Utils::Text;
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

  my @text_info = $self->get_text_info;
  $self->{'label_height'} = $text_info[3];

  $self->{'bump_tally'} = {'_bump' => {
                                    'length' => $self->image_config->container_width,
                                    'rows'   => $self->track_config->get('depth') || 1e3,
                                    'array'  => [],
                                      }
                            }; 

  return $self;
}
  
sub create_glyphs {
### Method to create the glyphs needed by a given style
### Returns an array of Glyph objects
### Stub - must be implemented in child modules
  my $self = shift;
  warn "!!! MANDATORY METHOD ".ref($self).'::create_glyphs HAS NOT BEEN IMPLEMENTED!';
}

sub get_text_info {
### Get text dimensions
  my ($self, $text) = @_;
  $text ||= 'X';
  my @info = EnsEMBL::Draw::Utils::Text::get_text_info($self->cache, $self->image_config, 0, $text, '', font => $self->{'font_name'}, ptsize => $self->{'font_size'});
  ## Pad the text on the right side by 10 pixels so it doesn't 
  ## run into the next one and compromise readability
  return {'width' => $info[2] + 10, 'height' => $info[3]};
}

sub set_bump_row {
  my ($self, $start, $end, $show_label, $text_info) = @_;
  my $row = 0;

  ## Set bumping based on longest of feature and label
  my $text_end  = $show_label ?
                        ceil($start + $text_info->{'width'} / $self->{'pix_per_bp'})
                        : 0;
  $end          = $text_end if $text_end > $end;

  $row = bump($self->bump_tally, $start, $end);
  return $row;
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

sub bump_tally {
### Accessor
### @return a Hashref that keeps track of bumping 
  my $self = shift;
  return $self->{'bump_tally'};
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

1;
