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

package EnsEMBL::Draw::GlyphSet_wiggle_and_block;

### Module to draw a set of Ensembl features as either 
### a 'wiggle' (line graph) or a series of blocks

use strict;

use List::Util qw(min max);

use base qw(EnsEMBL::Draw::GlyphSet_wiggle);

sub draw_error {}

sub render_compact        { return $_[0]->_render;           }
sub render_tiling         { return $_[0]->_render('wiggle'); }
sub render_tiling_feature { return $_[0]->_render('both');   }

### SPECIAL REGULATION SIDE LEGEND STUFF ###

## Draw the special box found on reg. multi-wiggle tracks
sub _add_sublegend_box {
  my ($self,$offset,$content,$click_text) = @_;

  my %font_details = $self->get_font_details('innertext', 1);
  my @text = $self->get_text_width(0,$click_text, '', %font_details);
  my ($width,$height) = @text[2,3];
  $self->push($self->Rect({
    width         => $width + 15,
    absolutewidth => $width + 15,
    height        => $height + 2,
    y             => $offset+13,
    x             => -117,
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
    y         => $offset+13,
    x         => -116,
    absolutey => 1,
    absolutex => 1,
    %font_details,
  }), $self->Triangle({
    width     => 6,
    height    => 5,
    direction => 'down',
    mid_point => [ -123 + $width + 10, $offset+23 ],
    colour    => '#336699',
    absolutex => 1,
    absolutey => 1,
  }));
  return $height;
}

sub _build_reg_legend_text {
  my ($self,$labels,$colours) = @_;

  return '' unless $labels and $colours;
  my ($legend_alt_text, %seen);
  my $max = scalar @$labels - 1;
  for (my $i = 0; $i <= $max; $i++) {
    my $name = $labels->[$i];
    my $colour = $colours->[$i];

    if (!exists $seen{$name}) {
      $legend_alt_text .= "$name:$colour,";
      $seen{$name} = 1;
    }
  }
  $legend_alt_text =~ s/,$//;
  return $legend_alt_text;
}

## Contents of the ZMenu of the special box found on reg. multi-wiggles
sub _sublegend_box_content {
  my ($self,$title,$labels,$colours,$extra_content) = @_;

  my $legend_alt_text = $self->_build_reg_legend_text($labels,$colours);
  $title =~ s/&/and/g; # amps problematic; not just a matter of encoding
  return [$title,"[ $legend_alt_text ]",@{$extra_content||[]}];
}

## Draw the mini label founf on reg. multi-wiggle tracks
sub _draw_mini_label {
  my ($self,$label,$offset) = @_;

  my %font_details = $self->get_font_details('innertext', 1);
  my @res_analysis = $self->get_text_width(0,'Legend & More', '',
                                           %font_details);
  $self->push($self->Text({
    text      => $label,
    height    => $res_analysis[3],
    width     => $res_analysis[2],
    halign    => 'left',
    valign    => 'bottom',
    colour    => 'black',
    y         => $offset,
    x         => -118,
    absolutey => 1,
    absolutex => 1,
    %font_details,
  }));
}

## Draw the mini label and special box found on reg. multi-wiggle tracks
sub _add_sublegend {
  my ($self,$mini_title,$box_click_text,$zmenu_heading,$extra_content,
      $offset,$labels,$colours) = @_;

  $self->_draw_mini_label($mini_title,$offset) if $mini_title;
  my $content = $self->_sublegend_box_content($zmenu_heading,$labels,
                                              $colours,$extra_content);
  my $height = $self->_add_sublegend_box($offset,$content,$box_click_text);
  return $height+4;
}

### END OF SPECIAL REGULATION SIDE LEGEND STUFF ###

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

  my $max_length  = $self->my_config('threshold')   || $self->{'config'}->species_defs->MAX_DRAWING_LENGTH || 10000;
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

sub draw_wiggle_plot {
  my ($self, $features, $parameters, $colours, $labels) = @_;

  $parameters->{'initial_offset'} = $self->_offset;
  $self->_offset($self->do_draw_wiggle($features,$parameters,$colours,$labels));
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

  my @res_analysis;
  while($name) {
    @res_analysis = $self->get_text_width(0, $name, '', %font_details);
    last if($res_analysis[2] < -$x_offset);
    $name = substr($name,0,-1);
  }

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
