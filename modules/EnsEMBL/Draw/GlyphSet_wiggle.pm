=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

sub supports_subtitles { 1; }
sub wiggle_subtitle { undef; }
sub subtitle_colour { $_[0]->{'subtitle_colour'} || 'slategray' }
sub subtitle_text {
  my ($self) = @_;

  my $name = $self->my_config('short_name') || $self->my_config('name');
  my $label = $self->wiggle_subtitle;
  $label =~ s/\[\[name\]\]/$name/;
  $label =~ s/<.*?>//g;
  return $label;
}

sub _draw_axes {
  my ($self,$top,$zero,$bottom,$slice_length,$parameters) = @_;

  my $axis_style = $parameters->{'graph_type'} eq 'line' ? 0 : 1;
  my $axis_colour =
    $parameters->{'axis_colour'} || $self->my_colour('axis') || 'red';
  $self->push($self->Line({ # horizontal line
    x         => 0,
    y         => $zero,
    width     => $slice_length,
    height    => 0,
    absolutey => 1,
    colour    => $axis_colour,
    dotted    => $axis_style,
  }), $self->Line({ # vertical line
    x         => 0,
    y         => $top,
    width     => 0,
    height    => $bottom - $top,
    absolutey => 1,
    absolutex => 1,
    colour    => $axis_colour,
    dotted    => $axis_style,
  }));
}

sub _draw_score {
  my ($self,$y,$value,$parameters) = @_;

  my $text = sprintf('%.2f',$value);
  my %font = $self->get_font_details('innertext', 1);
  my $width = [ $self->get_text_width(0, $text, '', %font) ]->[2];
  my $height = [ $self->get_text_width(0, 1, '', %font) ]->[3];
  my $colour =
      $parameters->{'axis_colour'} || $self->my_colour('axis')  || 'red';
  $self->push($self->Text({
    text          => $text,
    height        => $height,
    width         => $width,
    textwidth     => $width,
    halign        => 'right',
    colour        => $colour,
    y             => $y - $height/2,
    x             => -10 - $width,
    absolutey     => 1,
    absolutex     => 1,
    absolutewidth => 1,
    %font,
  }), $self->Rect({
    height        => 0,
    width         => 5,
    colour        => $colour,
    y             => $y,
    x             => -8,
    absolutey     => 1,
    absolutex     => 1,
    absolutewidth => 1,
  }));
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

sub _draw_wiggle_points_as_bar_or_points {
  my ($self,$c,$features,$parameters) = @_;

  my $hrefs         = $parameters->{'hrefs'};
  my $use_points    = $parameters->{'graph_type'} eq 'points';
  my $max_score     = $parameters->{'max_score'};
  my $slice_length  = $self->{'container'}->length;
  my @rectangles;

  foreach my $f (@$features) {
    my $href = $self->_feature_href($f,$hrefs||{});
    my $colour = $self->_special_colour($f,$parameters) || $c->{'colour'};
    my ($start,$end,$score) = $self->_feature_values($f,$slice_length);
    my $height = ($score-$c->{'line_score'}) * $c->{'pix_per_score'};
    my $title = sprintf('%.2f',$score);

    push @rectangles, {
      y         => $c->{'line_px'} - max($height, 0),
      height    => $use_points ? 0 : abs $height,
      x         => $start - 1,
      width     => $end - $start + 1,
      absolutey => 1,
      colour    => $colour,
      alpha     => $parameters->{'use_alpha'} ? 0.5 : 0,
      title     => $parameters->{'no_titles'} ? undef : $title,
      href      => $href,
      class     => $parameters->{'class'} // ''
    };
  }

  $self->push($self->Rect($_)) for sort { $b->{'height'} <=> $a->{'height'} } @rectangles;
}

sub _discrete_features {
  my ($self,$ff) = @_;

  if(ref($ff->[0]) eq 'HASH' or $ff->[0]->window_size) {
    return 0;
  } else {
    return 1;
  }
}

sub _draw_wiggle_points_as_line {
  my ($self, $c, $features) = @_;
  return unless $features && $features->[0];
  my $slice_length = $self->{'container'}->length;
  my $discrete_features = $self->_discrete_features($features);
  if($discrete_features) {
    $features = [ sort { $a->start <=> $b->start } @$features ];
  }
  elsif (ref($features->[0]) eq 'HASH') {
    $features = [ sort { $a->{'start'} <=> $b->{'start'} } @$features ];
  }

  my ($previous_x,$previous_y);
  for (my $i = 0; $i < @$features; $i++) {
    my $f = $features->[$i];
    next if ref $f eq 'HASH' and $discrete_features;

    my ($current_x,$current_score);
    if ($discrete_features) {
      $current_score = $f->scores->[0];
      $current_x     = ($f->end + $f->start) / 2;
    } else {
      $current_x     = ($f->{'end'} + $f->{'start'}) / 2;
      $current_score = $f->{'score'};
    }
    my $current_y = $c->{'line_px'}-($current_score-$c->{'line_score'}) * $c->{'pix_per_score'};
    next unless $current_x <= $slice_length;

    if(defined $previous_x) {
      $self->push($self->Line({
        x         => $current_x,
        y         => $current_y,
        width     => $previous_x - $current_x,
        height    => $previous_y - $current_y,
        colour    => $c->{'colour'},
        absolutey => 1,
      }));
    }

    $previous_x     = $current_x;
    $previous_y     = $current_y;
  }
}

sub _draw_wiggle_points_as_graph {
  my ($self, $c, $features,$parameters) = @_;

  my $height = $c->{'pix_per_score'} * $parameters->{'max_score'};
  $self->push($self->Barcode({
    values    => $features,
    x         => 1,
    y         => 0,
    height    => $height,
    unit      => $parameters->{'unit'},
    max       => $parameters->{'max_score'},
    colours   => [$c->{'colour'}],
    wiggle    => $parameters->{'graph_type'},
  }));
}

sub draw_wiggle_points {
  my ($self,$c,$features,$parameters) = @_;

  if($parameters->{'unit'}) {
    $self->_draw_wiggle_points_as_graph($c,$features,$parameters);
  } elsif($parameters->{'graph_type'} eq 'line') {
    $self->_draw_wiggle_points_as_line($c,$features,$parameters);
  } else {
    $self->_draw_wiggle_points_as_bar_or_points($c,$features,$parameters);
  }
}

sub _add_regulation_minilabel {
  my ($self,$parameters,$top,$labels,$colours) = @_;

  my $header_label = shift @$labels;
  my $click_text = $parameters->{'zmenu_click_text'} || 'Legend';
  my $extra_content = $parameters->{'zmenu_extra_content'};
  $self->_add_sublegend($header_label,$click_text,$header_label,
                        $extra_content,$top,$labels,$colours);
}

sub _draw_guideline {
  my ($self,$width,$y,$type) = @_;

  $type ||= '1';
  $self->push($self->Line({
    x         => 0,
    y         => $y,
    width     => $width,
    height    => 1,
    colour    => 'grey90',
    absolutey => 1,
    dotted => $type,
  }));
}

sub do_draw_wiggle {
  my ($self, $features, $parameters, $colours, $labels) = @_;

  my $slice = $self->{'container'};
  my $row_height =
    $parameters->{'height'} || $self->my_config('height') || 60;
 
  # max_score: score at top of y-axis on graph
  # min_score: score at bottom of y-axis on graph
  # range: scores spanned by graph (small value used if identically zero)
  # pix_per_score: vertical pixels per unit score
  my $max_score     = $parameters->{'max_score'};
  my $min_score     = $parameters->{'min_score'};
  my $range = $max_score-$min_score;
  if($range < 0.01) {
    # Oh dear, data all has pretty much same value ...
    if($max_score > 0.01) {
      # ... but it's not zero, so just move minimum down
      $min_score = 0;
    } else {
      # ... just create some sky
      $max_score = 0.1;
    }
  }
  $range = $max_score-$min_score;
  my $pix_per_score = $row_height/$range;

  # top: top of graph in pixel units, offset from track top (usu. 0)
  # line_score: value to draw "to" up/down, in score units (usu. 0)
  # line_px: value to draw "to" up/down, in pixel units (usu. 0)
  # bottom: bottom of graph in pixel units (usu. approx. pixel height)
  my $top = ($parameters->{'initial_offset'}||0);
  my $line_score = max(0,$min_score);
  my $bottom = $top + $pix_per_score * $range;
  my $line_px = $bottom - ($line_score-$min_score) * $pix_per_score;

  # Make sure subtitles will be correctly coloured
  $self->{'subtitle_colour'} ||=
    $parameters->{'score_colour'} || $self->my_colour('score') || 'blue';

  # Shift down the lhs label to between the axes unless the subtitle is within the track
  if($bottom-$top > 30 && $self->wiggle_subtitle) {
    # luxurious space for centred label
    # graph is offset down if subtitled
    $self->{'label_y_offset'} =
        ($bottom-$top)/2             # half-way-between
        + $self->subtitle_height     
        - 16;                        # two-line label so centre its centre
  } else {
    # tight, just squeeze it down a little
    $self->{'label_y_offset'} = 0;
  }

  # Extra regulation left-legend stuff
  if($labels) {
    $self->_add_regulation_minilabel($parameters,$top,$labels,$colours);
  }

  # Draw axes and their numerical labels
  if (!$parameters->{'no_axis'}) {
    $self->_draw_axes($top,$line_px,$bottom,$slice->length,$parameters);
  }
  if ($parameters->{'axis_label'} ne 'off') {
    $self->_draw_score($top,$max_score,$parameters);
    $self->_draw_score($bottom,$min_score,$parameters);
  }
  if(!$parameters->{'no_axis'} and !$parameters->{'no_guidelines'}) {
    foreach my $i (1..4) {
      my $type;
      $type = 'small' unless $i % 2;
      $self->_draw_guideline($slice->length,($top*$i+$bottom*(4-$i))/4,
                             $type);
    }
  }

  # Single line? Build into singleton set.
  $features = [ $features ] if ref $features->[0] ne 'ARRAY';
 
  # Draw them! 
  my $plot_conf = {
    line_score => $line_score,
    line_px => $line_px,
    pix_per_score => $pix_per_score,
    colour =>
      $parameters->{'score_colour'}  || $self->my_colour('score') || 'blue',
  };
  foreach my $feature_set (@$features) {
    $plot_conf->{'colour'} = shift(@$colours) if $colours and @$colours;
    $self->draw_wiggle_points($plot_conf,$feature_set, $parameters);
  }

  return $row_height;
}

1;
