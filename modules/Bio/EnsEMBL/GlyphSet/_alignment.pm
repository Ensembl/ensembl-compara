package Bio::EnsEMBL::GlyphSet::_alignment;

use strict;

use List::Util qw(min max);

use base qw(Bio::EnsEMBL::GlyphSet_wiggle_and_block Bio::EnsEMBL::GlyphSet::_difference);

#==============================================================================
# The following functions can be over-riden if the class does require
# something diffirent - main one to be over-riden is probably the
# features call - as it will need to take different parameters...
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

sub render_unlimited        { $_[0]->render_normal(1, 1000);                                 }
sub render_stack            { $_[0]->render_normal(1, 40);                                   }
sub render_simple           { $_[0]->render_normal;                                          }
sub render_half_height      { $_[0]->render_normal($_[0]->my_config('height') / 2 || 4, 20); }
sub render_labels           { $_[0]->{'show_labels'} = 1; $_[0]->render_normal;              }
sub render_ungrouped_labels { $_[0]->{'show_labels'} = 1; $_[0]->render_ungrouped;           }

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
  if($self->my_config('strandbump')) {
    $off{0} =  -1;
    $off{$h} = 1;
  }
  foreach my $y (keys %off) { 
    my $href;
    $href = $self->href_bgd($off{$y}) if $self->can('href_bgd');
    $self->push($self->Rect({
      x         => 0,
      y         => $y,
      width     => $self->{'container'}->length,
      height    => $h,
      # no colour key, ie transparent
      absolutey => 1,
      href      => $href,
      class     => 'group',
    }));
  }
}

sub render_normal {
  my $self = shift;
  
  return $self->render_text if $self->{'text_export'};
  
  my $tfh             = $self->{'config'}->texthelper->height($self->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'});
  my $h               = @_ ? shift : ($self->my_config('height') || 8);
     $h               = $self->{'extras'}{'height'} if $self->{'extras'} && $self->{'extras'}{'height'};
  my $dep             = @_ ? shift : ($self->my_config('dep') || 6);
     $dep = 0 if $self->my_config('nobump') or $self->my_config('strandbump');
  my $gap             = $h < 2 ? 1 : 2;   
  my $strand          = $self->strand;
  my $strand_flag     = $self->my_config('strand');
  my $length          = $self->{'container'}->length;
  my $pix_per_bp      = $self->scalex;
  my $draw_cigar      = $self->my_config('force_cigar') eq 'yes' || $pix_per_bp > 0.2;
  my %highlights      = map { $_, 1 } $self->highlights;
  my $db              = 'DATABASE_CORE';
  my %features        = $self->features;                                                                # Get array of features and push them into the id hash
  my @sorted          = $self->sort_features_by_priority(%features);                                    # Sort (user tracks) by priority
     @sorted          = $strand < 0 ? sort keys %features : reverse sort keys %features unless @sorted;
  my $extdbs          = $self->species_defs->databases->{$db}{'tables'}{'external_db'}{'entries'};      # Get details of external_db - currently only retrieved from core since they should be all the same
  my $y_offset        = 0;
  my $features_drawn  = 0;
  my $features_bumped = 0;
  my $label_h         = 0;
  my ($fontname, $fontsize);
  
  $self->_render_hidden_bgd($h) if($self->my_config('addhiddenbgd'));  
  my $join = ($self->{'my_config'}{'data'}{'join'} ne 'off' && !$self->{'renderer_no_join'});
  if ($self->{'show_labels'}) {
    ($fontname, $fontsize) = $self->get_font_details('outertext');
    $label_h = [ $self->get_text_width(0, 'X', '', ptsize => $fontsize, font => $fontname) ]->[3];
    $join = 1; # The no-join thing gets completely mad with labels on.
  }
  
  foreach my $feature_key (@sorted) {
    ## Fix for userdata with per-track config
    my ($config, @features);
    
    $self->{'track_key'} = $feature_key;
    
    next unless $features{$feature_key};
    
    my @tmp = @{$features{$feature_key}};
    my %id;

    if (ref $tmp[0] eq 'ARRAY') {
      @features = @{$tmp[0]};
      $config   = $tmp[1];
      # below not ||= because 0 || undef is undef; we want //= but don't have 5.10
      $dep  = defined $dep ? $dep : $tmp[1]->{'dep'};
    } else {
      @features = @tmp;
    }

    $self->_init_bump(undef, $dep);
    
    my $nojoin_id = 1;
    foreach my $f (map $_->[2], sort { $a->[0] <=> $b->[0] }  map [ $_->start,$_->end, $_ ], @features) {
      my $s = $f->start;
      my $e = $f->end;
      
      next if $strand_flag eq 'b' && $strand != (($f->can('hstrand') ? $f->hstrand : 1) * $f->strand || -1) || $e < 1 || $s > $length;      
      my $fgroup_name = $join ? $self->feature_group($f) : $nojoin_id++;
      my $db_name     = $f->can('external_db_id') ? $extdbs->{$f->external_db_id}{'db_name'} : 'OLIGO';
      
      push @{$id{$fgroup_name}}, [ $s, $e, $f, int($s * $pix_per_bp), int($e * $pix_per_bp), $db_name ];
    }
    
    next unless keys %id;
    
    my @greyscale      = qw(ffffff d8d8d8 cccccc a8a8a8 999999 787878 666666 484848 333333 181818 000000);
    my $colour_key     = $self->colour_key($feature_key);
    my $feature_colour = $self->my_colour($colour_key);
    my $label_colour   = $feature_colour;
    my $join_colour    = $self->my_colour($colour_key, 'join');
    my $max_score      = $config->{'max_score'} || 1000;
    my $min_score      = $config->{'min_score'} || 0;
    my $regexp         = $pix_per_bp > 0.1 ? '\dI' : $pix_per_bp > 0.01 ? '\d\dI' : '\d\d\dI';
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
    
    my $ngreyscale = scalar(@greyscale);
    my $greyscale_max = 1000;
    if ($config && exists($config->{'greyscale_max'}) && $config->{'greyscale_max'} > 0) {
      $greyscale_max = $config->{'greyscale_max'};
    }

    foreach my $i (sort { $id{$a}[0][3] <=> $id{$b}[0][3] || $id{$b}[-1][4] <=> $id{$a}[-1][4] } keys %id) {
      my @feat       = @{$id{$i}};
      my $db_name    = $feat[0][5];
      my $bump_start = int($pix_per_bp * ($feat[0][0]  < 1       ? 1       : $feat[0][0])) - 1;
      my $bump_end   = int($pix_per_bp * ($feat[-1][1] > $length ? $length : $feat[-1][1]));
      my $x          = -1e8;
      
      if ($config) {
        my $f = $feat[0][2];
        
        # implicit_colour means that a colour has been arbitrarily assigned
        # during parsing and some stronger indication, such as the presence 
        # of scores, should override those assignments. -- ds23
        if ($config->{'useScore'} == 1 && $config->{'implicit_colour'}) {
          my $index          = int(($f->score * $ngreyscale) / $greyscale_max);
             $index          = min($ngreyscale - 1, $index);
             $feature_colour = $greyscale[$index];
             $label_colour   = '#333333';
        } elsif ($config->{'useScore'} == 2) {
          my $score          = $f->score || 0;
             $score          = $min_score if $score < $min_score;
             $score          = $max_score if $score > $max_score;
          my $grade          = $score >= $max_score ? $cg_grades - 1 : int(($score - $min_score) / $score_per_grade);
             $feature_colour = $colour_gradient[$grade];
        }
      }
      
      if ($self->{'show_labels'}) {
        my $title    = $self->feature_label($feat[0][2], $db_name);
        my $tw       = [ $self->get_text_width(0, $title, '', ptsize => $fontsize, font => $fontname) ]->[2];
        my $text_end = $bump_start + $tw + 1;
           $bump_end = $text_end if $text_end > $bump_end;
      }
      
      my $row = 0;
      if($dep > 0) {
        $row = $self->bump_row($bump_start, $bump_end);
        
        if ($row > $dep) {
          $features_bumped++;
          next;
        }
      }
      
      # +1 below cos we render eg a rectangle from (100, 100) of height
      # and width 10 as (100,100)-(110,110), ie actually 11x11. -- ds23
      $y_pos = $y_offset - $row * int($h + 1 + $gap * $label_h) * $strand;
      
      my $strand_y = ($self->my_config('strandbump') and $feat[0][2]->strand == -1)?$h:0;
      my $composite = $self->Composite({
        href  => $self->href($feat[0][2]),
        x     => $feat[0][0] > 1 ? $feat[0][0] - 1 : 0,
        width => 0,
        y     => 0,
        height => $h,
        title => $self->feature_title($feat[0][2], $db_name),
        class => 'group',
      });
      
      foreach (@feat) {
        my ($s, $e, $f) = @$_;
        
        next if int($e * $pix_per_bp) <= int($x * $pix_per_bp);
        
        my $cigar;
        eval { $cigar = $f->cigar_string; };
        
        $features_drawn++;
        $feature_colour = $f->external_data->{'item_colour'}[0] if $config->{'itemRgb'} =~ /on/i;
        
        if ($draw_cigar || $cigar =~ /$regexp/) {
           my $start = $s < 1 ? 1 : $s;
           my $end   = $e > $length ? $length : $e;
              $x     = $end;
          
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
          my $start = $s < 1 ? 1 : $s;
          my $end   = $e > $length ? $length : $e;
             $x     = $end;
          
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
      }
      
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
      
      $composite->y($composite->y + $y_pos);
      $self->push($composite);
      
      if ($self->{'show_labels'}) {
        $self->push($self->Text({
          font      => $fontname,
          colour    => $label_colour,
          height    => $fontsize,
          ptsize    => $fontsize,
          text      => $self->feature_label($feat[0][2], $db_name),
          title     => $self->feature_title($feat[0][2], $db_name),
          halign    => 'left',
          valign    => 'center',
          x         => $composite->{'x'},
          y         => $composite->{'y'} + $h + 2,
          width     => $composite->{'x'} + ($bump_end - $bump_start) / $pix_per_bp,
          height    => $label_h,
          absolutey => 1,
          href  => $self->href($feat[0][2]),
        }));
      }
      
      if (exists $highlights{$i}) {
        $self->unshift($self->Rect({
          x         => $composite->{'x'} - 1/$pix_per_bp,
          y         => $composite->{'y'} - 1,
          width     => $composite->{'width'} + 2/$pix_per_bp,
          height    => $h + 2,
          colour    => 'highlight1',
          absolutey => 1,
        }));
      }
    }
    
    $y_offset -= $strand * ($self->_max_bump_row * ($h + $gap + $label_h) + 6);
  }
  
  $self->errorTrack(sprintf q{No features from '%s' in this region}, $self->my_config('name')) unless $features_drawn || $self->{'no_empty_track_message'} || $self->{'config'}->get_option('opt_empty_tracks') == 0;
  $self->errorTrack(sprintf(q{%s features from '%s' omitted}, $features_bumped, $self->my_config('name')), undef, $y_offset) if $self->get_parameter('opt_show_bumped') && $features_bumped;
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
  my ($fontname, $fontsize);
  
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
    my @ok_features = grep ref $_ eq 'ARRAY', @{$features{$feature_key}};
    
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
  
  $self->errorTrack(sprintf q{No features from '%s' in this region}, $self->my_config('name')) unless $features_drawn || $self->{'no_empty_track_message'} || $self->{'config'}->get_option('opt_empty_tracks') == 0;
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
