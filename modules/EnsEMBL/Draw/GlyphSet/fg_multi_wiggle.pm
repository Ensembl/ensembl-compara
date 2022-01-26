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

package EnsEMBL::Draw::GlyphSet::fg_multi_wiggle;

### Draws peak and/or wiggle tracks for regulatory build data
### e.g. histone modifications

use strict;

use EnsEMBL::Draw::Style::Extra::Header;

use parent qw(EnsEMBL::Draw::GlyphSet::bigwig);

sub label { return undef; }

sub render_compact {
  my $self = shift;
  #warn "### RENDERING PEAKS";
  $self->_render_aggregate;
}

sub render_signal {
  my $self = shift;
  #warn "### RENDERING SIGNAL";
  $self->_render_aggregate;
}

sub render_signal_feature {
  my $self = shift;
  #warn "### RENDERING BOTH";
  #$self->{'my_config'}->set('on_error',555);
  $self->_render_aggregate;
}

sub data_by_cell_line {
### Fetch an entire dataset for a given cell line
### @param cell_line String
### @return Hashref
  my ($self, $cell_line) = @_;

  my $config  = $self->{'config'};
  my $data    = $config->{'data_by_cell_line'};
  ## Lazy evaluation
  if (ref($data) eq 'CODE') {
    $data       = $data->() if ref($data) eq 'CODE';
    $config->{'data_by_cell_line'} = $data;
  }
  return $cell_line ? ($data->{$cell_line}||{}) : $data;
}

sub _colour_legend {
  my ($self,$data) = @_;

  my %out;
  foreach my $s (@$data) {
    next unless $s->{'metadata'}{'sublabel'};
    $out{$s->{'metadata'}{'sublabel'}} = $s->{'metadata'}{'colour'};
  }
  return \%out;
}

sub draw_aggregate {
  my $self = shift;

  ## Set some defaults for all displays
  my $top = 0;
  my $h   = 4;
  $self->{'my_config'}->set('multi', 1);
  $self->{'my_config'}->set('vspacing', 0);
  $self->{'my_config'}->set('hide_subtitle',1);
  $self->{'my_config'}->set('display_structure', 1);
  $self->{'my_config'}->set('display_summit', 1);
  $self->{'my_config'}->set('slice_start', $self->{'container'}->start);

  ## Get the features and/or wiggle URL(s)
  my $cell_line = $self->my_config('cell_line');
  my $label   = 'Experiments';
  my $data    = $self->data_by_cell_line($cell_line);
  #warn "### $label: DRAWING AGGREGATE FOR $cell_line";

  #use Data::Dumper;
  #$Data::Dumper::Sortkeys = 1;
  #$Data::Dumper::Maxdepth = 2;

  ## Work out what we need to draw
  my (%blocks, %wiggles);
  foreach my $track (keys %$data) {
    my $info = $data->{$track};
    next unless $info->{'renderer'};
    #warn ">>> TRACK $track HAS RENDERER ".$info->{'renderer'};
    if ($info->{'renderer'} eq 'compact') {
      #warn "... WITH FEATURES: ".Dumper($info->{'block_features'});
      %blocks = (%blocks, %{$info->{'block_features'}||{}});
    }
    elsif ($info->{'renderer'} eq 'signal') {
      #warn "... WITH WIGGLE: ".Dumper($info->{'wiggle_features'});
      %wiggles = (%wiggles, %{$info->{'wiggle_features'}||{}});
    }
    elsif ($info->{'renderer'} eq 'signal_feature') {
      %blocks = (%blocks, %{$info->{'block_features'}||{}});
      #warn "... WITH FEATURES: ".Dumper($info->{'block_features'});
      %wiggles = (%wiggles, %{$info->{'wiggle_features'}||{}});
      #warn "... WITH WIGGLE: ".Dumper($info->{'wiggle_features'});
    }
  }
  #warn "@@@ BLOCKS: ".Dumper(\%blocks);
  #warn "@@@ WIGGLES: ".Dumper(\%wiggles);

  ## Prepare to draw any headers/labels in lefthand column
  if (%blocks) {
    $self->{'my_config'}->set('height', $h * 2);
  }
  my %config  = %{$self->track_style_config};
  my $header  = EnsEMBL::Draw::Style::Extra::Header->new(\%config);
  my $colours   = $self->{'config'}{'fg_multi_wiggle_colours'} ||= $self->get_colours;
  my $args = {
              'label'     => $label, 
              'colours'   => $colours, 
              };
  my ($block_style, $wiggle_style, $subhead_height);
  my $data_for_legend = [];

  ## Draw the peaks
  if (%blocks) {
    my $style_class = 'EnsEMBL::Draw::Style::Feature::Peaks';
    if ($self->dynamic_use($style_class)) {

      ## Add a summary title in the lefthand margin
      my $tracks_on = '';
      $subhead_height = $header->draw_margin_subhead('Experiments', $tracks_on);

      ## Push features down a bit, so their labels don't overlap this header
      my $y_start = $self->{'my_config'}->get('y_start');
      $self->{'my_config'}->set('y_start', $y_start + $subhead_height);

      ## Draw features
      $args->{'feature_type'} = 'block_features';
      my $subset    = $self->get_features(\%blocks, $args);
      $block_style  = $style_class->new(\%config, $subset);

      if ($block_style) {
        $self->{'my_config'}->set('has_sublabels', 1);
        $self->push($block_style->create_glyphs);

        ## Label each subtrack in the margin
        $header->draw_margin_sublabels($subset);

        ## And add to legend
        push @$data_for_legend, @$subset;
      }
    }
  }

  ## Draw the graph tracks
  my $wiggle_offset = 20;
  if (%wiggles) {
    my $style_class = 'EnsEMBL::Draw::Style::Graph';
    if ($self->dynamic_use($style_class)) {

      $self->{'my_config'}->set('on_error', 555);
      $self->{'my_config'}->set('height', $h * 15);
      $self->{'my_config'}->set('initial_offset', $self->{'my_config'}->get('y_start') + $wiggle_offset);

      unless ($subhead_height) {
        ## Add a summary title in the lefthand margin
        my $tracks_on = '';
        $subhead_height = $header->draw_margin_subhead('Experiments', $tracks_on);
      }

      ## Draw features
      $args->{'feature_type'} = 'wiggle_features';
      my $subset    = $self->get_features(\%wiggles, $args);
      $wiggle_style  = $style_class->new(\%config, $subset);

      ## And add to legend
      push @$data_for_legend, @$subset;
    }
  }
  $self->push($wiggle_style->create_glyphs) if $wiggle_style;

  ## Finally create the popup menu and add the header to the glyphset
  my $colour_legend = $self->_colour_legend($data_for_legend);
  my $params = {
                label           => 'Legend & More',
                title           => $label,
                colour_legend   => $colour_legend,
                sublegend_links => $self->_sublegend_links,
               };
  if (%blocks && %wiggles) {
    $params->{'y_offset'} = $wiggle_offset;
  }
  if (%blocks) {
    $params->{'show_peaks'} = 1;
  }
  $header->draw_sublegend($params);
  $self->push(@{$header->glyphs||[]}); 

  ## This is clunky, but it's the only way we can make the new code
  ## work in a nice backwards-compatible way right now!
  ## Get label position, which is set in Style::Graph
  $self->{'label_y_offset'} = $self->{'my_config'}->get('label_y_offset');

  ## Everything went OK, so no error to return
  #warn "############## DONE ##########\n\n";
  return 0;
}

sub _block_zmenu {
  my ($self,$f) = @_;

  my $offset = $self->{'container'}->strand>0 ? $self->{'container'}->start - 1 : $self->{'container'}->end + 1;

  my $component = $self->{'config'}->get_parameter('component');

  return $self->_url({
    action    => 'FeatureEvidence',
    fdb       => 'funcgen',
    pos       => sprintf('%s:%s-%s', $f->slice->seq_region_name, $offset + $f->start, $f->end + $offset),
    fs        => $f->get_PeakCalling->name,

    ps        => $f->summit || 'undetermined',
    act       => $component,
    evidence => !$self->{'will_draw_wiggle'},
  });
}

sub get_features {
  my ($self, $tracks, $args) = @_;

  my $data = [];
  my $legend = {};

  foreach my $key (sort { $a cmp $b } keys %$tracks) {
    my $subtrack = {'metadata' => {},
                    'features' => [],
                    };

    my @temp          = split /:/, $key;
    
    pop @temp;
    my $feature_name  = pop @temp;

    my $colour        = $args->{'colours'}{$feature_name};
    $subtrack->{'metadata'}{'colour'} = $colour;
    $legend->{$feature_name} = $colour;

    my $label         = $feature_name;
    my $cell_line     = join(':',@temp);
    $label           .= ' '.$cell_line if $args->{'is_multi'};
    $subtrack->{'metadata'}{'sublabel'} = $label;

    if ($args->{'feature_type'} eq 'block_features') {
      $subtrack->{'metadata'}{'feature_height'} = 8;
      my $features = $tracks->{$key};
      foreach my $f (@$features) {
        my $href = $self->_block_zmenu($f);
        my $hash = {
                    start     => $f->start,
                    end       => $f->end,
                    midpoint  => $f->summit,
                    label     => $label,
                    href      => $href,
                    };
        push @{$subtrack->{'features'}}, $hash; 
      }
    }
    elsif ($args->{'feature_type'} eq 'wiggle_features') {
      my $bins                    = $self->bins;
      my $url                     = $tracks->{$key};
      my $wiggle                  = $self->get_data($bins, $url);
      $subtrack->{'features'}     = $wiggle->[0]{'features'};

      ## Don't override values that we've already set!
      while (my($k, $v) = each (%{$wiggle->[0]{'metadata'}||{}})) {
        $subtrack->{'metadata'}{$k} ||= $v;
      }
    }
    push @$data, $subtrack;
  }
  
  ## Add colours to legend
  if (keys %$legend) {
    my $legend_colours = $self->{'legend'}{'fg_multi_wiggle_legend'}{'colours'} || {};
    $legend_colours->{$_} = $legend->{$_} for keys %$legend;
    $self->{'legend'}{'fg_multi_wiggle_legend'} = { priority => 1030, 
                                                    legend => [], 
                                                    colours => $legend_colours };
  }

  return $data; 
}

sub get_colours {
  my $self      = shift;
  return unless $self->data_by_cell_line;
  my $config    = $self->{'config'};
  my $colourmap = $config->colourmap;
  my %ratio     = ( 1 => 0.6, 2 => 0.4, 3 => 0.2, 4 => 0 );
  my $count     = 0;
  my %feature_colours;

  # First generate pool of colours we can draw from
  if (!exists $config->{'pool'}) {
    my $colours = $self->my_config('colours');

    $config->{'pool'} = [];

    if ($colours) {
      $config->{'pool'}[$_] = $self->my_colour($_) for sort { $a <=> $b } keys %$colours;
    } else {
      $config->{'pool'} = [qw(red blue green purple yellow orange brown black)]
    }
  }

  # Assign each feature set a colour, and set the intensity based on methalation state
  foreach my $name (sort keys %{$self->data_by_cell_line->{'colours'}}) {
    my $histone_pattern = $name;

    if (!exists $feature_colours{$name}) {
      my $c = $config->{'pool'}[$count++];

      $count = 0 if $count >= 55;

      if ($histone_pattern =~ s/^H\d+//) {
        # First assign a colour for most basic pattern - i.e. no methyalation state information
        my $histone_number = substr $name, 0, 2;

        s/me\d+// for $histone_pattern, $name;

        $feature_colours{$name} = $colourmap->mix($c, 'white', $ratio{4});

        # Now add each possible methyalation state of this type with the appropriate intensity
        for (my $i = 1; $i <= 4; $i++) {
          $histone_pattern  = $histone_number . $histone_pattern unless $histone_pattern =~ /^H\d/;
          $histone_pattern .= $histone_pattern =~ s/me\d+/me$i/ ? '' : "me$i";

          $feature_colours{$histone_pattern} = $colourmap->mix($c, 'white', $ratio{$i});
        }
      } else {
        $feature_colours{$name} = $colourmap->mix($c, 'white', $ratio{4});
      }
    }
  }

  return \%feature_colours;
}

sub _sublegend_links {
  my $self = shift;
 
  my $hub = $self->{'config'}->hub;
  my $matrix_url = $hub->url('Config', {
            action        => 'ViewBottom',
            matrix        => 'RegMatrix',
            menu          => 'regulatory_features',
  });

  return [
          {
            text  => 'Configure tracks',
            href  => $matrix_url,
            class => 'config modal_link',
            rel   => 'modal_config_viewbottom',
          },
        ];
}

## Custom render methods

sub render_text {
  my ($self, $wiggle) = @_;
  warn 'No text render implemented for bigwig';
  return '';
}


1;
