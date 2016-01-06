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

package EnsEMBL::Draw::GlyphSet::UserData;

### Parent for glyphsets that display a user's custom tracks

use strict;

use Role::Tiny;

use EnsEMBL::Web::Utils::FormatText qw(add_links);

use parent qw(EnsEMBL::Draw::GlyphSet);

sub can_json { return 1; }

sub init {
  my $self = shift;
  my @roles;
  my $style = $self->my_config('style') || $self->my_config('display') || '';

  if ($style eq 'wiggle' || $style =~ /tiling/) {
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
  warn ">>> IMPORTANT - THIS METHOD MUST BE IMPLEMENTED IN CHILD MODULES!";
=pod

Because user files can contain multiple datasets, this method should return data 
in the following format:

$data = [
         { #Track1
          'metadata' => {},
          'features' => {
                           '1'  => [{}],
                          '-1'  => [{}],
                        },
          },
          { #Track2
           ... etc...
          },
        ];

The keys of the feature hashref refer to the strand on which we wish to draw the data
(as distinct from the strand on which the feature is actually found, which may be different)
- this should be determined in the file parser, based on settings passed to it

=cut
}

sub draw_features {
  my ($self, $subtracks) = @_;
  $subtracks ||= $self->{'features'};
  return unless $subtracks && ref $subtracks eq 'ARRAY';
  my $feature_count = 0;

  foreach (@$subtracks) {
    next unless $_->{'features'} && ref $_->{'features'} eq 'HASH';
    $feature_count += scalar(@{$_->{'features'}{$self->strand}||[]});
  }

  unless ($feature_count > 0) {
    ## Text for error message
    return 'data';
  }

  ## Defaults
  $self->{'my_config'}->set('this_strand', $self->strand);
  $self->{'my_config'}->set('slice_length', $self->{'container'}->length);
  $self->{'my_config'}->set('bumped', 1) unless defined($self->{'my_config'}->get('bumped'));
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
  my $skipped     = 1;

  foreach (@$subtracks) {
    my $features  = $_->{'features'}{$self->strand};
    my $metadata  = $_->{'metadata'} || {};
    next unless scalar @{$features||[]};
    $skipped = 0;

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

  ## Return nothing if we decided not to draw any subtracks
  return if $skipped;

  $config{'bg_href'} = $self->_bg_href;

  my $drawing_style = $self->{'my_config'}->get('drawing_style') || ['Feature::Structured'];

  foreach (@{$drawing_style||[]}) {
    my $style_class = 'EnsEMBL::Draw::Style::'.$_;
    if ($self->dynamic_use($style_class)) {
      my $style = $style_class->new(\%config, $subtracks);
      $self->push($style->create_glyphs);
    }
  }
  ## This is clunky, but it's the only way we can make the new code
  ## work in a nice backwards-compatible way right now!
  ## Get label position, which is set in Style::Graph
  $self->{'label_y_offset'} = $self->{'my_config'}->get('label_y_offset');

  ## Everything went OK, so no error to return
  return 0;
}

sub draw_aggregate {
  my ($self, $subtracks) = @_;
  $subtracks ||= $self->{'features'};
  return unless $subtracks && ref $subtracks eq 'ARRAY';

  my %config = %{$self->track_style_config};

  $config{'bg_href'} = $self->_bg_href;

  my $drawing_style = $self->{'my_config'}->get('drawing_style') || ['Feature::Structured'];

  foreach (@{$drawing_style||[]}) {
    my $style_class = 'EnsEMBL::Draw::Style::'.$_;
    if ($self->dynamic_use($style_class)) {
      my $style = $style_class->new(\%config, $subtracks);
      $self->push($style->create_glyphs);
    }
  }
  ## This is clunky, but it's the only way we can make the new code
  ## work in a nice backwards-compatible way right now!
  ## Get label position, which is set in Style::Graph
  $self->{'label_y_offset'} = $self->{'my_config'}->get('label_y_offset');

  ## Everything went OK, so no error to return
  return 0;
}

sub _bg_href {
  my $self = shift;

  ## Background link - needed for zmenus
  ## Needs to be first to capture clicks
  ## Useful to keep zmenus working on blank regions
  ## only useful in nobump or strandbump modes
  my $link    = $self->_url({ action => 'UserData' }); 
  my $bg_href = { 0 => $link };
  my $height  = $self->{'my_config'}->get('height');

  if ($self->{'my_config'}->get('strandbump')) {
    $bg_href->{0}        = $link;
    $bg_href->{$height}  = $link;
  }
  return $bg_href;
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
