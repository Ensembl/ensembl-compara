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
###   my $data = [];
### ... # Munge data
###   my $output = EnsEMBL::Draw::Style::NameOfStyle->new($config, $data);
###   $self->push($output->glyphs);
### } 

use strict;
use warnings;

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

  my $self = {
              'data' => $data,
              %$config
              };

  bless $self, $class;

  return $self;
}
  
sub glyphs {
### Method to create the glyphs needed by a given style
### Returns an array of Glyph objects
### Stub - must be implemented in child modules
  my $self = shift;
  warn "!!! MANDATORY METHOD ".ref($self).'::glyphs HAS NOT BEEN IMPLEMENTED!';
}

#### BASIC ACCESSORS #################

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
### Accessor (setter/getter)
### @param key String - a key to a cached value
### @param value (optional) - a value to be set in the cache
### @return an arbitrary value from the web cache (if we have caching turned on)
  my ($self, $key, $value) = @_;
  return unless $key;
  $self->{'image_config'}{'_cache'}{$key} = $value if $value;
  return $self->{'image_config'}{'_cache'}{$key};
}

#### MANIPULATE RAW COORDINATES INTO DRAWING COORDINATES ####

sub map_to_image {
### Map absolute coordinates onto image coordinates
### @param coords Array - start and/or end coordinates of a feature
### @return Array - the mapped coordinates
  my ($self, @coords) = @_;
  my @mapped;

  foreach (@coords) {
    ## Map coordinates relative to slice

    ## Scale coordinates to image
    $_ *= $self->{'pix_per_bp'};

    push @mapped, $_;
  }

  return @mapped;
}
