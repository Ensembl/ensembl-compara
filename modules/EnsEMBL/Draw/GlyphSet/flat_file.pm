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

package EnsEMBL::Draw::GlyphSet::flat_file;

### Module for drawing features parsed from a non-indexed text file (such as 
### user-uploaded data)

use strict;

use EnsEMBL::Web::File::User;
use EnsEMBL::Web::IOWrapper;
use EnsEMBL::Web::Utils::FormatText qw(add_links);

use EnsEMBL::Draw::Style::Feature::Structured;
use EnsEMBL::Draw::Style::Feature::Transcript;
use EnsEMBL::Draw::Style::Feature::Interaction;

use base qw(EnsEMBL::Draw::GlyphSet::Alignment);

sub features {
  my $self         = shift;
  my $container    = $self->{'container'};
  my $species_defs = $self->species_defs;
  my $sub_type     = $self->my_config('sub_type');
  my $format       = $self->my_config('format');
  my $features     = [];

  ## Get the file contents
  my %args = (
              'hub'     => $self->{'config'}->hub,
              'format'  => $format,
              );

  if ($sub_type eq 'url') {
    $args{'file'} = $self->my_config('url');
    $args{'input_drivers'} = ['URL'];
  }
  else {
    $args{'file'} = $self->my_config('file');
    if ($args{'file'} !~ /\//) { ## TmpFile upload
      $args{'prefix'} = 'user_upload';
    }
  }

  my $file  = EnsEMBL::Web::File::User->new(%args);
  my $iow   = EnsEMBL::Web::IOWrapper::open($file);

  if ($iow) {
    ## Parse the file, filtering on the current slice
    $features = $iow->create_tracks($container);
  } else {
    #return $self->errorTrack(sprintf 'Could not read file %s', $self->my_config('caption'));
    warn "!!! ERROR CREATING PARSER FOR $format FORMAT";
  }

  return $features;
}

sub draw_features {
  my $self = shift;

  ## Defaults
  my $colour_key     = $self->colour_key('default');
  $self->{'my_config'}->set('default_colour', $self->my_colour($colour_key));

  $self->{'my_config'}->set('bumped', 1) unless defined($self->{'my_config'}->get('bumped'));
  $self->{'my_config'}->set('same_strand', $self->strand);
  unless ($self->{'my_config'}->get('height')) {
    $self->{'my_config'}->set('height', 8);
  }

  unless ($self->{'my_config'}->get('depth')) {
    $self->{'my_config'}->set('depth', 10);
  }

  my $subtracks = $self->features;
  my $config    = $self->track_style_config;

  my $key         = $self->{'hover_label_class'};
  my $hover_label = $self->{'config'}->{'hover_labels'}{$key};
  my $mod_header  = $hover_label->{'header'};

  foreach (@$subtracks) {
    my $features  = $_->{'features'};
    my $metadata  = $_->{'metadata'};
    my $name      = $metadata->{'name'};
    if ($name) {
      if ($mod_header) {
        $hover_label->{'header'} .= ': ';
        $mod_header = 0;
      }
      else {
        $hover_label->{'header'} .= '; '; 
      }
      $hover_label->{'header'} .= $name;
    }

    ## Add description to track name mouseover menu
    my $description = $metadata->{'description'};
    if ($description) {
      $description = add_links($description);
      $hover_label->{'extra_desc'} .= '<br>' if $hover_label->{'extra_desc'}; 
      $hover_label->{'extra_desc'} .= $description;
    }

    my $drawing_style = $self->{'my_config'}->get('drawing_style');
    my $style_class   = $drawing_style ? "EnsEMBL::Draw::Style::Feature::$drawing_style" 
                                       : 'EnsEMBL::Draw::Style::Feature::Structured';

    my $style = $style_class->new($config, $features);
    $self->push($style->create_glyphs);
  }
}

sub render_as_transcript_nolabel {
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', 'Transcript');
  $self->draw_features;
}

sub render_as_transcript_label {
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', 'Transcript');
  $self->{'my_config'}->set('show_labels', 1);
  $self->draw_features;
}

sub render_interaction {
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', 'Interaction');
  $self->{'my_config'}->set('bumped', 0); 
  $self->draw_features;
  ## Limit track height to that of biggest arc
  my $max_height  = $self->{'my_config'}->get('max_height');
  $self->{'maxy'} = $max_height if $max_height;
}

sub href {
}



1;
