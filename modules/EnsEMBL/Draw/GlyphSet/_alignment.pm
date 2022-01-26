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

package EnsEMBL::Draw::GlyphSet::_alignment;

### Parent class used by various tracks that show features as simple
### coloured blocks (including histograms)

use strict;

use List::Util qw(min max);
use POSIX qw(floor ceil);

use base qw(EnsEMBL::Draw::GlyphSet_wiggle_and_block EnsEMBL::Draw::GlyphSet::_difference);

sub wiggle_subtitle {}

#==============================================================================
# The following functions can be overridden if the class does require
# something different - main one to be overridden is probably the
# features call, as it will need to take different parameters...
#==============================================================================

sub feature_group {
  my ($self, $f) = @_;
  (my $name = $f->hseqname) =~ s/(\..*|T7|SP6)$//; # this regexp will remove the differences in names between the ends of BACs/FOSmids.
  return $name;
}

sub feature_label { return $_[1]->hseqname; }

sub feature_title {
  my ($self, $f, $db_name) = @_;
  $db_name ||= 'External Feature';
  return "$db_name " . $f->hseqname;
}

sub features {
  my $self         = shift;
  my $method       = 'get_all_' . ($self->my_config('object_type') || 'DnaAlignFeature') . 's';
  my $db           = $self->my_config('db');
  my @logic_names  = @{$self->my_config('logic_names') || []};
  my $strand_shown = $self->my_config('show_strands');
  my @results      = map { $self->{'container'}->$method($_, undef, $db) || () } @logic_names;
  
  # force all features to be on one strand if the config requests it
  if ($strand_shown) {
    $_->strand($strand_shown) for map @$_, @results;
  }
  
  return ($self->my_config('name') => [ @results ]);
}

sub href {
  ### Links to /Location/Genome
  
  my ($self, $f) = @_;
  my $ln     = $f->can('analysis') ? $f->analysis->logic_name : '';
  my $id     = $f->display_id;
     $id     = $f->dbID if $ln eq 'alt_seq_mapping';

  return $self->_url({
    species => $self->species,
    action  => $self->my_config('zmenu') ? $self->my_config('zmenu') : 'Genome',
    ftype   => $self->my_config('object_type') || 'DnaAlignFeature',
    db      => $self->my_config('db'),
    r       => $f->seq_region_name . ':' . $f->seq_region_start . '-' . $f->seq_region_end,
    id      => $id,
    ln      => $ln,
  });
}

sub colour_key { return $_[0]->my_config('colour_key') || $_[0]->my_config('sub_type'); }

#==============================================================================
# Next we have the _init function which chooses how to render the
# features...
#==============================================================================

sub render_unlimited          { $_[0]->render_as_alignment_nolabel({'height' => 1, 'depth' => 1000});       }
sub render_stack              { $_[0]->render_as_alignment_nolabel({'height' => 1, 'depth' => 40});         }
sub render_simple             { $_[0]->render_as_alignment_nolabel;                                         }
sub render_half_height        { $_[0]->render_as_alignment_nolabel({
                                                            'height' => $_[0]->my_config('height') / 2 || 4, 
                                                            'depth'   => 20
                                                            });                                             }
sub render_as_alignment_label { $_[0]->{'show_labels'} = 1; $_[0]->render_as_alignment_nolabel;             }
sub render_ungrouped_labels   { $_[0]->{'show_labels'} = 1; $_[0]->render_ungrouped;                        }

sub render_as_transcript_nolabel {$_[0]->render_as_alignment_nolabel({'structure' => 1});                   }
sub render_as_transcript_label   {$_[0]->{'show_labels'} = 1; 
                                              $_[0]->render_as_alignment_nolabel({'structure' => 1});       }

## Backwards compatibility
sub render_normal { $_[0]->render_as_alignment_nolabel($_[1]); }
sub render_labels { $_[0]->render_as_alignment_label($_[1]); }

# variable height renderer
sub render_histogram {
  my $self     = shift;
  my $strand   = $self->strand;
  my %features = $self->features;
  
  $self->{'max_score'} = $self->my_config('hist_max_height') || 50; # defines scaling factor, plus any feature with a score >= this shown at max height (set to 50 for rna-seq but can be configured via web-data)
  $self->{'height'}    = 30;                                        # overall track height
  
  foreach my $feature_key (keys %features) {
    my $colour_key             = $self->colour_key($feature_key);
    my $feature_colour         = $self->my_colour($colour_key);
    my $non_can_feature_colour = $self->my_colour("${colour_key}_non_can") || '';
    my $join_colour            = $self->my_colour($colour_key, 'join');
    my $feats                  = $features{$feature_key};
    my ($sorted_feats, $sorted_can_feats, $sorted_non_can_feats, $hrefs) = ([], [], [], {});
    
    foreach my $f ( map $_->[1], sort { $a->[0] <=> $b->[0] } map [ $_->start, $_ ], @{$feats->[0]}) {
      next if $f->strand ne $strand;
      
      # artificially set score to the max allowed score if it's greater than that
      $f->score($self->{'max_score'}) if $f->score > $self->{'max_score'};
      
      # sort into canonical and non-canonical
      # if it ends with a prefix of the string "non canonical" of length
      #   over 3, it's non canonical. (Often gets truncated).
      my $can_type = [ split(/:/,$f->display_id) ]->[-1];
      if($can_type and length($can_type)>3 and 
         substr("non canonical",0,length($can_type)) eq $can_type) {
        push @$sorted_non_can_feats, $f;
      } else {
        push @$sorted_can_feats, $f;
      }
      
      $hrefs->{$f->display_id} = $self->href($f);
    }
    
    # draw canonical first and then non-canonical features
    push @{$sorted_feats}, @$_ for $sorted_can_feats, $sorted_non_can_feats;

    $self->draw_wiggle_plot($sorted_feats, {
      min_score            => 0,
      max_score            => $self->{'max_score'},
      score_colour         => $feature_colour,
      no_axis              => 1,
      axis_label           => 'off',
      use_alpha            => 1,
      class                => 'hover',
      hrefs                => $hrefs,
      non_can_score_colour => $non_can_feature_colour,
    });
  }
}

sub _render_hidden_bgd {
  my ($self,$h) = @_;
  
  # Needs to be first to capture clicks
  # Useful to keep zmenus working on blank regions
  # only useful in nobump or strandbump modes
  my %off = ( 0 => 0 );
  
  if ($self->my_config('strandbump')) {
    $off{0}  = -1;
    $off{$h} = 1;
  }
  
  foreach my $y (keys %off) { 
    # no colour key, ie transparent
    $self->push($self->Rect({
      x         => 0,
      y         => $y,
      width     => $self->{'container'}->length,
      height    => $h,
      absolutey => 1,
      href      => $self->href_bgd($off{$y}),
      class     => 'group',
    }));
  }
}

sub render_as_alignment_nolabel {
  my ($self, $args) = @_;
  
  return $self->render_text if $self->{'text_export'};
  
  my $h               = $args->{'height'} || $self->my_config('height') || 8;
     $h               = $self->{'extras'}{'height'} if $self->{'extras'} && $self->{'extras'}{'height'};
  my $strand_bump     = $self->my_config('strandbump');
  my $explicit_zero   = (defined $_[0] and !$_[0]); # arg of 0 means 0
  my $depth           = $args->{'depth'} || $self->my_config('dep') || 6;
     $depth           = 0 if $strand_bump || $self->my_config('nobump');
  my $show_structure  = $args->{'structure'} || 0;
  ## User setting overrides everything else
  my $default_depth   = $depth;
  my $user_depth      = $self->my_config('userdepth');
  
     $depth           = $user_depth if $user_depth and !$explicit_zero;
  my $gap             = $h < 2 ? 1 : 2;   
  my $strand          = $self->strand;
  my $strand_flag     = $self->my_config('strand');
  my $length          = $self->{'container'}->length;
  my $pix_per_bp      = $self->scalex;
  my $draw_cigar      = $self->my_config('force_cigar') eq 'yes' || $pix_per_bp > 0.2;
  my %highlights      = map { $_, 1 } $self->highlights;
  my $db              = 'DATABASE_CORE';
  my $extdbs          = $self->species_defs->databases->{$db}{'tables'}{'external_db'}{'entries'};      # Get details of external_db - currently only retrieved from core since they should be all the same
  my %features        = $self->features;                                                                # Get array of features and push them into the id hash
  my @sorted          = $self->sort_features_by_priority(%features);                                    # Sort (user tracks) by priority
     @sorted          = $strand < 0 ? sort keys %features : reverse sort keys %features unless @sorted;
  my $join            = $self->{'my_config'}{'data'}{'join'} ne 'off' && !$self->{'renderer_no_join'};
  my @greyscale       = qw(ffffff d8d8d8 cccccc a8a8a8 999999 787878 666666 484848 333333 181818 000000);
  my $ngreyscale      = scalar @greyscale;
  my $regexp          = $pix_per_bp > 0.1 ? '\dI' : $pix_per_bp > 0.01 ? '\d\dI' : '\d\d\dI';
  my $y_offset        = 0;
  my $features_drawn  = 0;
  my $features_bumped = 0;
  my $label_h         = 0;
  my ($fontname, $fontsize);
  
  ## NB We need fontsize for the track expansion text, even if there are no labels
  ($fontname, $fontsize) = $self->get_font_details('outertext');
  if ($self->{'show_labels'}) {
    $label_h = [ $self->get_text_width(0, 'X', '', ptsize => $fontsize, font => $fontname) ]->[3];
    $join    = 1; # The no-join thing gets completely mad with labels on.
  }

  if(!$self->{'show_labels'}) { 
    # Force no bumping if no actual overlap in features
    # XXX doing a sort is too slow: integrate with main sort below 
    # Can take about 1-5ms on tracks with a lot of data
    my %ends;
    my @features;
    foreach my $feature_key (@sorted) {
      my @tmp = @{$features{$feature_key}||[]};
      if (ref $tmp[0] eq 'ARRAY') {
        push @features,@{$tmp[0]};
      } else {
        push @features,@tmp;
      }
    }
    @features = sort { $a->start <=> $b->start } @features;
    my $overlap = 0;
    if(@features) {
      foreach my $s (1..$#features) {
        $overlap = 1 if($features[$s-1]->end > $features[$s]->start);
      }
    }

    $depth = 0 unless $overlap;
  }

  my ($track_height,$total,$on_screen,$off_screen,$on_other_strand) = (0,0,0,0,0);

  foreach my $feature_key (@sorted) {
    ## Fix for userdata with per-track config
    my ($config, @features);
    
    $self->{'track_key'} = $feature_key;
    
    next unless $features{$feature_key};
    
    my @tmp = @{$features{$feature_key}};
    my %id;

    if (ref $tmp[0] eq 'ARRAY') {
      @features = @{$tmp[0]};
      if (ref $tmp[1] eq 'HASH') {
        $config   = $tmp[1];
        $depth  //= $tmp[1]{'dep'};
      }
    } else {
      @features = @tmp;
    }

    $self->_init_bump(undef, $depth);
    my $nojoin_id = 1;
    
    foreach (sort { $a->[0] <=> $b->[0] }  map [ $_->start, $_->end, $_ ], @features) {
      my ($s, $e, $f) = @$_;

      if ($strand_flag eq 'b' && $strand != (($f->can('hstrand') ? $f->hstrand : 1) * $f->strand || -1) || $e < 1 || $s > $length) {
        $on_other_strand = 1;
        next;
      }
      my $fgroup_name = $join ? $self->feature_group($f) : $nojoin_id++;
      my $db_name     = $f->can('external_db_id') ? $extdbs->{$f->external_db_id}{'db_name'} : 'OLIGO';
      
      push @{$id{$fgroup_name}}, [ $s, $e, $f, int($s * $pix_per_bp), int($e * $pix_per_bp), $db_name ];
    }
    my %idl;
    foreach my $k (keys %id) {
      $idl{$k} = $strand * ( max(map { $_->[1] } @{$id{$k}}) -
                             min(map { $_->[0] } @{$id{$k}}));
    }

    next unless keys %id;
    
    my $colour_key     = $self->colour_key($feature_key);
    my $feature_colour = $self->my_colour($colour_key);
    my $join_colour    = $self->my_colour($colour_key, 'join');
    my $label_colour   = $feature_colour;
    my $max_score      = $config->{'max_score'} || 1000;
    my $min_score      = $config->{'min_score'} || 0;
    my ($cg_grades, $score_per_grade, @colour_gradient, $y_pos);
    
    if ($config && $config->{'useScore'} == 2) {
      $cg_grades       =  $config->{'cg_grades'} || 20;
      $score_per_grade = ($max_score - $min_score) / $cg_grades;
      
      my @cg_colours = map { /^cgColour/ && $config->{$_} ? $config->{$_} : () } sort keys %$config;
      my $ccount     = scalar @cg_colours;
      
      if ($ccount) {
        unshift @cg_colours, 'white' if $ccount == 1;
      } else {
        @cg_colours = qw(yellow green blue);
      }
      
      @colour_gradient = $self->{'config'}->colourmap->build_linear_gradient($cg_grades, \@cg_colours);
    }
    
    my $greyscale_max = $config && exists $config->{'greyscale_max'} && $config->{'greyscale_max'} > 0 ? $config->{'greyscale_max'} : 1000;
    
    foreach my $i (sort { $idl{$a} <=> $idl{$b} } keys %id) {
      my @feat       = @{$id{$i}};
      my $db_name    = $feat[0][5];
      my $feat_from  = max(min(map { $_->[0] } @feat),1);
      my $feat_to    = min(max(map { $_->[1] } @feat),$length);
      my $bump_start = int($pix_per_bp * $feat_from) - 1;
      my $bump_end   = int($pix_per_bp * $feat_to);
         $bump_end   = max($bump_end, $bump_start + 1 + [ $self->get_text_width(0, $self->feature_label($feat[0][2], $db_name), '', ptsize => $fontsize, font => $fontname) ]->[2]) if $self->{'show_labels'};
      my $x          = -1e8;
      my $row        = 0;
      $total++;
      
      if ($depth > 0) {
        $row = $self->bump_row($bump_start, $bump_end);
        
        if ($row > $depth) {
          $features_bumped++;
          $off_screen++;
          next;
        }
      }
      $on_screen++;
      
      if ($config->{'useScore'}) {
        my $score = $feat[0][2]->score || 0;
        
        # implicit_colour means that a colour has been arbitrarily assigned
        # during parsing and some stronger indication, such as the presence 
        # of scores, should override those assignments. -- ds23
        if ($config->{'useScore'} == 1 && $config->{'implicit_colour'}) {
          $feature_colour = $greyscale[min($ngreyscale - 1, int(($score * $ngreyscale) / $greyscale_max))];
          $label_colour   = '#333333';
        } elsif ($config->{'useScore'} == 2) {
          $score          = min(max($score, $min_score), $max_score);
          $feature_colour = $colour_gradient[$score >= $max_score ? $cg_grades - 1 : int(($score - $min_score) / $score_per_grade)];
        }
      }
      
      # +1 below cos we render eg a rectangle from (100, 100) of height
      # and width 10 as (100,100)-(110,110), ie actually 11x11. -- ds23
      $y_pos = $y_offset - $row * int($h + 1 + $gap * $label_h) * $strand;

      my $strand_y = $strand_bump && $feat[0][2]->strand == -1 ? $h : 0;
      my $position = {
        x      => $feat[0][0] > 1 ? $feat[0][0] - 1 : 0,
        y      => 0,
        width  => 0,
        height => $h,
      };
      
      my $composite;

      if (scalar @feat == 1 and !$depth and $config->{'simpleblock_optimise'}) {
        $composite = $self;
      } else {
        $composite = $self->Composite({
          %$position,
          href  => $self->href($feat[0][2]),
          title => $self->feature_title($feat[0][2], $db_name),
          class => 'group',
        });
        
        $position = $composite;
      }
      
      foreach (@feat) {
        my ($s, $e, $f) = @$_;
        
        next if int($e * $pix_per_bp) <= int($x * $pix_per_bp);
        
        my $feature_object = ref $f ne 'HASH';
        my $start          = max($s, 1);
        my $end            = min($e, $length);
        my $cigar;
        
        $x = $end;
        
        if ($feature_object) {
          eval { $cigar = $f->cigar_string; };
          if ($config->{'itemRgb'} =~ /on/i && ref($f) =~ /Text::Feature/) { 
            $feature_colour = $f->external_data->{'item_colour'}[0];
          }
        }
     
        if ($self->my_config('has_blocks') && $show_structure) {
          ## BED file shown like transcript
          $label_colour       = $feature_colour;
          my ($block_count)   = @{$f->external_data->{'BlockCount'}||[]};
          my ($block_starts)  = @{$f->external_data->{'BlockStarts'}||[]};
          my ($block_sizes)   = @{$f->external_data->{'BlockSizes'}||[]};
          my @block_starts    = split(',', $block_starts); 
          my @block_sizes     = split(',', $block_sizes); 
          my ($thick_start)   = @{$f->external_data->{'thick_start'} || [0]};
          my ($thick_end)     = @{$f->external_data->{'thick_end'} || [0]};
          ## Make relative to viewport
          $thick_start        -= $self->{'container'}->start if $thick_start;
          $thick_end          -= $self->{'container'}->start if $thick_end;

          ## Fix for non-intuitive configuration of non-coding transcripts
          if ($thick_start == $thick_end) {
            $thick_start  = 0;
            $thick_end    = 0;
          }
          my $coding = $thick_start || $thick_end ? 1 : 0;
  
          ## Ignore thick start/end if it's outside the current region
          $thick_start = 0 if $thick_start < 1;
          $thick_end = 0 if $thick_end >= $end;

          my %glyph_params  = (
                                y           => $composite->{'y'},
                                height      => $h,
                                colour      => $feature_colour,
                                absolutey   => 1,
                              );

          for (my $j = 0; $j < $block_count; $j++) {
            my $block_start = $s + $block_starts[$j] - 1;
            my $block_width = $block_sizes[$j] || 1;
            my $block_end   = $block_start + $block_width;
            next if ($block_end < 0 || $block_start > $length);

            ## Truncate to limits of viewport
            $block_start  = 0 if $block_start < 0;
            $block_end    = $length if $block_end > $length;
            $block_width  = $block_end - $block_start if $block_width > $block_end;

            my %block_params = %glyph_params;

            if ($thick_start && $thick_start > $block_start) {
              if ($thick_start > $block_end) {
                $block_params{'x'}     = $block_start;
                $block_params{'width'} = $block_width;
                $composite->unshift($self->draw_utr(%block_params));
              }
              else {
                my $utr_width = $thick_start - $block_start;
                $block_params{'x'}     = $block_start;
                $block_params{'width'} = $utr_width;
                $composite->unshift($self->draw_utr(%block_params));

                $block_params{'x'}     = $thick_start;
                $block_params{'width'} = $block_width - $utr_width;
                $composite->unshift($self->draw_coding_block(%block_params));
              }
            }
            elsif ($thick_end && $thick_end < $block_end) {
              if ($thick_end < $block_start) {
                $block_params{'x'}     = $block_start;
                $block_params{'width'} = $block_width;
                $composite->unshift($self->draw_coding_block(%block_params));
              }
              else {
                my $utr_width = $block_end - $thick_end;
                $utr_width = 0 if $utr_width < 1;   
                $block_params{'x'}     = $block_start;
                $block_params{'width'} = $block_width - $utr_width + 1;
                $composite->unshift($self->draw_coding_block(%block_params));

                $block_params{'x'}     = $thick_end;
                $block_params{'width'} = $utr_width;
                $composite->unshift($self->draw_utr(%block_params));
              }
            }
            else {
              $block_params{'x'}     = $block_start;
              $block_params{'width'} = $block_width;
              if ($coding) {
                $composite->unshift($self->draw_coding_block(%block_params));
              }
              else {
                $composite->unshift($self->draw_noncoding_block(%block_params));
              }
            }

            if ($j < ($block_count - 1)) {
              $composite->push($self->Intron({
                                            x         => $block_end,
                                            y         => $composite->{'y'},
                                            width     => $s + $block_starts[$j+1] - $block_end,
                                            height    => $h,
                                            colour    => $feature_colour,
                                            strand    => $f->strand,
                                            absolutey => 1,
                                          }));
            }
          }
        }
        elsif ($draw_cigar || $cigar =~ /$regexp/) {
          $composite->push($self->Space({
            x         => $start - 1,
            y         => 0,
            width     => $end - $start + 1,
            height    => $h,
            absolutey => 1,
          }));
          
          $self->draw_cigar_feature({
            composite      => $composite, 
            feature        => $f, 
            height         => $h, 
            feature_colour => $feature_colour, 
            label_colour   => $label_colour,
            delete_colour  => 'black', 
            scalex         => $pix_per_bp,
            y              => $strand_y,
          });
        } else {
          $composite->push($self->Rect({
            x            => $start - 1,
            y            => $strand_y,
            width        => $end - $start + 1,
            height       => $h,
            colour       => $feature_colour,
            label_colour => $label_colour,
            absolutey    => 1,
          }));
        }
        
        $features_drawn = 1;
      }
      
      if ($composite ne $self) {
        if (!$show_structure) {
          if ($h > 1) {
            $composite->bordercolour($feature_colour) if $join;
          } else {
            $composite->unshift($self->Rect({
                                              x         => $composite->{'x'},
                                              y         => $composite->{'y'},
                                              width     => $composite->{'width'},
                                              height    => $h,
                                              colour    => $join_colour,
                                              absolutey => 1
                                            }));
          }
        }
        
        $composite->y($composite->y + $y_pos);
        $self->push($composite);
      }
      
      if ($self->{'show_labels'}) {
        my $start = $self->{'container'}->start;
        $self->push($self->Text({
          font      => $fontname,
          colour    => $label_colour,
          height    => $fontsize,
          ptsize    => $fontsize,
          text      => $self->feature_label($feat[0][2], $db_name),
          title     => $self->feature_title($feat[0][2], $db_name),
          halign    => 'left',
          valign    => 'center',
          x         => $position->{'x'},
          y         => $position->{'y'} + $h + 2,
          width     => $position->{'x'} + ($bump_end - $bump_start) / $pix_per_bp,
          height    => $label_h,
          absolutey => 1,
          href      => $self->href($feat[0][2],{ fake_click_start => $start + $feat_from, fake_click_end => $start + $feat_to }),
          class     => 'group', # for click_start/end on labels
        }));
      }
      
      if ($self->{'config'}->get_option('opt_highlight_feature') != 0 && exists $highlights{$i}) {
        $self->unshift($self->Rect({
          x         => $position->{'x'} - 1 / $pix_per_bp,
          y         => $position->{'y'} - 1,
          width     => $position->{'width'} + 2 / $pix_per_bp,
          height    => $h + 2,
          colour    => 'highlight1',
          absolutey => 1,
        }));
      }
      $track_height = $position->{'y'} if $position->{'y'} > $track_height;
    }
    $y_offset -= $strand * ($self->_max_bump_row * ($h + $gap + $label_h) + 6);
  }

  my $text;
  if ($off_screen) {
    my $default = $depth == $default_depth ? 'by default' : '';
    $text = "Showing $on_screen of $total features, due to track being limited to $depth rows $default - click to show more";
  } 
  elsif ($total > 0) {
    $text = "Showing all $total features - click to show fewer";
  }
  if ($text) {
    my $y = $track_height + $fontsize * 2 + 10;
    my $href = $self->_url({'action' => 'ExpandTrack', 'goto' => $self->{'config'}->hub->action, 'count' => $on_screen+$off_screen, 'default' => $default_depth}); 
    $self->push($self->Text({
          font      => $fontname,
          colour    => 'black',
          height    => $fontsize,
          width     => $self->{'container'}->length,
          ptsize    => $fontsize,
          text      => $text,
          halign    => 'left',
          valign    => 'center',
          x         => 0, 
          y         => $y,
          absolutey => 1,
          href      => $href,
        }));
    $self->push($self->Space({
            x         => 0,
            y         => $y + 5,
            width     => 100,
            height    => 8,
            absolutey => 1,
    }));
  }
  
  $self->_render_hidden_bgd($h) if $features_drawn && $self->my_config('addhiddenbgd') && $self->can('href_bgd') && !$depth; 
  
  $self->errorTrack(sprintf q{No features from '%s' on this strand}, $self->my_config('name')) unless $features_drawn || $on_other_strand || $self->{'no_empty_track_message'} || $self->{'config'}->get_option('opt_empty_tracks') == 0;
  $self->errorTrack(sprintf(q{%s features from '%s' omitted}, $features_bumped, $self->my_config('name')), undef, $y_offset) if $self->get_parameter('opt_show_bumped') && $features_bumped;
}

sub draw_coding_block {
  my ($self, %params) = @_;
  return $self->Rect({%params});
}

sub draw_noncoding_block {
  my ($self, %params) = @_;
  $params{'bordercolour'} = $params{'colour'};
  delete $params{'colour'};
  return $self->Rect({%params});
}

sub draw_utr {
  my ($self, %params) = @_;
  $params{'height'} = $params{'height'} - 2;
  $params{'y'} += 1; 
  return $self->draw_noncoding_block(%params);
}

# First we cluster to a sensible scale for this display. Then we characterise
# each cluster as: perfect match; contains inserts; contains deletes; mixed.

sub render_difference {
  my ($self) = @_;

  $self->draw_cigar_difference({});
}

sub render_ungrouped {
  my $self           = shift;
  my $strand         = $self->strand;
  my $strand_flag    = $self->my_config('strand');
    my $length         = $self->{'container'}->length;
    my $pix_per_bp     = $self->scalex;
  my $draw_cigar     = $self->my_config('force_cigar') eq 'yes' || $pix_per_bp > 0.2;
  my $h              = $self->my_config('height') || 8;
  my $regexp         = $pix_per_bp > 0.1 ? '\dI' : $pix_per_bp > 0.01 ? '\d\dI' : '\d\d\dI';
  my $features_drawn = 0;
  my $x              = -1e8; ## used to optimize drawing
  my %features       = $self->features;
  my $y_offset       = 0;
  my $label_h        = 0;
  my ($fontname, $fontsize, $on_this_strand, @ok_features);
  
  if ($self->{'show_labels'}) {
    ($fontname, $fontsize) = $self->get_font_details('outertext');
    $label_h = [ $self->get_text_width(0, 'X', '', ptsize => $fontsize, font => $fontname) ]->[3];
  }

  ## Grab all the features;
  ## Remove those not on this display strand
  ## Create an array of arrayrefs [start, end, feature]
  ## Sort according to start of feature
  foreach my $feature_key ($strand < 0 ? sort keys %features : reverse sort keys %features) {
    my $flag           = 0;
    my $colour_key     = $self->colour_key($feature_key);
    my $feature_colour = $self->my_colour($colour_key);

    ## Sanity check - make sure the feature set only contains arrayrefs, or the fancy transformation
    ## below will barf (mainly when trying to handle userdata, which includes a config hashref)
    @ok_features = grep ref $_ eq 'ARRAY', @{$features{$feature_key}};
    
    $self->{'track_key'} = $feature_key;
    
    $self->_init_bump(undef, '0.5');
    
    foreach my $f (
      sort { $a->[0] <=> $b->[0] }
      map  { [ $_->start, $_->end, $_ ] }
      grep { !($strand_flag eq 'b' && $strand != (($_->can('hstrand') ? $_->hstrand : 1) * $_->strand || -1) || $_->start > $length || $_->end < 1) } 
      map  { @$_ } @ok_features
    ) {
      my ($start, $end, $feat) = @$f;
      ($start, $end) = ($end, $start) if $end < $start; # Flip start end YUK!
      $start = 1       if $start < 1;
      $end   = $length if $end > $length;
      $on_this_strand++;
      
      next if ($end * $pix_per_bp) == int($x * $pix_per_bp);
      
      my $cigar;
      eval { $cigar = $feat->cigar_string; };
      
      $x = $start;
      
      $features_drawn++;
      $flag++;
      
      if ($draw_cigar || $cigar =~ /$regexp/) {
        $self->draw_cigar_feature({
          composite      => $self, 
          feature        => $feat, 
          height         => $h, 
          feature_colour => $feature_colour, 
          delete_colour  => 'black', 
          scalex         => $pix_per_bp,
          inverted       => $self->{'inverted'} || 0,
        });
      } else {
        $self->push($self->Rect({
          x          => $x - 1,
          y          => $y_offset,
          width      => $end - $x + 1,
          height     => $h,
          colour     => $feature_colour,
          absolutey  => 1,
        }));
      }
      
      if ($self->{'show_labels'}) {
        my $bump_start = int($x * $pix_per_bp) - 1;
        my $title      = $self->feature_label($f->[2]);
        my $tw         = [ $self->get_text_width(0, $title, '', ptsize => $fontsize, font => $fontname) ]->[2];
        my $bump_end   = $bump_start + $tw + 1;
        my $row        = $self->bump_row($bump_start, $bump_end);
        
        if ($row < 0.5) {
          $self->push( $self->Text({
            font      => $fontname,
            colour    => $feature_colour,
            height    => $fontsize,
            ptsize    => $fontsize,
            text      => $title,
            title     => $title,
            halign    => 'left',
            valign    => 'center',
            x         => $x,
            y         => $y_offset + $h,
            width     => ($bump_end - $bump_start) / $pix_per_bp,
            height    => $label_h,
            absolutey => 1
          }));
        }
      }
    }
    
    $y_offset -= $strand * ($h + 2);
  }
  
  $self->errorTrack(sprintf q{No features from '%s' on this strand}, $self->my_config('name')) unless $features_drawn || ($on_this_strand == scalar(@ok_features)) || $self->{'no_empty_track_message'} || $self->{'config'}->get_option('opt_empty_tracks') == 0;
}

sub render_text {
  my $self     = shift;
  my $strand   = $self->strand;
  my %features = $self->features;
  my $method   = $self->can('export_feature') ? 'export_feature' : '_render_text';
  my $export;

  foreach my $feature_key ($strand < 0 ? sort keys %features : reverse sort keys %features) {
    foreach my $f (@{$features{$feature_key}}) {
      foreach (map { $_->[2] } sort { $a->[0] <=> $b->[0] } map { [ $_->start, $_->end, $_ ] } @{$f || []}) {
        $export .= $self->$method($_, $self->my_config('caption'), { headers => [ 'id' ], values => [ $_->can('hseqname') ? $_->hseqname : $_->can('id') ? $_->id : '' ] });
      }
    }
  }

  return $export;
}

# Renders with emphasis on positions with poor alignment. Useful, eg for patches.
sub render_misalign {
  my $self = shift;
  my %features       = $self->features;

  $self->{'inverted'} = 1;
  $self->render_ungrouped(@_);
}

1;
