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

package EnsEMBL::Draw::GlyphSet::vcf;

### Module for drawing data in VCF format (either user-attached, or
### internally configured via an ini file or database record

use strict;
no warnings 'uninitialized';

use List::Util qw(max);

use Role::Tiny::With;
with 'EnsEMBL::Draw::Role::Default';
with 'EnsEMBL::Draw::Role::Wiggle';

use EnsEMBL::Web::IOWrapper::Indexed;

use parent qw(EnsEMBL::Draw::GlyphSet::UserData);

sub init {
  my $self = shift;

  ## Cache raw VCF features
  $self->{'data'} = $self->get_data;
}

############# RENDERING ########################

sub render_histogram {
  my $self = shift;
  my $features = $self->get_data->[0]{'features'};
  if ($features) {
    return scalar @$features > 200 ? $self->render_density_bar : $self->render_simple;
  }
  else {
    $self->no_features;
  }
}

sub render_simple {
  my $self = shift;
  my $features = $self->get_data->[0]{'features'};
  if ($features) {
    if (scalar @$features > 200) {
      $self->too_many_features;
      return undef;
    }
    else {
      ## Convert raw features into correct data format 
      $self->{'my_config'}->set('height', 12);
      $self->{'my_config'}->set('show_overlay', 1);
      $self->{'my_config'}->set('default_strand', 1);
      $self->{'my_config'}->set('drawing_style', ['Feature::Variant']);
      $self->draw_features;
    }
  }
  else {
    $self->no_features;
  }
}

sub render_density_bar {
  my $self        = shift;
  $self->{'my_config'}->set('height', 20);
  $self->{'my_config'}->set('no_guidelines', 1);
  $self->{'my_config'}->set('integer_score', 1);
  my $colours = $self->species_defs->colour('variation');
  $self->{'my_config'}->set('colour', $colours->{'default'}->{'default'});

  ## Convert raw features into correct data format 
  my $density_features = $self->density_features;
  if ($density_features) {
    $self->{'data'}[0]{'features'} = $density_features;
    $self->{'my_config'}->set('max_score', max(@$density_features));
    $self->{'my_config'}->set('drawing_style', ['Graph::Histogram']);
    $self->_render_aggregate;
  }
  else {
    $self->no_features;
  }

}

############# DATA ACCESS & PROCESSING ########################

sub get_data {
  my ($self, $url) = @_;
  return $self->{'data'} if scalar @{$self->{'data'}||[]};
  my $hub         = $self->{'config'}->hub;
  $url          ||= $self->my_config('url');
  my $container   = $self->{'container'};
  my $data        = [];

  my ($skip, $strand_to_omit) = $self->get_strand_filters;
  return $data if $skip == $self->strand;

  my $args            = { 'options' => {
                                  'hub'         => $hub,
                                  'config_type' => $self->{'config'}{'type'},
                                  'track'       => $self->{'my_config'}{'id'},
                                  },
                        };

  my $iow = $self->get_iow($url, $args);

  if ($iow) {
    ## We need to pass 'faux' metadata to the ensembl-io wrapper, because
    ## most files won't have explicit colour settings
    my $colours = $self->species_defs->colour('variation');
    my $colour  = $colours->{'default'}->{'default'}; 
    ## Don't try and scale if we're just doing a zmenu!
    my $pix_per_bp = $self->{'display'} eq 'text' ? '' : $self->scalex;
    my $metadata = {
                    'action'          => $self->{'my_config'}->get('zmenu_action'),
                    'colour'          => $colour,
                    'display'         => $self->{'display'},
                    'drawn_strand'    => $self->strand,
                    'strand_to_omit'  => $strand_to_omit,
                    'pix_per_bp'      => $pix_per_bp,
                    'use_synonyms'    => $hub->species_defs->USE_SEQREGION_SYNONYMS,
                    };

    ## No colour defined in ImageConfig, so fall back to defaults
    unless ($colour) {
      my $colourset_key           = $self->{'my_config'}->get('colourset') || 'userdata';
      my $colourset               = $hub->species_defs->colour($colourset_key);
      my $colours                 = $colourset->{'url'} || $colourset->{'default'};
      $metadata->{'colour'}       = $colours->{'default'};
      $metadata->{'label_colour'} = $colours->{'text'} || $colours->{'default'};
    }

    my $style = $self->my_config('style') || $self->my_config('display') || '';

    $data = $iow->create_tracks($container, $metadata);

    ## Final fallback, in case we didn't set this in the individual parser
    $metadata->{'label_colour'} ||= $colour;

    ## Can we actually render this many features?
    my $total;
    foreach (@$data) {
      $total += scalar @{$_->{'features'}||[]};
    }

    my $limit = $self->{'my_config'}->get('bigbed_limit') || 500;
    if ($total > $limit) {
      $data = [];
      $self->{'no_empty_track_message'}  = 1;
      $self->errorTrack('This track has too many features to show at this scale. Please zoom in.');
    }
  } else {
    $data = [];
    $self->errorTrack(sprintf 'Could not read file %s', $self->my_config('caption'));
  }
  #warn Dumper($data->[0]{'features'});
  return $data;
}

sub get_iow {
  my ($self, $url, $args) = @_;
  return EnsEMBL::Web::IOWrapper::Indexed::open($url, 'VCF4Tabix', $args);
}


sub density_features {
### Merge the features into bins
### @return Arrayref of hashes
  my $self     = shift;
  my $slice    = $self->{'container'};
  my $start    = $slice->start - 1;
  my $length   = $slice->length;
  my $im_width = $self->{'config'}->image_width;
  my $divlen   = $length / $im_width;
  $self->{'data'}[0]{'metadata'}{'unit'} = $divlen;
  ## Prepopulate bins, as histogram requires data at every point
  my %density  = map {$_, 0} (1..$im_width);
  foreach (@{$self->{'data'}[0]{'features'}}) {
    my $key = $_->{'start'} / $divlen;
    $density{int($_->{'start'} / $divlen)}++;
  }

  my $density_features = [];
  foreach (sort {$a <=> $b} keys %density) {
    push @$density_features, $density{$_};
  }
  return $density_features;
}

1;
