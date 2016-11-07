=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::Style::Feature;

=pod
Renders a track as a series of simple rectangular blocks

Also a parent module to most styles that render individual features
rather than graphs or other aggregate data.

This module expects data in the following format:

  $data = [
            {
            'metadata' => {},
            'features' => [
                {
                'start'         => 123456,
                'end'           => 123789,
                'colour'        => 'red',                             # mandatory unless bordercolour set
                'bordercolour'  => 'black',                           # optional
                'label'         => 'Feature 1',                       # optional
                'label_colour'  => 'red',                             # optional
                'join_colour'   => 'red',                             # optional
                'href'          => '/Location/View?r=123456-124789',  # optional  
                'title'         => 'Some text goes here',             # optional  
                },
              ],
            }
          ];
=cut

use strict;
use warnings;
no warnings 'uninitialized';

use POSIX qw(ceil);
use List::Util qw(max);

use parent qw(EnsEMBL::Draw::Style);

sub create_glyphs {
### Create all the glyphs required by this style
### @return Array of EnsEMBL::Web::Glyph objects
  my $self = shift;

  my $data            = $self->data;
  my $image_config    = $self->image_config;
  my $track_config    = $self->track_config;
  ## Set some track-wide variables
  my $slice_width     = $image_config->container_width;
  my $bumped          = $track_config->get('bumped');
  my $vspacing        = defined($track_config->get('vspacing')) ? $track_config->get('vspacing') : 4;
  my $label_padding   = 10; ## Prevent labels from running into one another
  ## In case the file contains multiple tracks, start each subtrack below the previous one
  my $y_start         = $track_config->get('y_start') || 0;
  my $subtrack_start  = $y_start;
  my $label_height    = 0;
  my $total_height    = 0;

  ## Strand settings
  foreach my $subtrack (@$data) {
    ## Keep track of all the feature heights so we can calculate a correct total height
    my $heights = {};

    ## Draw title over track
    if ($track_config->get('show_subtitle')) {
      $self->track_config->set('subtitle_y', 0);
      my $subtitle_height = $self->draw_subtitle($subtrack->{'metadata'}, $total_height);
      $subtrack_start .= $subtitle_height + 2;
    }

    my @features = @{$subtrack->{'features'}||[]}; 
    my $label_height;

    ## FIRST LOOP - process features
    foreach my $feature (@features) {
      ## Are we drawing transcripts or just genes?
      #next if $feature->{'type'} && $feature->{'type'} eq 'gene'        && !$track_config->{'hide_transcripts'};
      #next if $feature->{'type'} && $feature->{'type'} eq 'transcript'  && $track_config->{'hide_transcripts'};

      my $show_label  = $track_config->get('show_labels') && $feature->{'label'} ? 1 : 0;
      my $overlay     = $track_config->get('overlay_label');
      my $alongside   = $track_config->get('bumped') eq 'labels_alongside';

      ## Default colours, if none set in feature
      ## Note that a feature must have either a border colour or a fill colour,
      ## but doesn't need to have both. However we do set join and label colours,
      ## because other configuration options determine whether they are used
      if (!$feature->{'bordercolour'}) {
        $feature->{'colour'} ||= $track_config->get('default_colour') || $subtrack->{'metadata'}{'colour'} || 'black';
      }
      $feature->{'join_colour'}   ||= $feature->{'colour'} || $feature->{'bordercolour'};
      $feature->{'label_colour'}  ||= $feature->{'colour'} || $feature->{'bordercolour'};
      $feature->{'_bstart'} = $feature->{'start'};
      $feature->{'_bend'} = $feature->{'end'};
      if ($show_label && !$overlay) {
        my $text_info   = $self->get_text_info($feature->{'label'});
        ## Round up, since we're working in base-pairs - otherwise we may still overlap the next feature
        my $lwidth_bp = ceil(($text_info->{'width'} + $label_padding) / $self->{'pix_per_bp'});
        $feature->{'_bend'} = $alongside ? $feature->{'_bend'} + $lwidth_bp
                                         : max($feature->{'_bend'}, $feature->{'_bstart'} + $lwidth_bp);
        $label_height = max($label_height, $text_info->{'height'});
      }
    }
    EnsEMBL::Draw::GlyphSet::do_bump($self,\@features);

    my $typical_label_height;
    $typical_label_height = $self->get_text_info($features[0]->{'label'}) if @features;
    ## SECOND LOOP - draw features
    foreach my $feature (@features) {
      my $new_y;
      my $feature_row = 0;
      my $label_row   = 0;
      ## Work out if we're bumping the whole feature or just the label
      if ($bumped) {
        my $bump = $feature->{'_bump'};
        $label_row   = $bump unless $bumped eq 'features_only';
        $feature_row = $bump unless $bumped eq 'labels_only';       
      }
      next if $feature_row < 0; ## Bumping code returns -1 if there's a problem 

      ## Work out where to place the feature
      my $feature_height  = $track_config->get('height') || $typical_label_height->{'height'};
      my $feature_width   = $feature->{'end'} - $feature->{'start'} + 1;

      if ($feature_width == 0) {
        ## Fix for single base-pair features
        $feature_width = 1;
      }
      else {
        ## Truncate to viewport - but don't alter feature hash because we may need it
        my ($drawn_start, $drawn_end) = $feature->{'end'} - $feature->{'start'}
                                        ? ($feature->{'start'}, $feature->{'end'})
                                        : ($feature->{'end'}, $feature->{'start'});
        $drawn_start        = 0 if $drawn_start < 0;
        $drawn_end          = $slice_width if $drawn_end > $slice_width;
        $feature_width      = $drawn_end - $drawn_start + 1; 
      }

      my $labels_height   = $label_row * $label_height;
      ## Only "ordinary" bumping requires adding the label to the feature height
      my $add_labels      = ($bumped && $bumped eq '1') ? $labels_height : 0;
      my $y               = $subtrack_start + ($feature_row * ($feature_height + $vspacing)) + $add_labels;

      my $position  = {
                      'y'           => $y,
                      'width'       => $feature_width,
                      'height'      => $feature_height,
                      'image_width' => $slice_width,
                      };
      
      ## Get the real height of the feature e.g. if it includes any tags or extra glyphs
      $self->draw_feature($feature, $position);
      my $extra = $self->track_config->get('extra_height') || 0;
      my $approx_height = $feature_height + $extra;
      push @{$heights->{$feature_row}}, ($approx_height + $vspacing + $add_labels);
    
      ## Optional label(s)
      my $font_size     = $self->{'font_size'};

      ## Regular labels (outside feature)
      if ($track_config->get('show_labels') && !$track_config->get('overlay_label') && $feature->{'label'}) {
        my $text_info   = $self->get_text_info($feature->{'label'});
        my $text_width    = $text_info->{'width'};
        my $text_height   = $text_info->{'height'};
        my ($new_x, $new_y);

        if ($bumped eq 'labels_alongside') {
          $new_x      = $feature->{'end'} + (4 / $self->{'pix_per_bp'});
          $new_y      = $position->{'y'} + $approx_height - $text_height;
          ## Reduce text size slightly so it doesn't take up too much space
          $font_size *= 0.9;
        }
        else {
          $new_x = $feature->{'start'} - 1;
          $new_x = 0 if $new_x < 0;
          $new_y = $position->{'y'} + $approx_height;
          $new_y += $labels_height if ($bumped eq 'labels_only');
          ## Pad width to match bumped position
          $text_width += 10;
        }

        $position = {
                      'x'           => $new_x,
                      'y'           => $new_y,
                      'height'      => $text_info->{'height'},
                      'width'       => $position->{'width'},
                      'text_width'  => $text_width, 
                      'image_width' => $slice_width,
                      'font_size'   => $font_size,
                    };
        $self->add_label($feature, $position);
      }

      ## Overlaid labels (on top of feature)
      ## Note that we can have these as well as regular labels, e.g. on variation tracks
      my $overlay_standard =
        ($track_config->get('overlay_label') && $feature->{'label'});
      my $overlay_separate =
        ($track_config->get('show_overlay') && $feature->{'text_overlay'});
      if($self->{'pix_per_bp'} > 4 && ($overlay_standard || $overlay_separate)) {
        my $label_text;
        my $bp_textwidth;

        my $text_info   = $self->get_text_info($feature->{'label'});
        my $text_width    = $text_info->{'width'};
        my $text_height   = $text_info->{'height'};
        ## If overlay text is different from main label, adjust accordingly
        if ($track_config->get('show_overlay') && $feature->{'text_overlay'}) {
          $label_text = $feature->{'text_overlay'};
          my $overlay_info  = $self->get_text_info($label_text);
          $bp_textwidth     = $overlay_info->{'width'};
        }
        else {  
          $label_text = $feature->{'label'};
          $bp_textwidth = $feature_width / $self->{'pix_per_bp'};
        }

        ## Reduce text size slightly for wider single-letter labels (A, M, V, W)
        my $tmp_textwidth = $bp_textwidth;
        if ($bp_textwidth >= $feature_width && length $label_text == 1) {
          $font_size       *= 0.9;
          my $tmp_text_info = $self->get_text_info($label_text);
          $text_width       = $tmp_text_info->{'width'};
          $text_height      = $tmp_text_info->{'height'};
          $tmp_textwidth    = $text_width / $self->{'pix_per_bp'};
        }

        if ($feature_width > $tmp_textwidth) { ## OK, so there's space for the overlay
          my $new_x = $feature->{'start'} - 1;
          $new_x = 0 if $new_x < 0;
          my $new_y = $position->{'y'} + $approx_height - $text_height;
          $position = {
                      'x'           => $new_x + (($feature_width - ($tmp_textwidth)) / 2),
                      'y'           => $new_y,
                      'height'      => $text_info->{'height'},
                      'width'       => $feature_width,
                      'text_width'  => $text_width, 
                      'image_width' => $slice_width,
                      'font_size'   => $font_size,
                    };
          $self->add_label($feature, $position, 'overlay');
        }
      }
    }

    ## Set the height of the track, in case we want anything in the lefthand margin
    my $subtrack_height = 0;
    while (my($row, $values) = each(%$heights)) {
      my $max = max(@$values);
      $subtrack_height += $max;
    }
    $subtrack_start += $subtrack_height;
    $total_height   += $subtrack_height;
    $track_config->set('real_feature_height', $subtrack_height);
    $self->add_messages($subtrack->{'metadata'}, $subtrack_height);
  }

  $self->draw_hidden_bgd($total_height);
  my $track_height = $track_config->get('total_height') || 0;
  $track_config->set('total_height', $track_height + $total_height);

  $track_config->set('y_start', $y_start + $total_height);
  return @{$self->glyphs||[]};
}

sub draw_feature {
### Create a glyph that's a simple filled rectangle
### @param feature Hashref - data for a single feature
### @param position Hashref - information about the feature's size and position
  my ($self, $feature, $position) = @_;

  return unless ($feature->{'colour'} || $feature->{'bordercolour'});

  ## Set parameters
  my $x = $feature->{'start'};
  $x    = 1 if $x < 1;
  my $params = {
                  x            => $x-1,
                  y            => $position->{'y'},
                  width        => $position->{'width'},
                  height       => $position->{'height'},
                  href         => $feature->{'href'},
                  title        => $feature->{'title'},
                  absolutey    => 1,
                };
  $params->{'colour'}       = $feature->{'colour'} if $feature->{'colour'};
  $params->{'bordercolour'} = $feature->{'bordercolour'} if $feature->{'bordercolour'};

  ## Are we highlighting this feature? Default is no!
  my $highlight = $self->highlight($feature, $params);

  if ($highlight) {
    push @{$self->glyphs}, $highlight;
  }
  push @{$self->glyphs}, $self->Rect($params);
}

sub highlight {
  my ($self, $feature, $params) = @_;
  return unless $feature->{'highlight'};

  my $colour = $feature->{'highlight_colour'} || 'black';

  return $self->Rect({
      x      => $params->{'x'} - 2 / $self->{'pix_per_bp'},
      y      => $params->{'y'} - 2,
      width  => $params->{'width'}  + 4 / $self->{'pix_per_bp'},
      height => $params->{'height'} + 4,
      colour => $colour,
      z      => -10,
  });

}

sub add_label {
### Create a text label
### @param feature Hashref - data for a single feature
### @param position Hashref - information about the label's size and position
  my ($self, $feature, $position, $type) = @_;

  ## Only show labels if they're shorter than the visible portion of the feature
  my $start = $feature->{'start'};  
  if ($start < 0) {
    my $feature_visible = $feature->{'end'} * $self->{'pix_per_bp'};
    return unless $feature_visible > $position->{'width'};
  }

  my ($text, $colour, $halign);
  if ($type && $type eq 'overlay') {
    $text   = $feature->{'text_overlay'} || $feature->{'label'};
    $colour = $self->make_contrasting($feature->{'colour'});
    $halign = 'left'; 
  }
  else {
    $text   = $feature->{'label'};
    $colour = $feature->{'label_colour'} || $feature->{'colour'};
    if ($colour) {
      $colour = $self->make_readable($colour);
    }
    else {
      $colour = 'black';
    }
    $halign = $self->track_config->get('centre_labels') ? 'center' : 'left';
  }

  my $label = {
                x         => $position->{'x'},
                y         => $position->{'y'},
                height    => $position->{'height'},
                width     => $position->{'width'},
                textwidth => $position->{'text_width'},
                text      => $text,
                colour    => $colour,
                font      => $self->{'font_name'},
                ptsize    => $position->{'font_size'} || $self->{'font_size'},
                halign    => $halign,
                valign    => 'center',
                href      => $feature->{'href'},
                title     => $feature->{'title'},
                absolutey => 1,
              };

  push @{$self->glyphs}, $self->Text($label);
}


1;
