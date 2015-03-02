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

package EnsEMBL::Draw::GlyphSet_wiggle_and_block;

### Module to draw a set of Ensembl features as either 
### a 'wiggle' (line graph) or a series of blocks

use strict;

use List::Util qw(min max);

use base qw(EnsEMBL::Draw::GlyphSet);

sub draw_error {}

sub render_compact        { return $_[0]->_render;           }
sub render_tiling         { return $_[0]->_render('wiggle'); }
sub render_tiling_feature { return $_[0]->_render('both');   }

sub render_text {
  my ($self, $wiggle) = @_;
  my $container    = $self->{'container'};
  my $feature_type = $self->my_config('caption');
  my $method       = $self->can('export_feature') ? 'export_feature' : '_render_text';
  my $export;
  
  if ($wiggle ne 'wiggle') {
    my $element_features = $self->can('element_features') ?  $self->element_features : [];
    my $strand           = $self->strand;
    my $strand_flag      = $self->my_config('strand');
    my $length           = $container->length;
    my @features         = sort { $a->[1] <=> $b->[1] } map { ($strand_flag ne 'b' || $strand == $_->{'strand'}) && $_->{'start'} <= $length && $_->{'end'} >= 1 ? [ $_, $_->{'start'} ] : () } @$element_features;
     
    foreach (@features) {
      my $f = $_->[0];
      
      $export .= $self->$method($f, $feature_type, undef, {
        seqname => $f->{'hseqname'}, 
        start   => $f->{'start'} + ($f->{'hstrand'} > 0 ? $f->{'hstart'} : $f->{'hend'}),
        end     => $f->{'end'}   + ($f->{'hstrand'} > 0 ? $f->{'hstart'} : $f->{'hend'}),
        strand  => '.',
        frame   => '.'
      });
    }
  }
  
  if ($wiggle) {
    my $score_features = $self->can('score_features') ? $self->score_features : [];
    my $name           = $container->seq_region_name;
    
    foreach my $f (@$score_features) {
      my $pos = $f->seq_region_pos;
      
      $export .= $self->$method($f, $feature_type, undef, { seqname => $name, start => $pos, end => $pos });
    }
  }
  
  return $export;
}

sub _render {
  ## Show both map and features
  
  my $self = shift;
  
  return $self->render_text(@_) if $self->{'text_export'};
  
  ## Check to see if we draw anything because of size!

  my $max_length  = $self->my_config('threshold')   || 10000;
  my $wiggle_name = $self->my_config('wiggle_name') || $self->my_config('label');

  if ($self->{'container'}->length > $max_length * 1010) {
    my $height = $self->errorTrack("$wiggle_name only displayed for less than $max_length Kb");
    $self->_offset($height + 4);
    
    return 1;
  }
  
  ## Now we try and draw the features
  my $error = $self->draw_features(@_);
  
  return unless $error && $self->{'config'}->get_option('opt_empty_tracks') == 1;
  
  my $here = $self->my_config('strand') eq 'b' ? 'on this strand' : 'in this region';

  my $height = $self->errorTrack("No $error $here", 0, $self->_offset);
  $self->_offset($height + 4);
  
  return 1;
}

sub draw_block_features {
  ### Predicted features
  ### Draws the predicted features track
  ### Arg1: arrayref of Feature objects
  ### Arg2: colour of the track
  ### Returns 1

  my ($self, $features, $colour, $score, $display_summit, $display_pwm) = @_;
  my $length     = $self->{'container'}->length;
  my $pix_per_bp = $self->scalex;
  my $h          = 8;
  
  foreach my $f (@$features) {
    my $start    = $f->start;  
    my $end      = $f->end;
       $start    = 1 if $start < 1;
       $end      = $length if $end > $length;
    my $midpoint = $f->summit;
    my $y        = $self->_offset;
    
    $self->push($self->Rect({
      x         => $start -1,
      y         => $y,
      height    => $h,
      width     => $end - $start,
      absolutey => 1, # in pix rather than bp
      colour    => $colour,
      href      => $self->block_features_zmenu($f, $score),
      class     => 'group',
    }));
    
    if ($display_pwm) {
      my @loci = @{$f->get_underlying_structure}; 
      my $end  = pop @loci;
      my ($start, @mf_loci) = @loci;

      while (my ($mf_start, $mf_end) = splice @mf_loci, 0, 2) {  
        my $mf_length = ($mf_end - $mf_start) + 1;
        
        $self->push($self->Rect({
          x         => $mf_start - 1,
          y         => $y,
          height    => $h,
          width     => $mf_length,
          absolutey => 1,  # in pix rather than bp
          colour    => 'black',
        }));
      }        
    }
    
    if ($length <= 20000 && $midpoint && $display_summit) {
      $midpoint -= $self->{'container'}->start;
      
      if ($midpoint > 0 && $midpoint < $length) {
        $self->push($self->Triangle({ # Upward pointing triangle
          width     => 4 / $pix_per_bp,
          height    => 4,
          direction => 'up',
          mid_point => [ $midpoint, $h + $y ],
          colour    => 'black',
          absolutey => 1,
        }), $self->Triangle({ # Downward pointing triangle
          width     => 4 / $pix_per_bp,
          height    => 4,
          direction => 'down',
          mid_point => [ $midpoint, $h + $y - 9 ],
          colour    => 'black',
          absolutey => 1,
        }));
      }
    }
  }

  $self->_offset($h + 6);
  
  return 1;
}

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

sub draw_wiggle_plot {
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
  my $pix_per_score = $max_score == $min_score ? $self->label->height : $row_height / max($max_score - $min_score, 1);
  my $top_offset    = 0;
  my $initial_offset= $self->_offset;
  my $bottom_offset = $max_score == $min_score ? 0 : (($max_score - ($min_score > 0 ? $min_score : 0)) || 1) * $pix_per_score;
  my $zero_offset   = $max_score * $pix_per_score;
  
  # Draw the labels
  ## Only done if we have multiple data sets
  if ($labels) {
    my $header_label = shift @$labels;
    my $y            = $self->_offset;
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
    
    $self->_offset($y_offset);
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
  
  $self->_offset($row_height + $textheight);
  
  return 1;
}

sub draw_wiggle_points {
  my ($self, $features, $slice, $parameters, $top_offset, $pix_per_score, $colour, $zero_offset) = @_;
  my $hrefs     = $parameters->{'hrefs'};
  my $points    = $parameters->{'graph_type'} eq 'points';
  my $max_score = max($parameters->{'max_score'}, 0);
  my $zero      = $top_offset + $zero_offset;
  
  foreach my $f (@$features) {
    my ($start, $end, $score, $min_score, $height, $width, $x, $y);
    my $href        = ref $f ne 'HASH' && $f->can('display_id') ? $hrefs->{$f->display_id} : '';
    my $this_colour = $colour;
    
    if ($parameters->{'use_feature_colours'} && $f->can('external_data')) {
      my $data        = $f->external_data;
         $this_colour = $data->{'item_colour'}[0] if $data && $data->{'item_colour'} && ref($data->{'item_colour'}) eq 'ARRAY';
    }
    
    # Data is from a Funcgen result set collection, windowsize > 0
    if (ref $f eq 'HASH') {
      $start = $f->{'start'} < 1 ? 1 : $f->{'start'};
      $end   = $f->{'end'}   > $slice->length  ? $slice->length : $f->{'end'};
      $score = $f->{'score'};
    } else {
      $start = $f->start < 1 ? 1 : $f->start; 
      $end   = $f->end   > $slice->length ? $slice->length : $f->end;  

      if ($f->isa('Bio::EnsEMBL::Variation::ReadCoverageCollection')) {
        $score     = $f->read_coverage_max;
        $min_score = $f->read_coverage_min;
      } else {
        $score = $f->can('score') ? $f->score || 0 : $f->can('scores') ? $f->scores->[0] : 0;
      }
    }
    
    # alter colour if the intron supporting feature has a name of non_canonical
    if (ref $f ne 'HASH' && $f->can('display_id') && $f->can('analysis') && $f->analysis->logic_name =~ /_intron/) {
      my $can_type    = [ split /:/, $f->display_id ]->[-1];
         $this_colour = $parameters->{'non_can_score_colour'} || $colour if $can_type && length $can_type > 3 && substr('non canonical', 0, length $can_type) eq $can_type;
    }
    
    $x     = $start - 1;
    $width = $end - $start + 1;
    
    foreach ([ $score, $this_colour ], $min_score ? [ $min_score, 'steelblue' ] : ()) {
      $height = ($max_score ? min($_->[0], $max_score) : $_->[0]) * $pix_per_score;
      $y      = $zero - max($height, 0);
      $height = $points ? 0 : abs $height;

      $self->push($self->Rect({
        y         => $y,
        height    => $height,
        x         => $x,
        width     => $width,
        absolutey => 1,
        colour    => $_->[1],
        alpha     => $parameters->{'use_alpha'} ? 0.5 : 0,
        title     => $parameters->{'no_titles'} ? undef : sprintf('%.2f', $_->[0]),
        href      => $href,
      }));
    }

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
  my $im_width       = $self->{'config'}->image_width;
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

sub draw_track_name {
  ### Predicted features
  ### Draws the name of the predicted features track
  ### Arg1: arrayref of Feature objects
  ### Arg2: colour of the track
  ### Returns 1

  my ($self, $name, $colour, $x_offset, $y_offset, $no_offset) = @_; 
  my $x  = $x_offset || 1;  
  my $y  = $self->_offset; 
     $y += $y_offset if $y_offset;
     
  my %font_details = $self->get_font_details('innertext', 1); 
  my @res_analysis = $self->get_text_width(0, $name, '', %font_details);

  $self->push($self->Text({
    x         => $x,
    y         => $y,
    text      => $name,
    height    => $res_analysis[3],
    width     => $res_analysis[2],
    halign    => 'left',
    valign    => 'bottom',
    colour    => $colour,
    absolutey => 1,
    absolutex => 1,
    %font_details,
  }));

  $self->_offset($res_analysis[3]) unless $no_offset;
  
  return 1;
}

sub display_no_data_error {
  my ($self, $error_string,$mild) = @_;
  my $height = $self->errorTrack($error_string, 0, $self->_offset,$mild);
  $self->_offset($height + 4); 
}

sub draw_space_glyph {
  ### Draws a an empty glyph as a spacer
  ### Arg1 : (optional) integer for space height,
  ### Returns 1

  my ($self, $space) = @_;
  $space ||= 9;

  $self->push($self->Space({
    height    => $space,
    width     => 1,
    y         => $self->_offset,
    x         => 0,
    absolutey => 1,  # puts in pix rather than bp
    absolutex => 1,
  }));
  
  $self->_offset($space);
  
  return 1;
}

sub _offset {
  ### Arg1 : (optional) number to add to offset
  ### Description: Getter/setter for offset
  ### Returns : integer

  my ($self, $offset) = @_;
  $self->{'offset'} += $offset if $offset;
  return $self->{'offset'} || 0;
}

1;
