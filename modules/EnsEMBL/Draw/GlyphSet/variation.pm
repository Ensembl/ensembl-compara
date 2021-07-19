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

package EnsEMBL::Draw::GlyphSet::variation;

### Draws a SNP track with new drawing code

use strict;

use List::Util qw(min);

use Bio::EnsEMBL::Variation::Utils::Constants;
use Bio::EnsEMBL::Variation::VariationFeature;

use EnsEMBL::Draw::Style::Feature::Variant;

use base qw(EnsEMBL::Draw::GlyphSet::Simple);

## Hack for backwards compatibility
sub subtitle_height { return 6; }

sub render_normal {
  my $self = shift;
  $self->{'my_config'}->set('bumped', 1);
  $self->{'my_config'}->set('depth', 20);
  return $self->_render;
}

sub render_compact {
  my $self = shift;
  return $self->_render;
}

sub render_labels {
  my $self = shift;

  if ($self->{'container'}->length <= 1e4) {
    $self->{'my_config'}->set('show_labels', 1);
    $self->{'my_config'}->set('bumped', 'labels_alongside');
  }
  return $self->_render;
}

sub render_nolabels {
  my $self = shift;
  $self->{'my_config'}->set('bumped', 1);
  return $self->_render;
}

sub _render {
  my $self = shift;
  $self->{'my_config'}->set('show_overlay', 1);
  $self->{'my_config'}->set('show_subtitle', 1);
  ## Add some extra vertical space for indels
  $self->{'my_config'}->set('extra_height', 8);

  my $data = $self->get_data;
  return unless scalar @{$data->[0]{'features'}||[]};

  my $config = $self->track_style_config;
  my $style  = EnsEMBL::Draw::Style::Feature::Variant->new($config, $data);
  $self->push($style->create_glyphs);
}

sub my_label { 
  my $self  = shift;  
  my $label = $self->type =~ /somatic/ ? 'Somatic Mutations' : 'Variations'; 
  return $label; 
}

sub get_data {
  my $self         = shift;
  my $max_length   = $self->my_config('threshold') || 1000;
  my $slice_length = $self->{'container'}->length;

  my $hub = $self->{'config'}{'hub'};  

  if ($slice_length > $max_length * 1010) {
    $self->errorTrack("Variation features are not displayed for regions larger than ${max_length}Kb");
    return [];
  } else {
    my $features_list = $self->{_data} ||= $hub->get_query('GlyphSet::Variation')->go($self,{
      species => $self->{'config'}{'species'},
      slice => $self->{'container'},
      id => $self->{'my_config'}->id,
      config => [qw(filter source sources sets set_name style no_label)],
      var_db => $self->my_config('db') || 'variation',
      config_type => $self->{'config'}{'type'},
      type => $self->type,
      slice_length => $slice_length,
    });
    if (!scalar(@$features_list)) {
      my $track_name = $self->my_config('name'); 
      $self->errorTrack("No $track_name data for this region");
      return [];
    }
    else {
      ## This is a bit clunky, but we have to pass colour data 
      ## to the drawing module on a per-feature basis
      my $colour_lookup = {};
      my $ok_features   = [];
      foreach (@$features_list) {
        next if $_->{'end'} < 1;
        my $key = $_->{'colour_key'};
        $colour_lookup->{$key} ||= $self->get_colours($_);
        my $colour = $self->{'legend'}{'variation_legend'}{$key} ||= $colour_lookup->{$key}{'feature'};
        $_->{'colour'}        = $colour;
        $_->{'colour_lookup'} = $colour_lookup->{$key};
        $self->{'legend'}{'variation_legend'}{$key} ||= $colour;
        push @$ok_features, $_;
      }
      return [{'features' => $ok_features}];
    }
  }
}

1;
