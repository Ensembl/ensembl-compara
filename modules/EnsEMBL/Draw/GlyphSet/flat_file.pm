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

use Role::Tiny;

use EnsEMBL::Web::File::User;
use EnsEMBL::Web::IOWrapper;
use EnsEMBL::Web::Utils::FormatText qw(add_links);

use EnsEMBL::Draw::Style::Feature::Structured;
use EnsEMBL::Draw::Style::Feature::Transcript;
use EnsEMBL::Draw::Style::Feature::Interaction;
use EnsEMBL::Draw::Style::Graph;
use EnsEMBL::Draw::Style::Graph::Histogram;
use EnsEMBL::Draw::Style::Graph::Barcode;

use parent qw(EnsEMBL::Draw::GlyphSet);

sub init {
  my $self = shift;
  my @roles;
  my $style = $self->my_config('style');

  if ($style eq 'wiggle') {
    push @roles, 'EnsEMBL::Draw::Role::Wiggle';
  }
  else {
    push @roles, 'EnsEMBL::Draw::Role::Alignment';
  }

  ## Don't try to apply non-existent roles, or Role::Tiny will complain
  if (scalar @roles) {
    Role::Tiny->apply_roles_to_object($self, @roles);
  }

  $self->{'features'} = $self->features;
}

sub features {
  my $self         = shift;
  my $container    = $self->{'container'};
  my $hub          = $self->{'config'}->hub;
  my $species_defs = $self->species_defs;
  my $sub_type     = $self->my_config('sub_type');
  my $format       = $self->my_config('format');
  my $data         = [];

  ## Get the file contents
  my %args = (
              'hub'     => $hub,
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
  my $iow   = EnsEMBL::Web::IOWrapper::open($file, 
                                            'hub'         => $hub, 
                                            'config_type' => $self->{'config'}{'type'},
                                            'track'       => $self->{'my_config'}{'id'},
                                            );

  if ($iow) {
    ## Parse the file, filtering on the current slice
    $data = $iow->create_tracks($container);
  } else {
    #return $self->errorTrack(sprintf 'Could not read file %s', $self->my_config('caption'));
    warn "!!! ERROR CREATING PARSER FOR $format FORMAT";
  }

  return $data;
}

sub draw_features {
  my ($self, $subtracks) = @_;
  $subtracks ||= $self->{'features'};

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

  ## Most wiggle plots make more sense if the baseline is zero
  $self->{'my_config'}->set('baseline_zero', 1);

  my %config    = %{$self->track_style_config};

  my $key         = $self->{'hover_label_class'};
  my $hover_label = $self->{'config'}->{'hover_labels'}{$key};
  my $mod_header  = $hover_label->{'header'};

  foreach (@$subtracks) {
    my $features  = $_->{'features'};
    my $metadata  = $_->{'metadata'} || {};

    ## Set alternative colour (used by some styles)
    if ($metadata->{'color'} && !$metadata->{'altColor'}) {
        ## No alt set, so default to a half-tint of the main colour
        my @gradient = EnsEMBL::Draw::Utils::ColourMap::build_linear_gradient(3, ['white', $metadata->{'color'}]);
        $metadata->{'altColor'} = $gradient[1];
      }


    my $name = $metadata->{'name'};
    if ($name && $hover_label->{'header'} !~ /$name/) { ## Don't add the track name more than once!
      if ($mod_header) {
        $hover_label->{'header'} .= ': ';
        $mod_header = 0;
      }
      else {
        $hover_label->{'header'} .= '; '; 
      }
      $hover_label->{'header'} .= $name;
    }

    ## Add description to track name mouseover menu (if not added already)
    my $description   = $metadata->{'description'};
    my $already_seen  = ($hover_label->{'extra_desc'} && $description 
                          && $hover_label->{'extra_desc'} =~ /$description/);
    if ($description && !$already_seen) {
      $description = add_links($description);
      $hover_label->{'extra_desc'} .= '<br>' if $hover_label->{'extra_desc'}; 
      $hover_label->{'extra_desc'} .= $description;
    }
    ## Also put it into config, for subtitles

    $config{'subtitle'} = $description;
  }
  my $drawing_style = $self->{'my_config'}->get('drawing_style') || ['Feature::Structured'];

  foreach (@{$drawing_style||[]}) {
    my $style_class = 'EnsEMBL::Draw::Style::'.$_;
    my $style = $style_class->new(\%config, $subtracks);
    $self->push($style->create_glyphs);
  }
  ## This is clunky, but it's the only way we can make the new code
  ## work in a nice backwards-compatible way right now!
  ## Get label position, which is set in Style::Graph
  $self->{'label_y_offset'} = $self->{'my_config'}->get('label_y_offset');
}

sub render_as_transcript_nolabel {
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Feature::Transcript']);
  $self->draw_features;
}

sub render_as_transcript_label {
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Feature::Transcript']);
  $self->{'my_config'}->set('show_labels', 1);
  $self->draw_features;
}

sub render_interaction {
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Feature::Interaction']);
  $self->{'my_config'}->set('bumped', 0); 
  $self->draw_features;
  ## Limit track height to that of biggest arc
  my $max_height  = $self->{'my_config'}->get('max_height');
  $self->{'maxy'} = $max_height if $max_height;
}

1;
