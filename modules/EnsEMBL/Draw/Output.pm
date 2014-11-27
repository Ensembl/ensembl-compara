=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::Output;

### Base package for drawing a discreet section of a genomic image,
### such as a section of assembly, feature track, scalebar or track legend
### Uses GD and the EnsEMBL::Draw::Glyph codebase to render data that's 
### been passed in from a controller

use strict;

use GD;
use GD::Simple;
use URI::Escape qw(uri_escape);
use POSIX qw(floor ceil);
use List::Util qw(min max);

use EnsEMBL::Draw::Glyph;
use EnsEMBL::Draw::Glyph::Circle;
use EnsEMBL::Draw::Glyph::Composite;
use EnsEMBL::Draw::Glyph::Poly;
use EnsEMBL::Draw::Glyph::Triangle;

use parent qw(EnsEMBL::Root);

sub new {
  my ($class, $config, $data) = @_;

  my $self = {
              'data' => $data,
              %$config
              };

  bless $self, $class;
  return $self;
}

sub render {
### Stub
### Render data into a track
  my $self = shift;
  warn "!!! RENDERING NOT IMPLEMENTED IN ".ref($self);
};

sub convert_to_local {
### Convert genomic/feature coordinates to ones relative to this image
  my ($self, $start, $end) = @_;
  my $absolute_start = $self->{'container'}->start;
  $start = $start - $absolute_start;
  $end   = $end - $absolute_start;
  return ($start, $end);
}


######## MISCELLANEOUS ACCESSORS #################

sub cache {
  my $self = shift;
  return $self->{'config'}->hub->cache;
}

sub image_config {
  my $self = shift;
  return $self->{'config'};
}

sub track_config {
  my $self = shift;
  return $self->{'my_config'};
}

sub default_height { return 8; }

sub track_width {
  my $self = shift;
  return $self->{'container'}{'track_width'};
}

### Wrappers around low-level drawing code

sub create_Glyph { 
  my $self = shift; 
  return EnsEMBL::Draw::Glyph->new(@_);     
}

sub create_Circle { 
  my $self = shift; 
  return EnsEMBL::Draw::Glyph::Circle->new(@_);     
}

sub create_Composite { 
  my $self = shift; 
  return EnsEMBL::Draw::Glyph::Composite->new(@_);     
}

sub create_Poly { 
  my $self = shift; 
  return EnsEMBL::Draw::Glyph::Poly->new(@_);     
}

sub create_Triangle { 
  my $self = shift; 
  return EnsEMBL::Draw::Glyph::Triangle->new(@_);     
}

sub get_gd {
  ### Returns the GD::Simple object appropriate for the given fontname
  ### and fontsize. GD::Simple objects are cached against fontname and fontsize.

  my $self     = shift;
  my $font     = shift || 'Arial';
  my $ptsize   = shift || 10;
  my $font_key = "${font}--${ptsize}";

  return $self->cache->get($font_key) if $self->cache->get($font_key);

  my $fontpath = $self->{'config'}->species_defs->ENSEMBL_STYLE->{'GRAPHIC_TTF_PATH'}. "/$font.ttf";
  my $gd       = GD::Simple->new(400, 400);

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

  return $self->cache->get($font_key) = $gd; # Update font cache
}


1;

