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

package EnsEMBL::Draw::Role::BigWig;

### Module for getting data in BigWIG format (either user-attached, or
### internally configured via an ini file or database record

use strict;

use Role::Tiny;
use List::Util qw(min max);
use Scalar::Util qw(looks_like_number);

use EnsEMBL::Web::File::Utils::IO;
use EnsEMBL::Web::File::Utils::URL;

use EnsEMBL::Web::IOWrapper::Indexed;

sub render_signal {
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Graph::Histogram']);
  $self->{'my_config'}->set('height', 60);
  $self->_render_aggregate;
}

sub render_scatter {
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Plot']);
  $self->{'my_config'}->set('height', 60);
  $self->{'my_config'}->set('filled', 1);
  $self->_render;
}

sub get_data {
  my ($self, $bins, $url) = @_;

  my $data = $self->_fetch_data($bins,$url);

  if ($data) {
    ## Adjust max and min according to track settings
    my @viewLimits = split(':', $self->my_config('viewLimits') || '');
    foreach (@$data) {
      my ($min_score, $max_score);

      ## Prioritise user settings
      if (defined($self->my_config('y_min')) && looks_like_number($self->my_config('y_min'))) {
        $min_score = $self->my_config('y_min');
      }
      if (defined($self->my_config('y_max')) && looks_like_number($self->my_config('y_min'))) {
        $max_score = $self->my_config('y_max');
      }
        
      ## Alternatively use pre-configured limits
      my $signal_range = $self->my_config('signal_range');
      unless (defined $min_score) {
        if (defined $signal_range) {
          $min_score = $signal_range->[0];
        }
        elsif (scalar @viewLimits) {
          $min_score = $viewLimits[0];
        }
      }

      unless (defined $max_score) {
        if (defined $signal_range) {
          $max_score = $signal_range->[1];
        }
        elsif (scalar @viewLimits) {
          $max_score = $viewLimits[1];
        }
      }

      ## Sort out metadata
      if (defined $min_score) {
        $_->{'metadata'}{'y_min'} = $min_score;
      }
      else {
        $min_score = $_->{'metadata'}{'min_score'};
      }
      if (defined $max_score) {
        $_->{'metadata'}{'y_max'} = $max_score;
      }
      else {
        $max_score = $_->{'metadata'}{'max_score'};
      }

      ## Finally constrain to gang range if configured 
      my $gang = $self->gang();
      if ($gang and $gang->{'max'}) {
        $max_score = $gang->{'max'};
      }
      if ($gang and $gang->{'min'}) {
        $min_score = $gang->{'min'};
      }
      $_->{'metadata'}{'max_score'} = $max_score;
      $_->{'metadata'}{'min_score'} = $min_score;
    }

  } else {
    warn "!!! $self: ERROR FETCHING DATA FOR FILE ".$self->my_config('caption')." (BIGWIG FORMAT)";
  }
  #$self->{'config'}->add_to_legend($legend);

  return $data;
}

sub _fetch_data {
### Get the data and cache it
  my ($self, $bins, $url) = @_;
  $bins ||= $self->bins;

  my $hub       = $self->{'config'}->hub;
  $url          ||= $self->my_config('url');

  if (!$url) { ## Internally configured bigwig file?
    my $dba       = $hub->database($self->my_config('type'), $self->species);

    if ($dba) {
      my $dfa = $dba->get_DataFileAdaptor();
      $dfa->global_base_path($hub->species_defs->DATAFILE_BASE_PATH);
      my ($logic_name) = @{$self->my_config('logic_names')||[]};
      my ($df) = @{$dfa->fetch_all_by_logic_name($logic_name)||[]};
      my $paths = $df->get_all_paths;
      $url = $paths->[-1];
    }
  }
  return [] unless $url;

  my $args      = { 'options' => {
                                  'hub'         => $hub,
                                  'config_type' => $self->{'config'}{'type'},
                                  'track'       => $self->{'my_config'}{'id'},
                                  },
                    'default_strand' => 1,
                    };

  my $iow = EnsEMBL::Web::IOWrapper::Indexed::open($url, 'BigWig', $args);
  my $data = [];

  if ($iow) {
    ## We need to pass 'faux' metadata to the ensembl-io wrapper, because
    ## most files won't have explicit colour settings
    my $colour = $self->my_config('colour') || 'slategray';
    $self->{'my_config'}->set('axis_colour', $colour);

    my ($y_min, $y_max);
    if ($self->{'my_config'}{'data'}) {
      $y_min  = $self->{'my_config'}{'data'}{'y_min'};
      $y_max  = $self->{'my_config'}{'data'}{'y_max'};
    }
  
    my ($slice, $whole_chromosome);
    if (ref($self->{'container'}) eq 'Bio::EnsEMBL::Slice') {
      $slice = $self->{'container'};
    }
    elsif ($self->{'container'}{'chr'} && $self->{'container'}{'sa'}) {
      my $adaptor = $self->{'container'}{'sa'};
      $slice      = $adaptor->fetch_by_region('chromosome', $self->{'container'}{'chr'});
      $whole_chromosome = 1;
    }

    my $length = $slice ? $slice->length : $hub->species_defs->MAX_CHR_LENGTH;
    $bins   ||= $self->bins($slice);

    my $metadata = {
                    'name'            => $self->{'my_config'}->get('name'),
                    'colour'          => $colour,
                    'join_colour'     => $colour,
                    'label_colour'    => $colour,
                    'graphType'       => 'bar',
                    'unit'            => $length / $bins,
                    'length'          => $length,
                    'bins'            => $bins,
                    'y_min'           => $y_min,
                    'y_max'           => $y_max,
                    'display'         => $self->{'display'},
                    'no_titles'       => $self->my_config('no_titles'),
                    'default_strand'  => 1,
                    'use_synonyms'    => $hub->species_defs->USE_SEQREGION_SYNONYMS,
                    };
    ## No colour defined in ImageConfig, so fall back to defaults
    unless ($colour) {
      my $colourset_key           = $self->{'my_config'}->get('colourset') || 'userdata';
      my $colourset               = $hub->species_defs->colour($colourset_key);
      my $colours                 = $colourset->{'url'} || $colourset->{'default'};
      $metadata->{'colour'}       = $colours->{'default'};
      $metadata->{'join_colour'}  = $colours->{'join'} || $colours->{'default'};
      $metadata->{'label_colour'} = $colours->{'text'} || $colours->{'default'};
    }

    ## Parse the file, filtering on the current slice
    $data = $iow->create_tracks($slice, $metadata, $whole_chromosome);
    # Don't cache here, it's not properly managed. Rely on main cache layer.
    return $data;
  }
  else {
    $self->errorTrack(sprintf 'Could not read file %s', $self->my_config('caption'));
    return [];
  }
}

sub bins {
### Set number of bins for summary - will typically be around 1000 for region in detail or 150 on whole chromosomes
### @return Integer
  my ($self, $slice) = @_;

  if(!$self->{'_bins'}) {
    $self->{'_bins'} = $slice ? min($self->{'config'}->image_width, $self->{'container'}->length) : 150;
  }
  return $self->{'_bins'};
}

sub gang_prepare {
  my ($self, $gang) = @_;

  my $data = $self->_fetch_data;

  foreach (@$data) {
    my $max = $_->{'metadata'}{'max_score'};
    $gang->{'max'} = max($gang->{'max'}||0, $max);
  }
}

1;
