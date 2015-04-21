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

package EnsEMBL::Draw::GlyphSet_wiggle;

# Draws "wiggles". Not actually a GlyphSet, but used by them.

use strict;

use List::Util qw(min max);

sub _min_defined(@) { min(grep { defined $_ } @_); }

use base qw(EnsEMBL::Draw::GlyphSet);

sub add_legend_box {
  my ($self,$click_text,$content,$y) = @_;

  my %font_details = $self->get_font_details('innertext', 1);
  my @text = $self->get_text_width(0,$click_text, '', %font_details);
  my ($width,$height) = @text[2,3];
  # add colour key legend
  $self->push($self->Rect({
    width         => $width + 15,
    absolutewidth => $width + 15,
    height        => $height + 2,
    y             => $y,
    x             => -119,
    absolutey     => 1,
    absolutex     => 1,
    title         => join('; ',@$content),
    class         => 'coloured',
    bordercolour  => '#336699',
    colour        => 'white',
  }), $self->Text({
    text      => $click_text,
    height    => $height,
    halign    => 'left',
    valign    => 'bottom',
    colour    => '#336699',
    y         => $y,
    x         => -118,
    absolutey => 1,
    absolutex => 1,
    %font_details,
  }), $self->Triangle({
    width     => 6,
    height    => 5,
    direction => 'down',
    mid_point => [ -123 + $width + 10, $y + 10 ],
    colour    => '#336699',
    absolutex => 1,
    absolutey => 1,
  }));
  return $height+4;
}

sub do_draw_wiggle {
  ### Wiggle plot
  ### Args: array_ref of features in score order, colour, min score for features, max_score for features, display label
  ### Description: draws wiggle plot using the score of the features
  ### Returns 1

  my ($self, $features, $parameters, $colours, $labels) = @_;
  my $slice         = $self->{'container'};
  my $row_height    = $self->my_config('height') || 60;
  my $max_score     = $parameters->{'max_score'};
  my $min_score     = $parameters->{'min_score'};
  my $axis_style    = $parameters->{'graph_type'} eq 'line' ? 0 : 1;
  my %font          = $self->get_font_details('innertext', 1);
  my $name          = $self->my_config('short_name') || $self->my_config('name');
  my $colour        = $parameters->{'score_colour'}  || $self->my_colour('score') || 'blue';
  my $axis_colour   = $parameters->{'axis_colour'}   || $self->my_colour('axis')  || 'red';
  my $label         = $parameters->{'description'}   || $self->my_colour('score', 'text');
     $label         =~ s/\[\[name\]\]/$name/;
  my $textheight    = [ $self->get_text_width(0, $label, '', %font) ]->[3];
  my $pix_per_score = 8; # If all else fails, ie no data and no label
  if($max_score == $min_score) {
    $pix_per_score = $self->label->height if $self->label;
  } else {
    $pix_per_score = $row_height / ($max_score-$min_score);
  }
  my $top_offset    = 0;
  my $offset        = ($parameters->{'initial_offset'} || 0);
  my $initial_offset= $offset;
  my $bottom_offset = $max_score == $min_score ? 0 : (($max_score - ($min_score > 0 ? $min_score : 0)) || 1) * $pix_per_score;
  my $zero_offset   = $max_score * $pix_per_score;

  # Draw the labels
  ## Only done if we have multiple data sets
  if ($labels) {
    my $header_label = shift @$labels;
    my $y            = $offset;
    my $y_offset     = 0;
    my %font_details = $self->get_font_details('innertext', 1);
    my @res_analysis = $self->get_text_width(0,'Legend & More', '', %font_details);
    my $max          = scalar @$labels - 1;
    my ($legend_alt_text, %seen);

    if ($header_label eq 'CTCF') {
      $y     += 15;
      $colour = shift @$colours;
    } else {
      $self->push($self->Text({
        text      => $header_label,
        height    => $res_analysis[3],
        width     => $res_analysis[2],
        halign    => 'left',
        valign    => 'bottom',
        colour    => 'black',
        y         => $y,
        x         => -118,
        absolutey => 1,
        absolutex => 1,
        %font_details,
      }));
    }

    for (my $i = 0; $i <= $max; $i++) {
      my $name   = $labels->[$i];
      my $colour = $colours->[$i];

      if (!exists $seen{$name}) {
        $legend_alt_text .= "$name:$colour,";
        $seen{$name}      = 1;
      }
    }

    $legend_alt_text =~ s/,$//;
    $y              += 13;

    my $zmenu_title = join(', ',$header_label,
                           @{$parameters->{'zmenu_extra_title'}||[]});
    my $zmenu_content = [$zmenu_title,"[ $legend_alt_text ]",
                             @{$parameters->{'zmenu_extra_content'}||[]}];
    my $zmenu_click = $parameters->{'zmenu_click_text'} || 'Legend';
    $self->add_legend_box($zmenu_click,$zmenu_content,$y);

    $y_offset   += 12;
    $top_offset += 15;
    $offset += $y_offset;
  }

  # Draw max and min score
  if ($parameters->{'axis_label'} ne 'off') {
    my $height        = [ $self->get_text_width(0, 1, '', %font) ]->[3];
    my $label_height  = 0;
    $label_height = $self->label->height if($self->label);
    $bottom_offset = max($bottom_offset, $top_offset + $label_height + $height);
    $pix_per_score = $bottom_offset / (($max_score - ($min_score < 0 ? $min_score : 0)) || 1);
    $zero_offset   = $max_score * $pix_per_score;

    foreach ([ $max_score, $top_offset ], [ $min_score, $top_offset+$zero_offset ]) {
      my $text  = sprintf '%.2f', $_->[0];
      my $width = [ $self->get_text_width(0, $text, '', %font) ]->[2];

      $self->push($self->Text({
        text          => $text,
        height        => $height,
        width         => $width,
        textwidth     => $width,
        halign        => 'right',
        colour        => $axis_colour,
        y             => $_->[1] + $initial_offset - $height / 2,
        x             => -10 - $width,
        absolutey     => 1,
        absolutex     => 1,
        absolutewidth => 1,
        %font,
      }), $self->Rect({
        height        => 0,
        width         => 5,
        colour        => $axis_colour,
        y             => $_->[1] + $initial_offset,
        x             => -8,
        absolutey     => 1,
        absolutex     => 1,
        absolutewidth => 1,
      }));
    }

    $self->{'label_y_offset'} = $top_offset+($zero_offset/2)-$label_height/2;
  }

  # Draw the axis
  if (!$parameters->{'no_axis'}) {
    $self->push($self->Line({ # horizontal line
      x         => 0,
      y         => $top_offset + $zero_offset + $initial_offset,
      width     => $slice->length,
      height    => 0,
      absolutey => 1,
      colour    => $axis_colour,
      dotted    => $axis_style,
    }), $self->Line({ # vertical line
      x         => 0,
      y         => $top_offset + $initial_offset,
      width     => 0,
      height    => $row_height,
      absolutey => 1,
      absolutex => 1,
      colour    => $axis_colour,
      dotted    => $axis_style,
    }));
  }

  # Draw wiggly plot
  ## Check to see if we have multiple data sets to draw on one axis
  if (ref $features->[0] eq 'ARRAY') {
    foreach my $feature_set (@$features) {
      $colour = shift @$colours;

      if ($parameters->{'graph_type'} eq 'line') {
        $self->draw_wiggle_points_as_line($feature_set, $slice, $parameters, $initial_offset + $top_offset, $pix_per_score, $colour, $zero_offset);
      } else {
        $self->draw_wiggle_points($feature_set, $slice, $parameters, $top_offset, $pix_per_score, $colour, $zero_offset);
      }
    }
  } else {
    $self->draw_wiggle_points($features, $slice, $parameters, $top_offset, $pix_per_score, $colour, $zero_offset);
  }

  # Add line of text
  $self->push($self->Text({
    text      => $label,
    width     => [ $self->get_text_width(0, $label, '', %font) ]->[2],
    halign    => 'left',
    colour    => $colour,
    y         => $bottom_offset,
    height    => $textheight,
    x         => 1,
    absolutey => 1,
    absolutex => 1,
    %font,
  }));

  $offset += $row_height + $textheight;

  return $offset - $initial_offset;
}

# eg. Sarcophilus harrisii as of e80
sub _is_old_style_rnaseq {
  my ($self,$f) = @_;

  return (ref $f ne 'HASH' and $f->can('display_id') and
    $f->can('analysis') and $f->analysis and
    $f->analysis->logic_name =~ /_intron/);
}

sub _old_rnaseq_is_non_canonical {
  my ($self,$f) = @_;

  my $can_type = [ split /:/, $f->display_id ]->[-1];
  return ($can_type and length $can_type > 3 and
    substr('non canonical', 0, length $can_type) eq $can_type);
}

sub _use_this_feature_colour {
  my ($self,$f,$parameters) = @_;

  if ($parameters->{'use_feature_colours'} and $f->can('external_data')) {
    my $data        = $f->external_data;
    if($data and $data->{'item_colour'} and
       ref($data->{'item_colour'}) eq 'ARRAY') {
      return $data->{'item_colour'}[0];
    }
  }
  return undef;
}

## Does feature need special colour handling?
sub _special_colour {
  my ($self,$f,$parameters) = @_;

  if($self->_is_old_style_rnaseq($f) and
     $self->_old_rnaseq_is_non_canonical($f)) {
    return $parameters->{'non_can_score_colour'};
  }

  my $feature_colour = $self->_use_this_feature_colour($f,$parameters);
  return $feature_colour if defined $feature_colour;

  # No special colour
  return undef;
}

## Given a feature, extract coords, value, and colour for this point
sub _feature_values {
  my ($self,$f,$slice_length) = @_;

  my @out;
  my ($start,$end,$score);
  if (ref $f eq 'HASH') {
    # A simple HASH value
    ($start,$end,$score) = ($f->{'start'},$f->{'end'},$f->{'score'});
  } else {
    # A proper feature
    ($start,$end,$score) = ($f->start,$f->end,0);
    if($f->can('score')) {
      $score = $f->score || 0;
    } elsif($f->can('scores')) {
      $score = $f->scores->[0] || 0;
    }
  }
  $start = max($start,1);
  $end = min($end,$slice_length);
  return ($start,$end,$score);
}

sub _feature_href {
  my ($self,$f,$hrefs) = @_;

  if(ref $f ne 'HASH' && $f->can('display_id')) {
    return $hrefs->{$f->display_id};
  }
  return '';
}

sub draw_wiggle_points {
  my ($self, $features, $slice, $parameters, $top_offset, $pix_per_score, $colour, $zero_offset) = @_;
  my $hrefs     = $parameters->{'hrefs'};
  my $use_points    = $parameters->{'graph_type'} eq 'points';
  my $max_score = $parameters->{'max_score'};
  my $zero      = $top_offset + $zero_offset;
  my $slice_length = $slice->length;

  foreach my $f (@$features) {
    my $href = $self->_feature_href($f,$hrefs||{});
    my $colour = $self->_special_colour($f,$parameters) || $colour;
    my ($start,$end,$score) = $self->_feature_values($f,$slice_length);
    my $height = _min_defined($score, $max_score) * $pix_per_score;
    my $title = sprintf('%.2f',$score);

    $self->push($self->Rect({
      y         => $zero - max($height, 0),
      height    => $use_points ? 0 : abs $height,
      x         => $start - 1,
      width     => $end - $start + 1,
      absolutey => 1,
      colour    => $colour,
      alpha     => $parameters->{'use_alpha'} ? 0.5 : 0,
      title     => $parameters->{'no_titles'} ? undef : $title,
      href      => $href,
    }));

    # If 'bumped' flag is on, this bumping is different than bumping on other tracks since this one only adds
    # an offset to the y coords to the next rectangle to be drawn so it doesn't overlap with the previous one
    $zero -= $height + 2 if $parameters->{'bumped'};
  }

  return 1;
}

sub draw_wiggle_points_as_line {
  my ($self, $features, $slice, $parameters, $top_offset, $pix_per_score, $colour, $zero_offset) = @_;
  my $slice          = $self->{'container'};
  my $vclen          = $slice->length;
  my $window_size    = ref $features->[0] eq 'HASH' ? 10 : $features->[0]->window_size;
     $features       = [ sort { $a->start <=> $b->start } @$features ] if $window_size == 0;
  my $previous_f     = $features->[0];
  my $previous_x     = ($previous_f->{'end'} + $previous_f->{'start'}) / 2;
  my $previous_score = $previous_f->{'score'};

  if ($window_size == 0) {
    $previous_score = $previous_f->scores->[0];
    $previous_x     = ($previous_f->end + $previous_f->start) / 2;
  }

  my $previous_y = $previous_score < 0 ? 0 : -$previous_score * $pix_per_score;
     $previous_y = $top_offset + $zero_offset + $previous_y;

  for (my $i = 1; $i <= @$features; $i++) {
    my $f             = $features->[$i];
    my $current_x     = ($f->{'end'} + $f->{'start'}) / 2;
    my $current_score = $f->{'score'};

    if ($window_size == 0) {
      next if ref $f eq 'HASH';

      $current_score = $f->scores->[0];
      $current_x     = ($f->end + $f->start) / 2;
    }

    my $current_y = $current_score < 0 ? 0 : -$current_score * $pix_per_score;
    my $width     = 1 - (($current_x - $previous_x) + 1);

    next if $width >= 1;

    my $y_coord = $top_offset + $zero_offset + $current_y;
    my $height  = 1 - ($y_coord - $previous_y);

    next unless $current_x <= $vclen;

    $self->push($self->Line({
      x         => $current_x,
      y         => $y_coord,
      width     => $width,
      height    => $height,
      colour    => $colour,
      absolutey => 1,
    }));

    $previous_x     = $current_x;
    $previous_y     = $y_coord;
    $previous_f     = $f;
    $previous_score = $current_score;
  }
}

1;
