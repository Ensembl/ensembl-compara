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

package EnsEMBL::Draw::GlyphSet_generic;

### Parent module of GlyphSet::_das

use strict;
use warnings;
no warnings 'uninitialized';

use Data::Dumper;
use HTML::Entities qw(encode_entities decode_entities);

use Bio::EnsEMBL::Feature;
use List::Util qw(max min);

use base qw(EnsEMBL::Draw::GlyphSet);

sub features {
  return {
    'f_count'    => 0,
    'g_count'    => 0,
    'merge'      => 0, # Merge all logic names into one track. Note different from other systems
    'groups'     => {},
    'f_styles'   => {},
    'g_styles'   => {},
    'errors'     => [],
    'ss_errors'  => [],
    'urls'       => [],
    'ori'        => {},
    'max_height' => 0
  };
} 

sub _draw_features {
  my ($self, $ori, $features, $render_flags) = @_;
  
  $self->_init_bump;
  
  my $strand = $self->strand;
  my $ppbp = $self->{'ppbp'} = $self->scalex;
  my $seq_len = $self->{'seq_len'} = $self->{'container'}->length;
  my $colour = $ori ? 'blue' : 'green';
  my $offset = $self->{'container'}->start - 1;
  my $has_labels = 0;
  my %can_hash;
  
  $self->{'bppp'} = 1 / $ppbp; 
  $self->{'h'} = 0;
  
  foreach my $lname (sort keys %{$features->{'groups'}}) {    
    foreach my $gkey (sort keys %{$features->{'groups'}{$lname}}) {
      my $group = $features->{'groups'}{$lname}{$gkey}{$ori};
      
      next unless $group;                                          # No features from this group on this strand
      next if $group->{'end'} < 1 || $group->{'start'} > $seq_len; # All features in group exist outside region
      
      # Now loop through all features and get the extents of features - we will need this later for bumping! and joining!
      my $g_s = $features->{'g_styles'}{$lname}{$group->{'type'}}; # Get the group style
      my $to_join = lc($g_s->{'style'}{'symbol'}) ne 'hidden';
      
      $g_s->{'style'}{'label'} = 'yes' if $render_flags eq 'force_labels';
      $has_labels = 1 if $g_s->{'style'}{'label'} eq 'yes';

      foreach my $style_key (keys %{$group->{'features'}}) {
        my $f_s  = $features->{'f_styles'}{$lname}{$style_key};
        
        $f_s->{'style'}{'label'} = 'yes' if $render_flags eq 'force_labels';
        $has_labels = 1 if $f_s->{'style'}{'label'} eq 'yes';
        
        my $to_bump = lc($f_s->{'style'}{'bump'}) eq 'yes' || $f_s->{'style'}{'bump'} eq '1'; # Bump if style bump is set
        my $fn_c = "composite_extent_".$f_s->{'style'}{'symbol'};
        my $fn_g = "extent_".$f_s->{'style'}{'symbol'};
        
        $can_hash{$fn_c} ||= $self->can($fn_c);
        $can_hash{$fn_g} ||= $self->can($fn_g) || '-';
        
        $fn_g = 'extent_box' if $can_hash{$fn_g} eq '-'; # default to drawing a box
        
        # This is one of the histogram style displays and the render fn has been defined
        if ($can_hash{$fn_c}) {
          $self->$fn_c($group, $f_s->{'style'});
          
          if ($f_s->{'style'}{'label'} eq 'yes') {
            $g_s->{'style'}{'label'} = 'yes';
            $g_s->{'style'}{'fgcolor'} ||= $f_s->{'style'}{'fgcolor'};
          }
        } else {
          if ($f_s->{'style'}{'label'} eq 'yes' && $to_join && !$to_bump) {
            $g_s->{'style'}{'label'} = 'yes';
            $g_s->{'style'}{'fgcolor'} ||= $f_s->{'style'}{'fgcolor'};
          }
          
          # Compute the extent of each glyph - and add to extent of group if not bumped
          foreach my $f (@{$group->{'features'}{$style_key}}) {
            # Only pass the glyph if we are going to put this glyph in a composite
            $self->$fn_g($to_join && !$to_bump ? $group : undef, $f, $f_s->{'style'});
          }
        }
        
        $group->{'height'} = $g_s->{'style'}{'height'} if $g_s->{'style'}{'height'} > $group->{'height'} && $group->{'extent_start'};
        $self->{'h'} = $g_s->{'style'}{'height'} if $g_s->{'style'}{'height'} > $self->{'h'} && $group->{'extent_start'};
      }
    }
  }
  
  $self->{'h'} ||= 12;
  
  # All groups and features now have two additional values
  # -> extent_start and extent_end so we know where to draw the boxes

  $has_labels = 0 unless $render_flags eq 'label_under' || $render_flags eq 'force_labels';

  my ($fontname, $fontsize) = $has_labels ? $self->get_font_details('outertext') : (undef, -2);

  foreach my $lname (sort keys %{$features->{'groups'}}) {
    foreach my $gkey (sort keys %{$features->{'groups'}{$lname}}) {
      my $group = $features->{'groups'}{$lname}{$gkey}{$ori};
      
      next unless $group; # May not have group on this strand
      
      # We now have a feature....
      # Now let us grab all the features in the group as we need to work out the width of the "group"
      # which may be wider than the feature if
      #   (a) we have labels (width of label if wider than feature)
      #   (b) have fixed width glyphs at points
      #   (c) have histogram data - has nos to left of graph
      
      # Start with looking for special "aggregator glyphs"
      my $g_s = $features->{'g_styles'}{$lname}{$group->{'type'}}; # Get the group style
      my @boxes;
      my $to_join = lc($g_s->{'style'}{'symbol'}) ne 'hidden';
      my $composite_flag = 0;
      my $score_based_flag = 0;
      
      $group->{'height'} ||= $self->{'h'};
      
      foreach (keys %{$group->{'features'}}) {
        $score_based_flag = 1 if $features->{'f_styles'}{$lname}{$_}{'use_score'}; # Composite if it is a graph
        
        # Composite if the features are to be bumped && linked
        if (lc($features->{'f_styles'}{$lname}{$_}{'style'}{'bump'} ne 'yes') && $features->{'f_styles'}{$lname}{$_}{'style'}{'bump'} ne '1') {
          $composite_flag ||= $to_join;
        }
      }
      
      if ($composite_flag || $score_based_flag) {
        my $end;
        my ($T, $TF, $tw, $h);
        my $label = '';
        
        if ($has_labels && $g_s->{'style'}{'label'} eq 'yes') {
          $label = $group->{'label'} ne '' ? $group->{'label'}
                 : ($render_flags eq 'force_labels') && defined($group->{'id'}) ? $group->{'id'}
                 : '';
        }
        
        if ($label ne '') {
          ($T, $TF, $tw, $h) = $self->get_text_width(0, $label, '', 'font' => $fontname, 'ptsize' => $fontsize);
          $end = $group->{'start'} + ($tw + 4) * $self->{'bppp'};
        }
        
        $end = $group->{'end'} if $group->{'end'} > $end;

        if ($group->{'extent_end'} > 0 && $group->{'extent_start'} < $seq_len) {
          my $row = $self->bump_row($group->{'start'} * $ppbp, $end * $ppbp) + $self->{'_row_offset'};
            
          $group->{'y'} = - $strand * $row * ($self->{'h'} + $fontsize + 4);
          # subgroups is always just the group unless a pseudogroup,
          # in which case it is all its members. For zmenus, etc.
          my @subgroups = ($group);
          @subgroups = @{$group->{'pg_members'}} if $group->{'pg_members'};

          foreach my $i (0..$#subgroups) {
            my $sg = $subgroups[$i];
            my $sg_p = $i ? $subgroups[$i-1] : undef;
            my $sg_n = $subgroups[$i+1];
            my $href = undef;
            my $title = sprintf(
              '%s; Start: %s; End: %s%s%s',
              $sg->{'label'} || $sg->{'id'},
              $sg->{'start'} + $offset,
              $sg->{'end'}   + $offset,
              $sg->{'strand'} ? '; Strand: ' . ($sg->{'strand'} > 0 ? '+' : '-') : '',
              $sg->{'count'} > 1 ? '; Features: ' . $sg->{'count'} : ''
            );
            
            if (@{$sg->{'links'}||[]}) {
              $href = $sg->{'links'}[0]{'href'};
            } elsif (@{$sg->{'flinks'}||[]}) {
              $href = $sg->{'flinks'}[0]{'href'};
            }
            
            if (@{$sg->{'notes'}||[]}) {
              $title .= join '', map { '; ' . encode_entities(decode_entities($_)) } @{$sg->{'notes'}};
            } elsif (@{$sg->{'fnotes'}||[]}) {
              $title .= join '', map { '; ' . encode_entities(decode_entities($_)) } @{$sg->{'fnotes'}};
            }
          
            $title .= '; Type: ' . ($sg->{'type_label'} || $sg->{'type'}) if $sg->{'type'};
            $title .= '; Id: '   . $sg->{'id'} if $sg->{'id'}; ### Id attribute MUST BE THE LAST thing in the title tag or z-menus won't work properly

            my ($s,$e) = ($sg->{'start'},$sg->{'end'});
            if($group->{'pg_members'}) { # ie only for pseudogroups
              # Add wiggle room for ham-fisted clicking: 8px or half-way
              my $fudge = 8 / $self->scalex; # ie 8px
              if(defined $sg_p) {
                $s = max($sg->{'start'}-$fudge,($sg_p->{'end'}+$sg->{'start'})/2);
              } else {
                $s = $sg->{'start'}-$fudge;
              }
              if(defined $sg_n) {
                $e = min($sg->{'end'}+$fudge,($sg_n->{'start'}+$sg->{'end'})/2);
              } else {
                $e = $sg->{'end'}+$fudge;
              }
            }
            $s = max(0,$s);
            $e = min($seq_len,$e);
            $self->push($self->Space({
              'absolutey'    => 1,
              'x'            => $s - 1,
              'width'        => $e - $s + 1,
              'y'            => $group->{'y'},
              'height'       => $self->{'h'},
              'href'         => $href,
              'title'        => $title,
              'class'        => $group->{'class'}
            }));
          } 
          my $s = $group->{'extent_start'};
          # Create a composite for the group and bump it
          $self->push($self->Text({
            'absolutey' => 1,
            'x'         => $s - 1 + 2 * $self->{'bppp'},
            'width'     => $tw / $ppbp,
            'y'         => $group->{'y'} + $self->{'h'} + 2,
            'textwidth' => $tw,
            'height'    => $fontsize,
            'halign'    => 'left',
            'valign'    => 'center',
            'ptsize'    => $fontsize,
            'font'      => $fontname,
            'colour'    => $g_s->{'style'}{'fgcolor'} || 'black',
            'text'      => $label
          })) if $label ne '';
        }
      }

      foreach my $style_key (
        map  { $_->[2] }
        sort { $a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] }
        map  {[
          $features->{'f_styles'}{$lname}{$_}{'style'}{'zindex'} || 0, # Render in z-index order
          $features->{'f_styles'}{$lname}{$_}{'use_score'}       || 0, # Render non-"group features" first
          $_                                                           # What we want the key to be
        ]}
        keys %{$group->{'features'}}
      ) {
        # Grab the style for the group of features
        my $f_s = $features->{'f_styles'}{$lname}{$style_key};
        $f_s->{'style'}{'height'} ||= $self->{'h'};
        
        my $to_bump = lc($f_s->{'style'}{'bump'}) eq 'yes' || $f_s->{'style'}{'bump'} eq '1';
       
        my $fn_c = 'composite_' . lc($f_s->{'style'}{'symbol'});
        my $fn_g = 'glyph_' . lc($f_s->{'style'}{'symbol'});
        
        $can_hash{$fn_c} ||= $self->can($fn_c);
        $can_hash{$fn_g} ||= $self->can($fn_g) || '-' ; # Default to drawing a box
        
        $fn_g = 'glyph_box' if $can_hash{$fn_g} eq '-';
        
        # This is one of the histogram style displays and the render fn has been defined
        if ($can_hash{$fn_c}) {
          $self->$fn_c($group, $group->{'features'}{$style_key}, $f_s->{'style'});
        } else {
          # We are bumping this feature so do not group it
          if ($to_bump || !$to_join) {
            # Draw the features in order
            foreach my $f (sort { $a->start <=> $b->start } @{$group->{'features'}{$style_key}}) {
              
              next unless defined $f->{'extent_start'};
              
              # Create glyph and bump it
              $f->{'y'} = 0;
              my ($T, $TF, $tw, $h);
              
              if ($to_bump) {
                my $end;
                
                if ($has_labels && $f->display_label && $f_s->{'style'}{'label'} eq 'yes') {
                  ($T, $TF, $tw, $h) = $self->get_text_width(0, $f->display_label, '', 'font' => $fontname, 'ptsize' => $fontsize);
                  $end = $f->{'extent_start'} + ($tw + 4) * $self->{'bppp'};
                }
                
                $end = $f->{'extent_end'} if $f->{'extent_end'} > $end;
                
                my $row = $self->bump_row($f->{'extent_start'} * $ppbp, $end * $ppbp ) + $self->{'_row_offset'};
                $f->{'y'} = - $strand * $row * ($self->{'h'} + $fontsize + 4); # reposition
              }
              
              my $href = @{$f->{'link'}||[]} ? $f->{'link'}->[0]{'href'} : undef;
              
              my $title = sprintf(
                '%s; Start: %s; End: %s%s%s%s',
                $f->display_label || $f->display_id,
                $f->seq_region_start,
                $f->seq_region_end,
                $f->seq_region_strand ? '; Strand: ' . ($f->seq_region_strand > 0 ? '+' : '-') : '',
                $f->type_id           ? '; Type: '   . ($f->type_label || $f->type_id)         : '',
                $f->display_id        ? '; Id: '     . $f->display_id                          : '' ### Id attribute MUST BE THE LAST thing in the title tag or z-menus won't work properly
              );

              $self->push($self->Space({
                'x'         => $f->{'extent_start'} - 1,
                'width'     => $f->{'extent_end'} - $f->{'extent_start'} + 1,
                'y'         => $f->{'y'},
                'height'    => $self->{'h'},
                'absolutey' => 1,
                'href'      => $href,
                'title'     => $title,
                'class'     => $group->{'class'}
              }));
              
              $self->push($self->Text({
                'absolutey' => 1,
                'x'         => $f->{'extent_start'} - 1 + 2 * $self->{'bppp'},
                'width'     => $tw / $ppbp,
                'y'         => $f->{'y'} + $self->{'h'} + 2,
                'halign'    => 'left',
                'valign'    => 'center',
                'textwidth' => $tw,
                'colour'    => $f_s->{'style'}{'fgcolor'} || 'black',
                'height'    => $fontsize,
                'ptsize'    => $fontsize,
                'font'      => $fontname,
                'text'      => $f->display_label
              })) if $has_labels && $f->display_label && $f_s->{'style'}{'label'} eq 'yes';
              
              $self->$fn_g(undef, $f, $f_s->{'style'});
            }
         } else { # We are grouping these features
            # Draw the features in order
            foreach my $f (sort { $a->start <=> $b->start } @{$group->{'features'}{$style_key}}) {
              next unless $f->{'extent_start'};
              
              $self->$fn_g( $group, $f, $f_s->{'style'});
              
              my ($s, $e) = ($f->{'extent_start'}, $f->{'extent_end'});
              
              # If it overlaps or abuts (int based)
              if (@boxes && ($s >= $boxes[-1][0] && $s <= $boxes[-1][1] + 1)) {
                $boxes[-1][1] = $e if $e > $boxes[-1][1];
              } else {
                push @boxes, [ $s, $e ];
              }
            }
          }
        }
      }
      
      my @boxes_2;
      
      if (@boxes) {
        @boxes = sort { $a->[0] <=> $b->[0] } @boxes;
        my $t = shift @boxes;
        @boxes_2 = ($t);
        
        foreach (@boxes) {
          # If it overlaps or abuts (int based)
          if ($_->[0] >= $boxes_2[-1][0] && $_->[1] <= $boxes_2[-1][1] + 1) {
            $boxes_2[-1][1] = $_->[1];
          } else {
            push @boxes_2, $_;
          }
        }
      }
      
      if ($composite_flag && !$score_based_flag) {
        my $y_pos = $group->{'y'} + $self->{'h'}/2;
        
        # Draw a glyph to the left
        if ($boxes_2[0][0] > 1 && $group->{'start'} <= 1) {
          $self->push($self->Line({
            'x'         => 0,
            'width'     => $boxes_2[0][0] - 1,
            'y'         => $y_pos,
            'height'    => 0,
            'absolutey' => 1,
            'dotted'    => 1,
            'colour'    => $g_s->{'style'}{'fgcolor'}
          }));
        }
        
        # Draw a glyph to the right
        if ($boxes_2[-1][1] < $seq_len && $group->{'end'} >= $seq_len) {
          $self->push($self->Line({
            'x'         => $boxes_2[-1][1],
            'width'     => $seq_len - $boxes_2[-1][1],
            'y'         => $y_pos,
            'height'    => 0,
            'absolutey' => 1,
            'dotted'    => 1,
            'colour'    => $g_s->{'style'}{'fgcolor'}
          }));
        }
        
        # Draw a glyph between pairs
        my $t = shift @boxes_2;
        
        foreach (@boxes_2) {
          # Draw a glyph from ($t->[-1] - $_->[0])
          my $f = $self->gen_feature({
            'start'  => $t->[1] + 1,
            'end'    => $_->[0] - 1,
            'strand' => $group->{'strand'} 
          });
          
          $f->{'y'}            = $group->{'y'};
          $f->{'extent_start'} = $t->[1] + 1;
          $f->{'extent_end'}   = $_->[0] - 1;
          
          my $method = "glyph_$g_s->{'style'}{'symbol'}";
          $method = 'glyph_box' unless $self->can($method);
          
          $self->$method(undef, $f, $g_s->{'style'});

          $t = $_;
        }
      }
    }
  }
  
	$self->{'_row_offset'} = $self->_max_bump_row;
}

sub render_nolabels {
  my $self = shift;
  $self->_render('nolabel');
}

sub render_normal {
  my $self = shift;
  $self->_render('label_under');
}

sub render_labels {
  my $self = shift;
  $self->_render('force_labels');
}

sub _render {
  my ($self, $render_flags) = @_;
  
  return $self->render_text if $self->{'text_export'};
  
  $render_flags ||= 'label_under';
  $self->{'y_offset'} = 0;

  # Grab and cache features as we need to find out which strands to draw them on
  my $features = $self->cache('generic:'.$self->{'my_config'}->id);
  $features = $self->cache('generic:'.$self->{'my_config'}->id, $self->features) unless $features;
  
  $self->timer_push('Fetched DAS features', undef, 'fetch');
  
  my $strand = $self->strand;

  my $y_offset = 0; # Useful to track errors

  # If we have errors then we will uniquify and sort
  if (@{$features->{'errors'}}) {
    my %saw = map { ($_, 1) } @{$features->{'errors'}};
    $self->errorTrack($_, undef, $self->{'y_offset'} += 12) foreach grep { $_ } sort keys %saw;
  }

  # Draw stranded features first
	$self->{'_row_offset'} = 0;
  $self->_draw_features($strand, $features, $render_flags) if $features->{'ori'}{$strand};
  
  # Draw unstranded features last, so they go below stranded features
  $self->_draw_features(0, $features, $render_flags) if $features->{'ori'}{0} && $strand == -1;
}

sub render_text {
  my $self = shift;
  
  my $features = $self->features;
  my $feature_type = $self->my_config('caption');
  my $method = $self->can('export_feature') ? 'export_feature' : '_render_text';
  my $export;
  
  foreach (sort keys %{$features->{'groups'}}) {
    my $lnames = $features->{'groups'}->{$_};
    
    foreach (sort keys %$lnames) {
      my $gkeys = $lnames->{$_};
      
      foreach (sort keys %$gkeys) {
        my $group_features = $gkeys->{$_}->{'features'};
        
        foreach my $key (sort keys %$group_features) {
          foreach (sort { $a->start <=> $b->start } @{$group_features->{$key}}) {
            $export .= $self->$method($_, $feature_type);
          }
        }
      }
    }
  }
  
  return $export;
}


# Two sorts of renderer - composite renderers - work on every element in the collection

sub composite_extent_histogram {
  my ($self, $g, $st) = @_;
  $self->composite_extent_gradient($g, $st);
}

sub composite_histogram {
  my ($self, $g, $f_ref, $st) = @_; # These have passed in the group + all the features in the group
  
  return if $g->{'extent_end'} <= 0;

  my $cp = $self->_colour_points($st);

  my $strand = $self->strand;
  my $l      = $self->{'seq_len'};
  my $min    = $st->{'min'};
  my $max    = $st->{'max'};
  my $range  = $max-$min;
  my $y      = $g->{'y'} + ($self->{'h'} - $st->{'height'})/2;
  my $sf     = $st->{'height'}/$range;

  $self->push($self->Line({
    'x'         => $g->{'extent_start'} - 1,
    'width'     => $g->{'extent_end'} - $g->{'extent_start'} + 1,
    'height'    => 0,
    'colour'    => 'red',
    'absolutey' => 1,
    'dotted'    => 1,
    'y'         => $y + ($strand > 0 ? -$min : $range + $min) * $sf
  })) if $min <= 0 && $max >= 0;
  
  $self->push($self->Line({
    'x'         => $g->{'extent_start'} - 1,
    'width'     => 0,
    'height'    => $st->{'height'},
    'colour'    => 'red',
    'absolutey' => 1,
    'dotted'    => 1,
    'y'         => $y
  }));
  
  $self->unshift($self->Space({
    'x'         => $g->{'extent_start'} - 1,
    'width'     => $g->{'extent_end'} - $g->{'extent_start'} + 1,
    'height'    => $st->{'height'},
    'absolutey' => 1,
    'y'         => $y
  }));
  
  foreach my $f (sort { $a->start <=> $b->start } @$f_ref) {
    my ($s, $e) = ($f->start, $f->end);
    
    next if $e < 1;
    last if $s > $l;
    
    $s = 1 if $s < 1;
    $e = $l if $e >$l;
    
    my $v = ($f->score - $min)/$range;
    my $c = $self->{'config'}->colourmap->hex_by_rgb($self->_colour($v, $cp));
    
    my($o, $h) = $f->score < $min ? (0, -$min)
               : $f->score > $max ? (-$min, $max)
               : $f->score < 0    ? (-$min + $f->score, -$f->score)
               :                    (-$min, $f->score);
    
    my $y_x = $y + ($strand > 0 ? $o : ($range - $o - $h))*$sf;
    
    $self->push($self->Rect({
      'height'    => $sf * $h,
      'x'         => $s - 1,
      'width'     => $e - $s + 1,
      'y'         => $y_x,
      'colour'    => $c,
      'absolutey' => 1
    }));
  }
  
  return ();
}

sub composite_extent_gradient {
  my ($self, $g, $st) = @_;
  
  return if $g->{'start'} > $self->{'seq_len'} || $g->{'end'} < 1;

  if ($g->{'fake'}) {
    $g->{'extent_start'} = max(1,$g->{'start'});
    $g->{'extent_end'}   = min($self->{'seq_len'},$g->{'end'});
  } else {
    my $gs = $g->{'start'} < 1 ? 1 : $g->{'start'};
    my $ge = $g->{'end'}   < $self->{'seq_len'} ? $g->{'end'} : $self->{'seq_len'};
    my $p  = 2 * $self->{'bppp'};
    
    $g->{'extent_start'} = $gs - $p if !defined($g->{'extent_start'}) || $g->{'start'} < $g->{'extent_start'};
    $g->{'extent_end'}   = $ge + $p if !defined($g->{'extent_end'}  ) || $g->{'end'}   > $g->{'extent_start'};
  }
  
  $g->{'height'} = $st->{'height'} if !defined($g->{'height'}) || $st->{'height'} > $g->{'height'};
  $self->{'h'}   = $st->{'height'} if !defined($self->{'h'})   || $st->{'height'} > $self->{'h'};
}

sub _colour_points {
  my ($self, $st) = @_;

  my @colour_points;
  
  for (1..9) { 
    my @c = $self->{'config'}->colourmap->rgb_by_name($st->{"color$_"}, 1) if $st->{"color$_"};
    push @colour_points, \@c if @c;
  }
  
  push @colour_points, [0, 255, 0]  unless @colour_points;
  
  return \@colour_points;
}

sub _colour {
  my ($self, $val, $cps) = @_;
  my $divisions = @$cps - 1;
  
  return $cps->[0]  unless $divisions;
  return $cps->[0]  if $val <= 0;
  return $cps->[-1] if $val >= 1;
  
  my $division = int($val * $divisions);
  my $o = ($val * $divisions) - $division;
  
  return [ map { $cps->[$division][$_]*(1-$o) + $cps->[$division+1][$_] * $o } (0..2) ];
}

sub composite_gradient {
  my ($self, $g, $f_ref, $st) = @_;
  
  return if $g->{'extent_end'} <= 0;

  my $cp = $self->_colour_points($st);

  my $l     = $self->{'seq_len'};
  my $min   = $st->{'min'};
  my $range = $st->{'max'}-$min;
  my $y     = $g->{'y'} + ($self->{'h'} - $st->{'height'})/2;

  $self->unshift($self->Rect({
    'x'         => $g->{'extent_start'} - 1,
    'width'     => $g->{'extent_end'} - $g->{'extent_start'} + 1,
    'height'    => $st->{'height'},
    'colour'    => '#f8f8f8',
    'absolutey' => 1,
    'dotted'    => 1,
    'y'         => $y
  }));
  
  foreach my $f (sort { $a->start <=> $b->start } @$f_ref) {
    my ($s, $e) = ($f->start, $f->end);
    
    next if $e < 1;
    last if $s > $l;
    
    $s = 1 if $s < 1;
    $e = $l if $e >$l;
    
    my $c = $self->{'config'}->colourmap->hex_by_rgb($self->_colour(($f->score - $min)/$range, $cp));
    
    $self->push($self->Rect({
      'height'    => $st->{'height'},
      'x'         => $s - 1,
      'width'     => $e - $s + 1,
      'y'         => $y,
      'colour'    => $c,
      'absolutey' => 1
    }));
  }
  
  return ();
}

sub composite_extent_lineplot {
  my ($self, $g, $st) = @_;
  return $self->composite_extent_histogram($g, $st);
}

sub composite_lineplot {
  my ($self, $g, $f_ref, $st) = @_;
  
  return if $g->{'extent_end'} <= 0;
  
  my $cp      = $self->_colour_points($st);
  my $strand  = $self->strand;
  my $l       = $self->{'seq_len'};
  my $min     = $st->{'min'};
  my $max     = $st->{'max'};
  my $range   = $max - $min;
  my $y       = $g->{'y'} + ($self->{'h'} - $st->{'height'})/2;
  my $sf      = $st->{'height'};
  my @q       = @$f_ref;
  my $t       = shift @q;
  my $start_x = ($t->start + $t->end - 1)/2;
  my $start_y = ($t->score - $min)/$range;
  
  $self->push($self->Line({
    'x'         => $g->{'extent_start'} - 1,
    'width'     => $g->{'extent_end'} - $g->{'extent_start'} + 1,
    'height'    => 0,
    'colour'    => 'red',
    'absolutey' => 1,
    'dotted'    => 1,
    'y'         => $y + ( $strand>0 ? -$min : $range + $min ) *$sf/$range
  })) if $min <= 0 && $max >= 0;

  $self->push($self->Line({
    'x'         => $g->{'extent_start'} - 1,
    'width'     => 0,
    'height'    => $st->{'height'},
    'colour'    => 'red',
    'absolutey' => 1,
    'dotted'    => 1,
    'y'         => $y
  }));
  
  $self->unshift($self->Rect({
    'x'         => $g->{'extent_start'} - 1,
    'width'     => $g->{'extent_end'} - $g->{'extent_start'} + 1,
    'height'    => $st->{'height'},
    'colour'    => '#f8f8f8',
    'absolutey' => 1,
    'dotted'    => 1,
    'y'         => $y
  }));

  foreach my $f (@$f_ref) {
    my $end_x = ($f->start + $f->end - 1)/2;
    my $end_y = ($f->score - $min)/$range;

    next if $end_x < 0;
    last if $start_x >= $l;
    
    my $co = $self->{'config'}->colourmap->hex_by_rgb($self->_colour(($end_y + $start_y)/2, $cp));
    my ($a, $b, $c, $d) = ($start_x, $start_y, $end_x, $end_y);
    
    if ($a < 0) {
      $b -= - $a * ($d - $b) / ($c - $a);
      $a  = 0;
    }
    
    if ($d > $l) {
      $d = $b + ($l - $a) * ($d - $b) / ($c - $a);
      $c = $l;
    } 
    
    unless ($start_y < 0 && $end_y < 0 || $start_y > 1 && $end_y > 1) {
      if ($b < 0) {
        $a += (-$b) * ($c - $a);
        $b  = 0;
      } elsif ($b > 1) {
        $a += ($b - 1) * ($c - $a);
        $b  = 1;
      }
      
      if($d < 0) {
        $c += $d * ($c - $a);
        $d  = 0;
      } elsif ($d > 1) {
        $c -= ($d - 1) * ($c - $a);
        $d  = 1;
      }
      
      $self->push($self->Line({
        'x'        => $a,
        'width'    => $c - $a,
        'y'        => $y + ($strand > 0 ? $b * $sf : $st->{'height'} - $b*$sf),
        'height'   => $strand * ($d - $b) * $sf,
        'colour'   => $co,
        'absolute' => 1
      }));
    }
    
    $start_x = $end_x;
    $start_y = $end_y;
  }
  
  return ();
}

sub composite_extent_tiling {
  my ($self, $g, $st) = @_;
  return $self->composite_extent_histogram($g, $st);
}

sub composite_tiling {
  my ($self, $g, $f_ref, $st) = @_;
  return $self->composite_histogram($g, $f_ref, $st);
}

#----------------------------------------------------------------------#
# Some helper functions for the renderer..                             #
#----------------------------------------------------------------------#
# _extent    - computes the extent of a glyph - and ats it to its      #
#              parent's extent if there is one...                      #
# _symbol_bg - draws the background box behind a feature! not          #
#              really part of the specification - but a nice to have!  #
#----------------------------------------------------------------------#

sub _extent {
  my ($self, $g, $f, $s, $e, $h) = @_;
  
  my $l = $self->{'seq_len'};

  # If we have a group
  if ($e < 1 || $s > $l) {
    return unless $g;
    
    $g->{'extent_start'} = 1   if $s < 1;  # Always change start extent if glyph to the left of the region
    $g->{'extent_end'}   = $l  if $e > $l; # Always change end   extent if glyph to the right of the region
    
    return;
  }
  
  $f->{'extent_start'} = $s < 1                  ? 1                  : $s;
  $f->{'extent_end'}   = $e > $self->{'seq_len'} ? $self->{'seq_len'} : $e;
  $self->{'h'}         = $h if $h > $self->{'h'};
  
  return unless $g;
  
  # Now let us modify the containing group
  $g->{'extent_start'} = $f->{'extent_start'} if !defined $g->{'extent_start'} || $f->{'extent_start'} < $g->{'extent_start'};
  $g->{'extent_end'}   = $f->{'extent_end'}   if !defined $g->{'extent_end'}   || $f->{'extent_end'}   > $g->{'extent_end'};
  $g->{'height'}       = $h                   if !defined $g->{'height'}       || $h                   > $g->{'height'};
}

sub _symbol_bg {
  my ($self, $g, $f, $s_g, $e_g, $st) = @_;
  
  my $h = $st->{'height'} || $self->{'h'};
  my $y = ($g ? $g->{'y'} : $f->{'y'}) + ($self->{'h'} - $h) /2;

  my $s = $f->start; 
     $s = $s_g if $s_g < $s;
     
  my $e = $f->end;
     $e = $e_g if $e_g > $e;
     
  my $l = $self->{'seq_len'};
  
  return if $e < 1 || $s > $l;
  
  $e = $l if $e > $l;
  $s = 1  if $s < 1;
  
  $self->push($self->Rect({
    'x'         => $s - 1,
    'width'     => $e - $s + 1,
    'y'         => $y,
    'height'    => $h,
    'absolutey' => 1,
    'colour'    => $st->{'bgcolor'}
  }));
}

sub _symbol_init {
  my ($self, $g, $f, $st) = @_;
  
  my $mp = ($f->start + $f->end - 1)/2;
  
  if ($mp < 0 || $mp > $self->{'seq_len'}) {
    $self->_symbol_bg($g, $f, $f->start, $f->end, $st) if $st->{'bgcolor'} && $st->{'bgcolor'} ne $st->{'fgcolor'};
    return;
  }
  
  my $h = $st->{'height'} || $self->{'h'};
  my $y = ($g ? $g->{'y'} : $f->{'y'}) + ($self->{'h'} - $h)/2;
  my $w = ($st->{'linewidth'} || $h) * $self->{'bppp'};
  
  $self->_symbol_bg($g, $f, $f->start, $f->end, $st) if $st->{'bgcolor'} && $st->{'bgcolor'} ne $st->{'fgcolor'};
  
  return ($mp, $h, $y, $w);
}

#----------------------------------------------------------------------#
# glyph renderers - work on individual elements from the specification #
# foreach glyph type there are up to two functions -                   #
# extent_{glyph_type} - computes the extent of the glyph from the      #
#                       feature and the glyph type                     #
# glyph_{glyph_type} - the actual code to render the particular glyph  #
#                      types                                           #
#----------------------------------------------------------------------#

#----------------------------------------------------------------------#
# Anchored Arrow <---| or |--->                                        #
# Haven't implemented parallel=no can't work out whether it is useful  #
# will do so after implementing the vertical arrows...                 #
#----------------------------------------------------------------------#

sub extent_anchored_arrow {
  my ($self, $g, $f, $st) = @_;

  # Not an arrow at all
  if ($st->{'northeast'} eq 'no' && $st->{'southwest'} eq 'no' ) {
    return $self->extent_line($g, $f, $st);
  }
  
  # Vertical arrow! get the width - if the midpoint is in the region then make space for the arrow
  if ($st->{'parallel'} eq 'no') {
    my $h = $st->{'height'} || $self->{'h'};
    my $w = ($st->{'linewidth'} || $h)*$self->{'bppp'}/2;
    my $mp = ($f->start + $f->end - 1)/2;
    
    if ($mp >= 0 || $mp <= $self->{'seq_len'}) {
      return $self->_extent($g, $f, $mp-$w, $mp+$w, $st->{'height'});
    }
  }
  
  return $self->extent_box($g, $f, $st);
}

sub glyph_anchored_arrow {
  my ($self, $g, $f, $st) = @_;
  my ($s, $e, $o) = ($f->start, $f->end, $f->strand);
  my ($mp, $h, $y, $w) = $self->_symbol_init($g, $f, $st);
  my $tw = $h * $self->{'bppp'}/2;
  my $l = $self->{'seq_len'};
  
  # If the width of the glyph is less than the width of the arrow section we draw it slightly differently
  if ($st->{'parallel'} eq 'no') { # This is now like one of the X glyphs
  
    return if $mp < 0 || $mp > $l; # Don't draw upwards arrow if mid point out of region
    
    my $lw = $st->{'linewidth'} || $h;
    $w = $lw * $self->{'bppp'};
    
    my $ah = $h < $lw ? $h/2 : $lw/2;
    my $top = $y + $h;
    my $bottom = $y;
    my $bar = 0;
    
    # Forward strand or unstranded features are drawn as "up" arrows
    if ($f->strand >= 0) {
      $self->push($self->Poly({
        'points'       => [ $mp-$w/2, $bottom+$ah, $mp, $bottom, $mp+$w/2, $bottom+$ah ],
        'absolutey'    => 1,
        'colour'       => $st->{'fgcolor'},
        'bordercolour' => $st->{'fgcolor'}
      }));
      
      $bottom += $ah;
      $bar     = $top;
    }
    # Reverse strand features are drawn as "down" arrows
    else {
      $self->push($self->Poly({
        'points'       => [ $mp-$w/2, $top-$ah, $mp, $top, $mp+$w/2, $top-$ah ],
        'absolutey'    => 1,
        'colour'       => $st->{'fgcolor'},
        'bordercolour' => $st->{'fgcolor'}
      }));
      
      $top -= $ah;
      $bar  = $bottom;
    }
    
    my $w2 = int($w/$self->{'bppp'}/4) * $self->{'bppp'};
    
    $self->push($self->Rect({
      'x'         => $mp - $w2,
      'width'     => $w2 * 2,
      'y'         => $bottom,
      'height'    => $top - $bottom,
      'absolutey' => 1,
      'colour'    => $st->{'fgcolor'}
    }));
    
    $self->push($self->Line({
      'x'         => $mp - $w/2,
      'width'     => $w,
      'y'         => $bar,
      'height'    => 0,
      'absolutey' => 1,
      'colour'    => $st->{'fgcolor'}
    }));
    
    return;
  }
  
  # This is a small arrow
  if ($e - $s + 1 < $tw) {
    $s = $f->{'extent_start'};
    $e = $f->{'extent_end'};
    
    $self->push($self->Poly({
      'colour'    => $st->{'fgcolor'},
      'absolutey' => 1,
      'points'    => [ 
        $o > 0 ? $s-1 : $e, 
        $y,
        $o > 0 ? $e : $s-1,
        $y + $h/2,
        $o > 0 ? $s-1: $e,
        $y+$h 
      ]
    }));
    
    return;
  }
  
  # Otherwise we draw the arrow in three parts...
  # Firstly the arrow head - if we are going to draw it
  $h  = $st->{'height'} || $self->{'h'};
  $y  = ($g ? $g->{'y'} : $f->{'y'}) + ($self->{'h'} - $h) /2;
  $tw = $h * $self->{'bppp'}/2;
  
  if ($o > 0 && $e == $f->{'extent_end'} || $o <= 0 && $s == $f->{'extent_start'}) {
    $self->push($self->Poly({
      'colour'    => $st->{'fgcolor'},
      'absolutey' => 1,
      'points'    => [
        $o > 0 ? $e-$tw : $s-1+$tw,
        $y,
        $o > 0 ? $e : $s-1,
        $y + $h/2,
        $o > 0 ? $e-$tw : $s-1+$tw,
        $y+$h 
      ]
    }));
  } else {
    # Reset the width of the triangle as we don't have the triangle to the left/right
    $tw = 0;
  }
  
  # Now draw the main bar
  my $bar_style = lc ( $st->{'bar_style'} || 'indent' );
  if ($bar_style eq 'line') {
    $self->push($self->Line({
      'x'         => $o > 0 ? $f->{'extent_start'} - 1 : $f->{'extent_start'} + $tw - 1,
      'width'     => $f->{'extent_end'} - $f->{'extent_start'} + 1 - $tw,
      'height'    => 0,
      'absolutey' => 1,
      'colour'    => $st->{'fgcolor'},
      'dotted'    => ($st->{'style'} eq 'dashed') ? 1 : 0,
      'y'         => $y + $h/2
    }));
  } else {
    my $n = $bar_style eq 'full' ? 0 : int($h/4);
    
    $self->push($self->Rect({
      'x'         => $o > 0 ? $f->{'extent_start'} - 1 : $f->{'extent_start'} + $tw - 1,
      'width'     => $f->{'extent_end'} - $f->{'extent_start'} + 1 - $tw,
      'height'    => $h - 2*$n,
      'absolutey' => 1,
      'colour'    => $st->{'fgcolor'},
      'y'         => $y + $n
    }));
  }
  
  # Draw the back if we haven't missed it out
  if ($o <= 0 && $e == $f->{'extent_end'} || $o > 0 && $s == $f->{'extent_start'}) {
    $self->push($self->Line({
      'x'         => $o > 0 ? $s - 1 : $e,
      'width'     => 0,
      'height'    => $h,
      'absolutey' => 1,
      'colour'    => $st->{'fgcolor'},
      'y'         => $y
    }));
  }
}

#----------------------------------------------------------------------#
# Arrow <-> --> <-- or the same vertically!                            #
#----------------------------------------------------------------------#
# Currently to do.....                                                 #
#----------------------------------------------------------------------#

sub extent_arrow {
  my ($self, $g, $f, $st) = @_;

   # Not an arrow at all
  if ($st->{'northeast'} eq 'no' && $st->{'southwest'} eq 'no') {
    return $self->extent_line($g, $f, $st);
  }
  
  # Vertical arrow. Get the width - if the midpoint is in the region then make space for the arrow
  if ($st->{'parallel'} eq 'no') {
    my $h = $st->{'height'} || $self->{'h'};
    my $w = ($st->{'linewidth'} || (2*$h/3)) * $self->{'bppp'}/2;
    my $mp = ($f->start + $f->end - 1)/2;
    
    if ($mp >= 0 || $mp <= $self->{'seq_len'}) {
      return $self->_extent($g, $f, $mp-$w, $mp+$w, $st->{'height'});
    }
  }
  
  return $self->extent_box($g, $f, $st);
}

sub glyph_arrow {
  my ($self, $g, $f, $st) = @_;
  
  # Not an arrow at all
  if ($st->{'northeast'} eq 'no' && $st->{'southwest'} eq 'no') {
    return $self->glyph_line($g, $f, $st);
  }
  
  my $s = $f->start;
  my $e = $f->end;
  
  my ($mp, $h, $y, $w) = $self->_symbol_init($g, $f, $st);
  my $l = $self->{'seq_len'};

   # This is now like one of the X glyphs
  if ($st->{'parallel'} eq 'no') {
    return if $mp < 0 || $mp > $l; # Don't draw upwards arrow if mid point out of region
   
    my $ah = int($h/3 < $st->{'linewidth'}/2 ? $st->{'linewidth'}/2 : $h/3);
    my $top = $y + $h;
    my $bottom = $y;
    
    my $lw = $st->{'linewidth'} || (2*$h/3);
    $w = int($lw/2) * 2 * $self->{'bppp'};

    # Draw the south-pointing arrowhead, unless the stylesheet says not to
    if ($st->{'southwest'} ne 'no') {
      $self->push($self->Poly({
        'points'       => [ $mp-$w/2, $top-$ah, $mp, $top, $mp+$w/2, $top-$ah ],
        'absolutey'    => 1,
        'colour'       => $st->{'fgcolor'},
        'bordercolour' => $st->{'fgcolor'}
      }));
      
      $top -= $ah;
    } 

    # Draw the north-pointing arrowhead, unless the stylesheet says not to
    if ($st->{'northeast'} ne 'no') {
      $self->push($self->Poly({
        'points'       => [ $mp-$w/2, $bottom+$ah, $mp, $bottom, $mp+$w/2, $bottom+$ah ],
        'absolutey'    => 1,
        'colour'       => $st->{'fgcolor'},
        'bordercolour' => $st->{'fgcolor'}
      }));
      
      $bottom += $ah;
    }
    
    my $w2 = int($w/$self->{'bppp'}/4) * $self->{'bppp'};
    
    $self->push($self->Rect({
      'x'         => $mp - $w2,
      'width'     => $w2 * 2,
      'y'         => $bottom,
      'height'    => $top - $bottom,
      'absolutey' => 1,
      'colour'    => $st->{'fgcolor'}
    }));
    return;
  }
  
  # More like a span glyph...
  my $ends = ($st->{'northeast'} eq 'no' || $st->{'southwest'} eq 'no') ? 1 : 2;
  
  # We have room to draw all bits
  if ($f->{'extent_end'} - $f->{'extent_start'} + 1 > $ends * $h * $self->{'bppp'}/2 ) {
    my $h = $st->{'height'} || $self->{'h'};
    my $y = ($g ? $g->{'y'} : $f->{'y'}) + ($self->{'h'} - $h) /2;
    my $box_s = $f->{'extent_start'};
    my $box_e = $f->{'extent_end'};
    my $aw = $h * $self->{'bppp'}/2;
    
    if ($f->{'extent_start'} == $f->start && $st->{'southwest'} ne 'no') {
      $self->push($self->Poly({
        'colour'       => $st->{'fgcolor'},
        'bordercolour' => $st->{'fgcolor'},
        'absolutey'    => 1,
        'points'       => [ $box_s-1, $y+$h/2, $box_s-1+$aw, $y, $box_s-1+$aw, $y+$h ]
      }));
      
      $box_s += $aw;
    }
    
    if ($f->{'extent_end'} == $f->end && $st->{'northeast'} ne 'no') {
      $self->push($self->Poly({
        'colour'       => $st->{fgcolor},
        'bordercolour' => $st->{fgcolor},
        'absolutey'    => 1,
        'points'       => [ $box_e, $y+$h/2, $box_e-$aw, $y+$h, $box_e-$aw, $y ]
      }));
      
      $box_e -= $aw;
    }
    
    $self->push($self->Space({
      'x'      => $box_s - 1,
      'width'  => $box_e - $box_s + 1,
      'y'      => $y,
      'height' => $h
    }));
    
    my $bar_style = lc ( $st->{'bar_style'} || 'line' );
    if ($bar_style eq 'full' || $bar_style eq 'indent') {
      my $n = $bar_style eq 'full' ? 0 : int($h/4);
      
      $self->push($self->Rect({
        'x'         => $box_s - 1,
        'width'     => $box_e - $box_s + 1,
        'height'    => $h - 2*$n,
        'absolutey' => 1,
        'colour'    => $st->{'fgcolor'},
        'y'         => $y + $n
      }));
    } else {
      $self->push($self->Line({
        'dotted'    => ($st->{'style'} eq 'dashed') ? 1 : 0,
        'x'         => $box_s - 1,
        'width'     => $box_e - $box_s + 1,
        'y'         => $y + $h/2,
        'height'    => 0,
        'colour'    => $st->{'fgcolor'},
        'absolutey' => 1
      }));
    }
    
    return;
  }
  
  # This is a narrow featured arrow
  $s = $f->{'extent_start'};
  $e = $f->{'extent_end'};
  
  if ($mp > $l || $st->{'northeast'} eq 'no') {
    # This is a right-left arrow
    $self->push($self->Poly({
      'colour'       => $st->{'fgcolor'},
      'bordercolour' => $st->{'fgcolor'},
      'absolutey'    => 1,
      'points'       => [ $s, $y+$h/2, $e, $y+$h, $e, $y ]
    }));
  } elsif ($mp < 0 || $st->{'southwest'} eq 'no') {
    # This is a left-right arrow
    $self->push($self->Poly({
      'colour' => $st->{fgcolor},
      'bordercolour' => $st->{fgcolor},
      'absolutey' => 1,
      'points' => [ $s,$y,$s,$y+$h,$e,$y+$h/2 ]
    }));
  } else {
    # This is a double-ended arrow
    $self->push($self->Poly({
      'colour'       => $st->{'fgcolor'},
      'bordercolour' => $st->{'fgcolor'},
      'absolutey'    => 1,
      'points'       => [ $s, $y+$h/2, $mp ,$y+$h, $e, $y+$h/2, $mp, $y ]
    }));
  }
}

#----------------------------------------------------------------------#
# Box.....                                                             #
#----------------------------------------------------------------------#
# Probably the simplest of all the symbols - just a filled box!        #
#----------------------------------------------------------------------#

sub extent_box {
  my ($self, $g, $f, $st) = @_;
  my $s = $f->start;
  my $e = $f->end;
  my $w = $st->{'width'} * $self->{'bppp'};
  
  if ($e - $s + 1 < $w) {
    $s = ($e + $s - 1 - $w)/2;
    $e = $s + $w/2;
  }
  
  return $self->_extent($g, $f, $s, $e, $st->{'height'});
}

sub glyph_box {
  my ($self, $g, $f, $st) = @_;
  
  return () unless $f->{'extent_start'}; # Not in region
  
  my $h = $st->{'height'} || $self->{'h'};
  my $y = ($g ? $g->{'y'} : $f->{'y'}) + ($self->{'h'} - $h)/2;
  
  $self->push($self->Rect({
    'x'            => $f->{'extent_start'} - 1,
    'width'        => $f->{'extent_end'} - $f->{'extent_start'} + 1,
    'y'            => $y,
    'height'       => $h,
    'absolutey'    => 1,
    'bordercolour' => $st->{'fgcolor'} || $st->{'bgcolor'},
    $st->{'bgcolor'} ? ( 'colour'  => $st->{'bgcolor'} ) : (),
    $st->{'pattern'} ? ( 'patterncolour' => $st->{'fgcolor'}, 'pattern' => $st->{'pattern'} ) : ()
  }));
}

#----------------------------------------------------------------------#
# Cross/dot/ex.....                                                    #
#----------------------------------------------------------------------#

sub extent_cross {
  my ($self, $g, $f, $st) = @_;
  
  my ($s, $e) = ($f->start, $f->end);
  my $mp      = ($s + $e - 1)/2;
  
  # If the mid point isn't in the region we only draw the background if it has a colour
  if ($mp < 0 || $mp > $self->{'seq_len'}) {
    return $self->extent_box($g, $f, $st) if $st->{'bgcolor'}; 
    return;
  }
  
  my $w = ($st->{'linewidth'} || $st->{'height'} || $self->{'h'} || 12) * $self->{'bppp'};
  my $l = $mp - $w/2;
  my $r = $mp + $w/2;
  
  # We have it on box
  if ($st->{'bgcolor'}) {
    $l = $s-1 < $l ? $s-1 : $l;
    $r = $e   > $r ? $e   : $r;
  }
  
  $self->_extent($g, $f, $l, $r, $st->{'height'} || $self->{'h'});
}

sub extent_dot { my $self = shift; return $self->extent_cross(@_); }
sub extent_ex  { my $self = shift; return $self->extent_cross(@_); }

sub glyph_cross {
  my($self, $g, $f, $st)= @_;
  
  my ($mp, $h, $y, $w) = $self->_symbol_init($g, $f, $st);
  
  return unless $mp;
  
  $self->push($self->Line({
    'x'         => $mp,
    'width'     => 0,
    'y'         => $y,
    'height'    => $h,
    'absolutey' => 1,
    'colour'    => $st->{'fgcolor'}
  }));
  $self->push($self->Line({
    'x'         => $mp - $w/2,
    'width'     => $w,
    'y'         => ($g ? $g->{'y'} : $f->{'y'}) + $self->{'h'}/2,
    'height'    => 0,
    'absolutey' => 1,
    'colour'    => $st->{'fgcolor'}
  }));
}

sub glyph_dot {
  my ($self, $g, $f, $st) = @_;
  
  my ($mp, $h, $y, $w) = $self->_symbol_init($g, $f, $st);
  
  return unless $mp;

  $self->push($self->Ellipse({
    'x'         => $mp,
    'width'     => $w,
    'y'         => $y + $h/2,
    'height'    => $h,
    'filled'    => 1,
    'absolutey' => 1,
    'colour'    => $st->{'fgcolor'}
  }));
}

sub glyph_ex {
  my ($self, $g, $f, $st)= @_;
  my ($mp, $h, $y, $w) = $self->_symbol_init($g, $f, $st);
  
  return unless $mp;

  $self->push($self->Line({
    'x'         => $mp - $w/2,
    'width'     => $w,
    'y'         => $y,
    'height'    => $h,
    'absolutey' => 1,
    'colour'    => $st->{'fgcolor'}
  }));
  
  $self->push($self->Line({
    'x'         => $mp - $w/2,
    'width'     => $w,
    'y'         => $y + $h,
    'height'    => -$h,
    'absolutey' => 1,
    'colour'    => $st->{'fgcolor'}
  }));
}

sub extent_hidden {
  return;
}

sub glyph_hidden {
  return ();
}

sub extent_line {
  my($self, $g, $f, $st)= @_;
  
  if ($st->{'parallel'} ne 'no' || $st->{'bgcolor'}) {
    return $self->extent_box($g, $f, $st);
  } else {
    my $mp = ($f->start + $f->end - 1)/2;
    return $self->_extent($g, $f, $mp, $mp,$st->{'height'})
  }
}

sub glyph_line {
  my ($self, $g, $f, $st) = @_;
  
  $self->_symbol_bg($g, $f, $st) if $st->{'bgcolor'} && $st->{'bgcolor'} ne $st->{'fgcolor'};
  
  if ($st->{'parallel'} eq 'no') {
    my $h = $st->{'height'} || $self->{'h'};
    my $y = ($g ? $g->{'y'} : $f->{'y'}) + ($self->{'h'} - $h) /2;
    my $mp = ($f->start + $f->end - 1)/2;
    
    if ($mp > 0 && $mp < $self->{'seq_len'}) {
      $self->push($self->Line({
        'x'         => $mp,
        'y'         => $y,
        'height'    => $h,
        'colour'    => $st->{'fgcolor'},
        'width'     => 0,
        'dotted'    => ($st->{'style'} eq 'dashed') ? 1 : 0,
        'absolutey' => 1
      }));
    }
    
    return;
  }
  
  if ($st->{'style'} eq 'hat' || $st->{'style'} eq 'intron') {
    my $h = $st->{'height'} || $self->{'h'};
    my $y = ($g ? $g->{'y'} : $f->{'y'}) + ($self->{'h'} - $h)/2;
    
    $self->push($self->Intron({
      'x'         => $f->{'extent_start'} - 1,
      'y'         => $y,
      'height'    => $h,
      'strand'    => $f->{'strand'},
      'colour'    => $st->{'fgcolor'},
      'width'     => $f->{'extent_end'} - $f->{'extent_start'} + 1,
      'dotted'    => 0,
      'absolutey' => 1
    }));
  } else {
    # style is either dashed or solid
    my $y = ($g ? $g->{'y'} : $f->{'y'}) + $self->{'h'}/2;
    
    $self->push($self->Line({
      'x'         => $f->{'extent_start'} - 1,
      'y'         => $y,
      'height'    => 0,
      'colour'    => $st->{'fgcolor'},
      'width'     => $f->{'extent_end'} - $f->{'extent_start'} + 1,
      'dotted'    => ($st->{'style'} eq 'dashed') ? 1 : 0,
      'absolutey' => 1
    }));
  }
}

# sub extent_primers - drop to default
sub glyph_primers {
  my ($self, $g, $f, $st) = @_;
  
  my $s = $f->start;
  my $e = $f->end;
  my $o = $f->strand;
  my $h = $st->{'height'} || $self->{'h'};
  
  my $y = ($g ? $g->{'y'} : $f->{'y'}) + ($self->{'h'} - $h)/2;
  my $tw = $h * $self->{'bppp'}/2;

  # Draw the spanning line
  $self->push($self->Line({
    'x'         => $f->{'extent_start'} - 1,
    'y'         => $y + $h/2,
    'height'    => 0,
    'colour'    => $st->{'bgcolor'},
    'width'     => $f->{'extent_end'} - $f->{'extent_start'} + 1,
    'dotted'    => ($st->{'style'} eq 'dashed') ? 1 : 0,
    'absolutey' => 1
  }));
  
  $tw = ($e - $s + 1)/2 if $e - $s + 1 < 2*$tw;
  
  if ($s == $f->{'extent_start'}){
    $self->push( $self->Poly({
      'points'    => [ $s-1, $y, $s-1+$tw, $y+$h/2, $s-1, $y+$h ],
      'colour'    => $st->{'fgcolor'},
      'absolutey' => 1,
    }));
  }
  
  if ($e == $f->{'extent_end'}){
    $self->push( $self->Poly({
      'points'    => [ $e, $y, $e-$tw, $y+$h/2, $e, $y+$h ],
      'colour'    => $st->{'fgcolor'},
      'absolutey' => 1,
    }));
  }  
}

# sub extent_span - drop to default
sub glyph_span {
  my ($self, $g, $f, $st) = @_;
  my $h = $st->{'height'} || $self->{'h'};
  my $y = ($g ? $g->{'y'} : $f->{'y'}) + ($self->{'h'} - $h)/2;
  
  if ($f->start == $f->{'extent_start'}) {
    # Draw left hand end
    $self->push($self->Line({
      'x'         => $f->start - 1,
      'y'         => $y,
      'height'    => $h,
      'colour'    => $st->{'fgcolor'},
      'width'     => 0,
      'absolutey' => 1
    }));
  }
  
  if ($f->end == $f->{'extent_end'}) {
    # Draw left hand end
    $self->push($self->Line({
      'x'         => $f->end,
      'y'         => $y,
      'height'    => $h,
      'colour'    => $st->{'fgcolor'},
      'width'     => 0,
      'absolutey' => 1
    }));
  }
  
  my $bar_style = lc ( $st->{'bar_style'} || 'line' );
  if ($bar_style eq 'full' || $bar_style eq 'indent') {
    my $n = $bar_style eq 'full' ? 0 : int($h/4);
    
    $self->push($self->Rect({
      'x'         => $f->{'extent_start'} - 1,
      'width'     => $f->{'extent_end'} - $f->{'extent_start'} + 1,
      'height'    => $h - 2*$n,
      'absolutey' => 1,
      'colour'    => $st->{'fgcolor'},
      'y'         => $y + $n
    }));
  } else {
    $self->push($self->Line({
      'x'         => $f->{'extent_start'} - 1,
      'width'     => $f->{'extent_end'} - $f->{'extent_start'} + 1,
      'y'         => $y + $h/2,
      'height'    => 0,
      'colour'    => $st->{'fgcolor'},
      'dotted'    => ($st->{'style'} eq 'dashed') ? 1 : 0,
      'absolutey' => 1
    }));
  }
}

sub extent_text {
  my ($self, $g, $f, $st) = @_;
  my $h   = $st->{'height'} || $self->{'h'};
  my $fh  = $st->{'fontsize'} || ($h*0.6); # Fit inside box
  my $fn  = $st->{'font'} || 'arial';
  my $str = $st->{'string'};
  my $l   = $self->{'seq_len'};
  
  my ($t, $flag, $tw, $th) = $self->get_text_width(0, $str, '', 'font' => $fn, 'ptsize' => $fh);

  my $bp_tw = $tw * $self->{'bppp'};
  $h ||= $th; # Make sure the box has a big enough height
  my ($s, $e) = ($f->start,$f->end);
  my $mp = ($s + $e - 1)/2;
  $s = 1 if $s < 1;
  $e = $l if $e > $l; 

  # Can we fit the text in the box? If so we will draw it centred to the mid-point as much as possible
  if ($bp_tw < $e - $s + 1) {
    # If not if we centre the text on the midpoint - will it fit in the range - if so draw it at the midpoint and
    my $ts = $mp - $bp_tw/2;
    $ts = 1 if $ts < 1;
    $ts = $l - $bp_tw if $ts > $l - $bp_tw;
    
    $f->{'tinfo'} = { 'ts' => $ts, 'tw' => $tw, 'bp_tw' => $bp_tw, 'th' => $th, 'fs' => $fh, 'fn' => $fn, 'st' => $str, 'extra' => 'ff' };
    
    return $st->{'bgcolor'} ? $self->_extent($g, $f, $f->start, $f->end, $h) : $self->_extent($g, $f, $ts, $ts+$bp_tw, $h);
  } elsif ($mp < 0 || $mp > $l) { # Out of range don't draw
    # If midpoint not in range don't draw the text at all - and just make space for the box if a background colour is set
    return $self->_extent($g, $f, $f->start, $f->end, $h) if $st->{'bgcolor'};
  } else {
    my $ts = $mp - $bp_tw/2;
    
    if ($ts < - 4 * $self->{'bppp'} || $ts + $bp_tw > $l + 4 * $self->{'bppp'}) {
      return $self->_extent($g, $f, $f->start, $f->end, $h) if $st->{'bgcolor'};
    } else {
      $f->{'tinfo'} = { 'ts' => $ts, 'tw' => $tw, 'bp_tw' => $bp_tw, 'th' => $th, 'fs' => $fh, 'fn' => $fn, 'st' => $str, 'extra' => 'pf' };
      return $self->_extent($g, $f, $ts, $ts+$bp_tw, $h);
    }
  }
}

sub glyph_text {
  my ($self, $g, $f, $st) = @_;
  
  if ($st->{'bgcolor'}) {
    $self->_symbol_init($g, $f, $st);
  }
  
  # We are drawing text between ts and ts+tw (height = th);
  if ($f->{'tinfo'}) {
    my $h = $st->{'height'} || $self->{'h'};
    my $y = ($g ? $g->{'y'} : $f->{'y'}) + ($self->{'h'} - $h)/2;
    
    $self->push($self->Text({
      'text'      => $st->{'string'},
      'valign'    => 'center',
      'textwidth' => $f->{'tinfo'}{'tw'},
      'x'         => $f->{'tinfo'}{'ts'},
      'width'     => $f->{'tinfo'}{'bp_tw'},
      'halign'    => 'center',
      'y'         => $y,
      'colour'    => $st->{'fgcolor'},
      'font'      => $f->{'tinfo'}{'fn'},
      'ptsize'    => $f->{'tinfo'}{'fs'},
      'height'    => $h,
      'absolutey' => 1
    }));
  }
}

# sub extent_toomany - drop to default
sub glyph_toomany {
  my ($self, $g, $f, $st) = @_;
  
  return () unless $f->{'extent_start'}; # Not in region
  
  my $h = $st->{'height'} || $self->{'h'};
  my $y = ($g ? $g->{'y'} : $f->{'y'}) + ($self->{'h'} - $h) /2;

  $self->push($self->Rect({
    'x'            => $f->{'extent_start'} - 1,
    'width'        => $f->{'extent_end'} - $f->{'extent_start'} + 1,
    'y'            => $y,
    'height'       => $h,
    'absolutey'    => 1,
    $st->{'bgcolor'} ? ( 'colour'       => $st->{'bgcolor'} ) : (),
    $st->{'fgcolor'} ? ( 'bordercolour' => $st->{'fgcolor'} ) : ()
  }));
  
  for (my $y1 = $y; $y1 < $y + $h; $y1 += 2) {
    $self->push($self->Rect({
      'x'         => $f->{'extent_start'} - 1,
      'width'     => $f->{'extent_end'} - $f->{'extent_start'} + 1,
      'y'         => $y1,
      'height'    => 0,
      'absolutey' => 1,
      $st->{'fgcolor'} ? ( 'colour' => $st->{'fgcolor'} ) : ()
    }));
  }
}

sub extent_triangle { my $self = shift; return $self->extent_cross(@_); }

sub glyph_triangle {
  my ($self, $g, $f, $st) = @_;
  my ($mp, $h, $y, $w) = $self->_symbol_init($g, $f, $st);
  
  return unless $mp;

  my $direction = lc($st->{'direction'});
  my ($t, $m, $b) = ($y, $y + $h/2, $y + $h);

  my $points = $direction eq 's' ? [ $mp - $w/2, $t, $mp,        $b, $mp + $w/2, $t ]  #v
             : $direction eq 'w' ? [ $mp - $w/2, $m, $mp + $w/2, $t, $mp + $w/2, $b ]  #<
             : $direction eq 'e' ? [ $mp - $w/2, $b, $mp - $w/2, $t, $mp + $w/2, $m ]  #>
             :                     [ $mp - $w/2, $b, $mp,        $t, $mp + $w/2, $b ]; #^

  $self->push($self->Poly({
    'points'    => $points,
    'colour'    => $st->{'fgcolor'},
    'absolutey' => 1,
  }));
}

1;
