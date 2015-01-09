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

package EnsEMBL::Draw::GlyphSet::controller;

### A "dummy" glyphset that gathers data from an EnsEMBL::Web::Draw::Data 
### object and passes it to the appropriate EnsEMBL::Web::Draw::Output module,
### thus turning the drawing code into something resembling MVC

### Note that we do _not_ subclass EnsEMBL::Draw::GlyphSet, because we want
### to strip out all the cruft and retain only essential functionality

### All of this functionality could/should eventually be moved into
### DrawableContainer, which is the real controller

use strict;
use warnings;

use parent qw(EnsEMBL::Root);

sub new {
### Constructor 
### Note that we have to use legacy argument names here, but inside
### the module, clearer names are used
### @param class String - class name
### @param args HashRef
###                     - container API Object on which this image is based (probably a slice)
###                     - config EnsEMBL::Web::ImageConfig
###                     - my_config EnsEMBL::Web::Tree::Node - track configuration
###                     - strand Integer - the strand we're currently drawing
###                     - extras
###                     - highlights
###                     - display String - the renderer for this track
###                     - legend
### @return EnsEMBL::Draw::GlyphSet::controller
  my ($class, $args) = @_;
  
  my $self = {
                container     => $args->{'container'},
                image_config  => $args->{'config'},
                track_config  => $args->{'my_config'},
                strand        => $args->{'strand'},
                extras        => $args->{'extra'}   || {},
                highlights    => $args->{'highlights'},
                display       => $args->{'display'} || 'off',
                legend        => $args->{'legend'}  || {},
             };

  bless $self, $class;

  ### This is where we implement the MVC structure!
  my $data;
  my $output_name = $self->track_config->get('style');
  my $data_type   = $self->track_config->get('data_type');

  ## Fetch the data (if any - some tracks are static
  if ($data_type) {
    my $data_class = 'EnsEMBL::Draw::Data::'.$data_type;

    if ($self->dynamic_use($data_class)) {
      my $object  = $data_class->new($args);
      $data       = $object->get_data;
      if ($data) {
        $self->{'data'} = $data;
        ## Map the renderer name to a real module
        $output_name = $object->select_output($output_name);
      }
    }
  }

  ## Create the output object
  my $output_class = 'EnsEMBL::Draw::Output::'.$output_name;
  warn ">>> RENDERING CLASS $output_class";
  if ($self->dynamic_use($output_class)) {
    my $output = $output_class->new($args, $data);
    warn ">>> OUTPUT $output";
    if ($output) {
      $self->{'output'} = $output;
      $output->init_label;
    }
    else {
      warn "!!! COULDN'T INSTANTIATE OUTPUT MODULE $output_class";
    }
  }
  return $self;
}

sub render {
  my $self = CORE::shift;
  $self->{'glyphs'} = $self->output->render;

  return undef;
}

sub output {
  my $self = CORE::shift;
  return $self->{'output'}; 
}

sub image_config {
  my $self = CORE::shift;
  return $self->{'image_config'}; 
}

sub track_config {
  my $self = CORE::shift;
  return $self->{'track_config'}; 
}

sub _colour_background { return 1; }

sub Text {
  my $self = CORE::shift; 
  return EnsEmBL::Draw::Glyph->new(@_);  
}

sub Line {
  my $self = CORE::shift; 
  return EnsEmBL::Draw::Glyph->new(@_);  
}

##############################################################################################

### Remaining methods are all wrappers around EnsEMBL::Draw::Output, which 
### replaces the drawing functions of EnsEMBL::Draw::GlyphSet

### All the methods below are required to replicate current GlyphSet behaviour, 
### and should probably be revisited and refactored if/when we move this 
### functionality into DrawableContainer

sub push {
  my $self = shift;
  $self->output->add_glyphs(@_);
}

sub miny {
  my ($self, $miny) = @_;
  $self->output->miny($miny) if(defined $miny);
  return $self->output->miny;
}

sub maxy {
  my ($self, $maxy) = @_;
  $self->output->maxy($maxy) if(defined $maxy);
  return $self->output->maxy;
};

sub transform {
  my $self = CORE::shift;
  my $T = $self->{'image_config'}->{'transform'};
  foreach( @{$self->output->{'glyphs'}} ) {
    $_->transform($T);
  }
}

sub section {
## ??
  my $self = shift;
  return $self->track_config->get('section') || '';
}

sub section_height {
## ??
  my $self = shift;
  return $self->{'section_text'} ? 24 : 0;
}

sub section_zmenu { 
## ??
  my $self = shift;
  return $self->track_config->get('section_zmenu'); 
}

sub section_no_text { 
## ??
  my $self = shift;
  $self->track_config->get('no_section_text'); 
}

sub section_text {
## ??
  my ($self, $text) = @_;
  $self->{'section_text'} = $text if $text;
  return $self->{'section_text'};
}

sub label {
  my ($self, $text) = @_;
  warn '>>>> FETCHED OUTPUT '.$self->output;
  $self->output->{'label'} = $text if(defined $text);
  return $self->output->{'label'};
}

sub label_img {
  my ($self, $text) = @_;
  $self->output->{'label_img'} = $text if(defined $text);
  return $self->output->{'label_img'};
}

sub label_text {
  my $self = CORE::shift;
  return $self->label_text;
}

sub max_label_rows { 
  my $self = CORE::shift;
  return $self->output->max_label_rows;
}

sub recast_label {
  my $self = CORE::shift;
  $self->output->recast_label(@_);
}

1;
