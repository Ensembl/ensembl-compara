=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::Role::Default;

### Shared functionality for new glyphsets - default behaviour
### if not otherwise specified in other roles

use strict;

use Role::Tiny;
use List::Util qw(min max);

use EnsEMBL::Web::Utils::FormatText qw(add_links);
use EnsEMBL::Draw::Style::Extra::Legend;

sub draw_features {
  my ($self, $subtracks) = @_;
  $subtracks ||= $self->{'data'}; ## cached track
  return unless $subtracks && ref $subtracks eq 'ARRAY';
  my $feature_count = 0;

  foreach (@$subtracks) {
    next unless $_->{'features'} && ref $_->{'features'} eq 'ARRAY';
    $feature_count += scalar(@{$_->{'features'}||[]});
  }

  if ($feature_count < 1) {
    return $self->no_features;
  }

  ## Defaults
  $self->{'my_config'}->set('slice_length', $self->{'container'}->length);
  $self->{'my_config'}->set('bumped', 1) unless defined($self->{'my_config'}->get('bumped'));
  unless ($self->{'my_config'}->get('height')) {
    $self->{'my_config'}->set('height', 8);
  }

  unless ($self->{'my_config'}->get('depth')) {
    $self->{'my_config'}->set('depth', 10);
  }

  ## Most wiggle plots make more sense if the baseline is zero
  $self->{'my_config'}->set('baseline_zero', 1);

  my %config    = %{$self->track_style_config};

  my $data        = [];
  my $key         = $self->{'hover_label_class'};
  my $hover_label = $self->{'config'}->{'hover_labels'}{$key};
  my $mod_header  = $hover_label->{'header'};
  my $skipped     = 1;

  foreach (@$subtracks) {
    my $features  = $_->{'features'};
    my $metadata  = $_->{'metadata'} || {};
    next unless scalar @{$features||[]};
    $skipped = 0;

    ## Do any required post-processing of features
    if ($self->can('post_process')) {
      $features = $self->post_process($features);
    }

    ## Set alternative colour (used by some styles)
    if ($metadata->{'color'} && !$metadata->{'altColor'}) {
        ## No alt set, so default to a half-tint of the main colour
        my @gradient = EnsEMBL::Draw::Utils::ColourMap::build_linear_gradient(3, ['white', $metadata->{'color'}]);
        $metadata->{'altColor'} = $gradient[1];
    }

    my $name = $metadata->{'name'};
    if ($name && $hover_label->{'header'} && $hover_label->{'header'} !~ /$name/) { ## Don't add the track name more than once!
      if ($mod_header) {
        $hover_label->{'header'} .= ': ';
        $mod_header = 0;
      }
      else {
        $hover_label->{'header'} .= '; '; 
      }
      $hover_label->{'header'} .= $name;
    }

    ## Add description to track name mouseover menu (if not added already)
    my $description   = $metadata->{'description'};
    my $already_seen  = ($hover_label->{'extra_desc'} && $description 
                          && $hover_label->{'extra_desc'} =~ /$description/);
    if ($description && !$already_seen) {
      $description = add_links($description);
      $hover_label->{'extra_desc'} .= '<br>' if $hover_label->{'extra_desc'}; 
      $hover_label->{'extra_desc'} .= $description;
    }
    ## Also put it into config, for subtitles
    $metadata->{'subtitle'} ||= $self->{'my_config'}->get('longLabel') 
                                  || $description 
                                  || $self->{'my_config'}->get('caption');

    ## Could also be done using $self->data_for_strand, but this avoids another loop
    push @$data, {'metadata' => $metadata, 'features' => $features};
  }

  if ($skipped) {
    return $self->no_features;
  }

  $config{'bg_href'} = $self->bg_href;

  my $drawing_style = $self->{'my_config'}->get('drawing_style') || ['Feature::Structured'];

  foreach (@{$drawing_style||[]}) {
    my $style_class = 'EnsEMBL::Draw::Style::'.$_;
    if ($self->dynamic_use($style_class)) {
      my $style = $style_class->new(\%config, $data);
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

sub draw_aggregate {
  my ($self, $data) = @_;
  $data ||= $self->{'data'};
  return unless $data && ref $data eq 'ARRAY';
  my $feature_count = 0;

  foreach (@$data) {
    next unless $_->{'features'} && ref $_->{'features'} eq 'ARRAY';
    $feature_count += scalar(@{$_->{'features'}||[]});
    $_->{'metadata'}{'subtitle'} ||= $self->{'my_config'}->get('longLabel') 
                                      || $self->{'my_config'}->get('caption');
  }

  if ($feature_count < 1) {
    return $self->no_features;
  }

  my %config = %{$self->track_style_config};

  $config{'bg_href'} = $self->bg_href;

  my $drawing_style = $self->{'my_config'}->get('drawing_style') || ['Graph'];

  ## Recalculate colours if using the pvalue renderer
  if ($self->{'my_config'}->get('use_pvalue')) {
    $self->{'my_config'}->set('subtitle_y', $self->{'my_config'}->get('height') + 4);
    my $params = {
                    min_score      => 0,
                    max_score      => 1,
                    key_labels     => [ 0, 0.05, 1 ],
                    transform      => 'log2',
                    decimal_places => 5,
                  };
    my ($gradient, $labels) = $self->convert_to_pvalues($data, $params);
    ## Also draw key in lefthand margin
    my $legend = EnsEMBL::Draw::Style::Extra::Legend->new(\%config);
    $legend->draw_gradient_key($gradient, $labels);
    $self->push(@{$legend->glyphs||[]});
  }

  foreach (@{$drawing_style||[]}) {
    my $style_class = 'EnsEMBL::Draw::Style::'.$_;
    if ($self->dynamic_use($style_class)) {
      my $style = $style_class->new(\%config, $data);
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

sub convert_to_pvalues {
  my ($self, $data, $params) = @_;

  ## pre-defined transform functions
  my %transforms = (
    default => sub { return $_[0] },
    log2 => sub {
      my $score = shift;
      $score = 0 if $score < 0;
      return 1 if $score == 0;
      return 0 if $score == 1;   
      return ( log(1 / $score) / log(2) ) / 10;
    }
  );

  ## Set parameters
  my $max_score        = $params->{max_score} || 1000;
  my $min_score        = $params->{min_score} || 0;
  my $default_colour   = $self->{my_config}->get('colour') || 'red';
  my @gradient_colours = @{ $params->{gradient_colours} || ['white', $default_colour] };
  my $transform        = $transforms{ $params->{transform} || 'default' };
  my $decimal_places   = $params->{decimal_places} || 2;

  my $colour_grades       = 20;
  my @gradient            = $self->{config}->colourmap->build_linear_gradient($colour_grades, \@gradient_colours);
  my $transform_min_score = min($transform->($min_score), $transform->($max_score));
  my $transform_max_score = max($transform->($min_score), $transform->($max_score));
  my $score_per_grade     = ($transform_max_score - $transform_min_score) / $colour_grades;
  
  ## Predefined method to select new colour based on score
  my $grade_from_score = sub {
    my $score = shift;
    my $gradient_score = min( max( $transform->($score), $transform_min_score ), $transform_max_score );
    my $grade = $gradient_score >= $transform_max_score ? $colour_grades - 1 : int(($gradient_score - $transform_min_score) / $score_per_grade);    
    return $grade
  };

  ## Create a key to these colours
  my $key         = {};
  my $key_labels  = $params->{key_labels} || [$min_score, $max_score];
  foreach (@$key_labels) {
    $key->{$grade_from_score->($_)} = $_;
  }

  ## Finally we get to actually set the feature colours!
  foreach (@$data) {
    foreach my $f (@{$_->{'features'}||[]}) {
      my $colour = $gradient[ $grade_from_score->($f->{'score'}) ];
      $f->{'colour'} = $colour;
    }
  }
  return (\@gradient, $key);
}

1;
