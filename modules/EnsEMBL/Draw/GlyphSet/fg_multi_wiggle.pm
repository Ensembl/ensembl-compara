=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  warn ">>> RENDERING PEAKS";
  $self->{'my_config'}->set('drawing_style', ['Feature::Peaks']);
  $self->{'my_config'}->set('height', 8);
  $self->{'my_config'}->set('hide_subtitle',1);
  $self->_render_aggregate;
}

sub render_signal {
  my $self = shift;
  warn ">>> RENDERING SIGNAL";
  $self->{'my_config'}->set('drawing_style', ['Graph']);
  $self->{'my_config'}->set('height', 60);
  $self->{'my_config'}->set('hide_subtitle',1);
  $self->_render_aggregate;
}

sub render_signal_feature {
  my $self = shift;
  warn ">>> RENDERING PEAKS WITH SIGNAL";
  $self->{'my_config'}->set('drawing_style', ['Feature::Peaks', 'Graph']);
  $self->{'my_config'}->set('height', 60);
  $self->{'my_config'}->set('hide_subtitle',1);
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
  $self->{'my_config'}->set('display_structure', 1);
  $self->{'my_config'}->set('display_summit', 1);
  $self->{'my_config'}->set('slice_start', $self->{'container'}->start);

  ## Draw the track(s)
  my $cell_line = $self->my_config('cell_line');
  my $label     = $self->my_config('label');
  my $colours   = $self->{'config'}{'fg_multi_wiggle_colours'} ||= $self->get_colours;

  my $args = {
              'label'     => $label, 
              'colours'   => $colours, 
              'is_multi'  => !!$cell_line eq 'MultiCell',
              };

  my $data    = $self->data_by_cell_line($cell_line);
  my $set     = $self->my_config('set');
  my %config  = %{$self->track_style_config};

  my $top = 0;
  foreach (@{$self->{'my_config'}->get('drawing_style')||[]}) {
    my $style_class = 'EnsEMBL::Draw::Style::'.$_;
    my $any_on = scalar keys %{$data->{'on'}};
    if ($self->dynamic_use($style_class)) {
      my $subset;
      if ($_ =~ /Feature/) {
        if ($data->{$set}{'block_features'}) {
          ## Add a summary title in the lefthand margin
          my $label     = $self->my_config('label');
          my $tracks_on = $data->{$set}{'on'} 
                    ? sprintf '%s/%s features turned on', map scalar keys %{$data->{$set}{$_} || {}}, qw(on available) 
                    : '';

          my $label_style = EnsEMBL::Draw::Style::Extra::Header->new(\%config);
 
          ## Only add the extra zmenu stuff if we're not drawing a wiggle
          $subset = $self->get_blocks($data->{$set}{'block_features'}, $args);
          $label_style->draw_margin_subhead($label, $tracks_on);
          $label_style->draw_margin_sublabels($subset);
          my $colour_legend = $self->_colour_legend($subset);
          my $hub = $self->{'config'}->hub;
          my $cell_type_url = $hub->url('Component', {
            action   => 'Web',
            function    => 'CellTypeSelector/ajax',
            image_config => $self->{'config'}->type,
          });
          my $evidence_url = $hub->url('Component', {
            action => 'Web',
            function => 'EvidenceSelector/ajax',
            image_config => $self->{'config'}->type,
          });
          $label_style->draw_sublegend({
            label => "Legend & more",
            title => $label,
            colour_legend => $colour_legend,
            sublegend_links => [
              {
                text => 'Select other cell types',
                href => $cell_type_url,
                class => 'modal_link',
              },{
                text => 'Select evidence to show',
                href => $evidence_url,
                class => 'modal_link',
              },
            ],
          });
          $top = $subset->[-1]{'metadata'}{'y'} + $subset->[-1]{'metadata'}{'height'} if @$subset;
          $self->push(@{$label_style->glyphs||[]});
        }
        else {
          $self->display_error_message($cell_line, $set, 'peaks') if $any_on;
        }
      }
      else {
        if ($data->{$set}{'wiggle_features'}) {
          $subset = $self->get_wiggle($data->{$set}{'wiggle_features'}, $args);
          $_->{'metadata'}{'y'} = $top for @$subset;
        }
        else {
          $self->display_error_message($cell_line, $set, 'wiggle') if $any_on;
        }
      }
      my $style = $style_class->new(\%config, $subset);
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

sub _block_zmenu {
  my ($self,$f) = @_;

  my $offset = $self->{'container'}->strand>0 ? $self->{'container'}->start - 1 : $self->{'container'}->end + 1;

  return $self->_url({
    action => 'FeatureEvidence',
    fdb    => 'funcgen',
    pos    => sprintf('%s:%s-%s', $f->slice->seq_region_name, $offset + $f->start, $f->end + $offset),
    fs     => $f->feature_set->name,
    ps     => $f->summit || 'undetermined',
    act    => $self->{'config'}->hub->action,
    evidence => !$self->{'will_draw_wiggle'},
  });
}

sub get_blocks {
  my ($self, $dataset, $args) = @_;

  my @data;
  foreach my $f_set (sort { $a cmp $b } keys %$dataset) {
    my $data = {'metadata' => {},
                'features' => [],
                };
    my @temp          = split /:/, $f_set;
    pop @temp;
    my $feature_name  = pop @temp;
    my $cell_line     = join(':',@temp);
    my $colour        = $args->{'colours'}{$feature_name};

    my $label         = $feature_name;
    $label            = "$feature_name $cell_line" if $args->{'is_multi'};

    my $features      = $dataset->{$f_set};
    foreach my $f (@$features) {
      ## Create motif features
      my $structure = [];
      my @loci = @{$f->get_underlying_structure};
      my $end  = pop @loci;
      my ($start, @mf_loci) = @loci;

      while (my ($mf_start, $mf_end) = splice @mf_loci, 0, 2) {
        push @$structure, {'start' => $mf_start, 'end' => $mf_end};
      }

      my $hash = {
                  start     => $f->start,
                  end       => $f->end,
                  midpoint  => $f->summit,
                  structure => $structure, 
                  label     => $label,
                  href      => $self->_block_zmenu($f),
                  };
      push @{$data->{'features'}}, $hash; 
    }
    $data->{'metadata'}{'sublabel'} = $label;
    $data->{'metadata'}{'colour'} = $colour;
    $data->{'metadata'}{'feature_height'} = 8;
    push @data,$data;
  }

  return \@data;
}

sub get_wiggle {
  my ($self,$dataset,$args) = @_;

  my $bins = $self->bins;
  my @data;
  foreach my $f_set (sort { $a cmp $b } keys %$dataset) {
    my $url = $dataset->{$f_set};
    my $data = $self->get_data($bins,$url);
    push @data,{
      metadata => $data->[0]{'metadata'},
      features => $data->[0]{'features'}{1},
    };
    my @temp          = split /:/, $f_set;
    pop @temp;
    my $feature_name  = pop @temp;
    my $colour        = $args->{'colours'}{$feature_name};
    $data[-1]->{'metadata'}{'colour'} = $colour;
  }
  return \@data;
}

sub get_colours {
  my $self      = shift;
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

sub _add_sublegend {

}

## Custom render methods

sub render_text {
  my ($self, $wiggle) = @_;
  warn 'No text render implemented for bigwig';
  return '';
}


1;
