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

package EnsEMBL::Draw::GlyphSet::bigbed;

### Module for drawing data in BigBED format (either user-attached, or
### internally configured via an ini file or database record

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::IOWrapper::Indexed;

use parent qw(EnsEMBL::Draw::GlyphSet::UserData);

sub can_json { return 1; }

# Overridden in some regulation tracks, as it's not always this simple
sub my_url { return $_[0]->my_config('url'); }

sub get_data {
  my ($self, $url, $track_metadata) = @_;
  return $self->{'data'} if scalar @{$self->{'data'}||[]};

  $track_metadata ||= {};
  my $hub         = $self->{'config'}->hub;
  $url          ||= $self->my_url;
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
    my $colour = $track_metadata->{'colour'} || $self->my_config('colour');
    ## Don't try and scale if we're just doing a zmenu!
    my $pix_per_bp = $self->{'display'} eq 'text' ? '' : $self->scalex;
    my $metadata = {
                    'action'          => $self->{'my_config'}->get('zmenu_action'), 
                    'colour'          => $colour,
                    'display'         => $self->{'display'},
                    'drawn_strand'    => $self->strand,
                    'strand_to_omit'  => $strand_to_omit,
                    'pix_per_bp'      => $pix_per_bp,
                    'spectrum'        => $self->{'my_config'}->get('spectrum'),
                    'colorByStrand'   => $self->{'my_config'}->get('colorByStrand'),
                    'use_synonyms'    => $hub->species_defs->USE_SEQREGION_SYNONYMS,
                    'link_template'   => $self->{'my_config'}->get('link_template'),
                    'link_label'      => $self->{'my_config'}->get('link_label'),
                    'zmenu_extras'    => $self->{'my_config'}->get('zmenu_extras'), 
                    'custom_fields'   => $self->{'my_config'}->get('custom_fields'), 
                    };

    ## Also set a default gradient in case we need it
    my @gradient = $iow->create_gradient([qw(yellow green blue)]);
    $metadata->{'default_gradient'} = \@gradient;

    ## No colour defined in ImageConfig, so fall back to defaults
    unless ($colour) {
      my $colourset_key           = $self->{'my_config'}->get('colourset') || 'userdata';
      my $colourset               = $hub->species_defs->colour($colourset_key);
      my $colours                 = $colourset->{'url'} || $colourset->{'default'};
      $metadata->{'colour'}       = $colours->{'default'};
      $metadata->{'join_colour'}  = $colours->{'join'} || $colours->{'default'};
      $metadata->{'label_colour'} = $colours->{'text'} || $colours->{'default'};
    }

    ## Omit individual feature links if this glyphset has a clickable background
    #$metadata->{'omit_feature_links'} = 1 if $self->can('bg_link');

    ## Some, very compact, zoomed-out styles only need a few of the
    ## features. We need to make sure that they receive no more than these
    ## as to attempt to retrieve them all causes us to run out of memory.
    ## There should maybe be an API for this. But without this optimisation,
    ## for example, Age of Base takes nearly a minute to render at 600kb
    ## and makes the apache worker large enough that it's then retired.
    my $style = $self->my_config('style') || $self->my_config('display') || '';
    ## Parse the file, filtering on the current slice
    $metadata->{'skip_overlap'} = ($style eq 'compact');

    $self->extra_metadata($metadata);

    $data = $iow->create_tracks($container, $metadata);

    ## Final fallback, in case we didn't set these in the individual parser
    $metadata->{'label_colour'} ||= $colour;
    $metadata->{'join_colour'} ||= $colour;

    ## Can we actually render this many features?
    my $total;
    foreach (@$data) {
      $total += scalar @{$_->{'features'}||[]};
    }

    my $limit = $self->{'my_config'}->get('bigbed_limit') || 500;
    if ($total > $limit) {
      $self->{'data'} = [];
      $self->{'no_empty_track_message'}  = 1;
      return $self->errorTrack('This track has too many features to show at this scale. Please zoom in.');
    }

    #use Data::Dumper; warn Dumper($data);
  } else {
    $self->{'data'} = [];
    return $self->errorTrack(sprintf 'Could not read file %s', $self->my_config('caption'));
  }
  #$self->{'config'}->add_to_legend($legend);

  return $data;
}

sub get_iow { 
  my ($self, $url, $args) = @_;
  return EnsEMBL::Web::IOWrapper::Indexed::open($url, 'BigBed', $args); 
} 
 
sub extra_metadata {}
 
sub render_as_alignment_nolabel {
  my $self = shift;
  $self->{'my_config'}->set('depth', 20);
  $self->draw_features;
}
 
sub render_as_alignment_label {
  my $self = shift;
  $self->{'my_config'}->set('depth', 20);
  $self->{'my_config'}->set('show_labels', 1);
  $self->draw_features;
}

sub render_compact {
  my $self = shift;
  $self->{'my_config'}->set('depth', 0);
  $self->{'my_config'}->set('no_join', 1);
  $self->draw_features;
}

sub render_signal {
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Graph::Bar']);
  $self->{'my_config'}->set('height', 60);
  $self->_render_aggregate;
}

sub render_as_transcript_nolabel {
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Feature::Transcript']);
  $self->{'my_config'}->set('height', 8);
  $self->{'my_config'}->set('depth', 20);
  $self->draw_features;
}

sub render_as_transcript_label {
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Feature::Transcript']);
  $self->{'my_config'}->set('height', 8);
  $self->{'my_config'}->set('depth', 20);
  $self->{'my_config'}->set('show_labels', 1);
  $self->draw_features;
}

sub render_text { warn "No text renderer for bigbed\n"; return ''; }

1;

