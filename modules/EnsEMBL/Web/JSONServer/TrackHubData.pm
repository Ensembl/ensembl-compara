=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::JSONServer::TrackHubData;

### Convert a parsed trackhub into JSON that can be used by the new interface

use strict;
use warnings;

use JSON;

use EnsEMBL::Web::Utils::TrackHub;
use EnsEMBL::Web::Utils::Sanitize qw(strip_HTML);

use parent qw(EnsEMBL::Web::JSONServer);

sub json_data {
  my $self = shift;
  my $hub  = $self->hub;

  my $record_id = $hub->param('record');
  return {} unless $record_id;
  (my $code = $record_id) =~ s/^url_//;

  my $record;
  foreach my $m (grep $_, $hub->user, $hub->session) {
    $record = $m->get_record_data({'type' => 'url', 'code' => $code});
    last if ($record && keys %$record);
  }
  my $url = $record->{'url'};
  return {} unless $url;

  my $trackhub  = EnsEMBL::Web::Utils::TrackHub->new('hub' => $self->hub, 'url' => $url);
  my $hub_info = $trackhub->get_hub({'parse_tracks' => 1, 'make_tree' => 1}); 
  $self->{'th_default_count'} = 0;


  ## Get the track tree for this genome
  my $tree;
  my $assemblies = $hub->species_defs->get_config($hub->param('species'), 'TRACKHUB_ASSEMBLY_ALIASES');
  $assemblies ||= [];
  $assemblies = [ $assemblies ] unless ref($assemblies) eq 'ARRAY';
  foreach (qw(UCSC_GOLDEN_PATH ASSEMBLY_VERSION ASSEMBLY_NAME)) {
    my $assembly = $hub->species_defs->get_config($hub->param('species'), $_);
    next unless $assembly;
    push @$assemblies,$assembly;
  }
  foreach my $assembly (@$assemblies) {
    $tree = $hub_info->{'genomes'}{$assembly}{'tree'};
    $tree = $tree->root if $tree;
    last if $tree;
  }
  return {} unless $tree;

  ## Now process the raw data into something we can use!
  my $tracks = [];
  $self->process_tree($tree, $tracks);

  #use Data::Dumper;
  #$Data::Dumper::Sortkeys = 1;
  #$Data::Dumper::Maxdepth = 3;
  #warn Dumper($tracks);

  return {hub_data => $tracks};
}

our $style_mappings = {
                          'bam'     => {
                                        'default' => 'coverage_with_reads',
                                        },
                          'cram'    => {
                                        'default' => 'coverage_with_reads',
                                        },
                          'bigbed'  => {
                                        'full'    => 'as_transcript_nolabel',
                                        'pack'    => 'as_transcript_label',
                                        'squish'  => 'half_height',
                                        'dense'   => 'as_alignment_nolabel',
                                        'default' => 'as_transcript_label',
                                        },
                          'biggenepred' => {
                                        'full'    => 'as_transcript_nolabel',
                                        'pack'    => 'as_transcript_label',
                                        'squish'  => 'half_height',
                                        'dense'   => 'as_collapsed_label',
                                        'default' => 'as_collapsed_label',
                                        },
                          'bigwig'  => {
                                        'full'    => 'signal',
                                        'dense'   => 'compact',
                                        'default' => 'compact',
                                        },
                          'vcf'     =>  {
                                        'full'    => 'histogram',
                                        'dense'   => 'compact',
                                        'default' => 'compact',
                                        },

};

sub process_tree {
  my ($self, $node, $tracks, $inherited) = @_;
  $inherited ||= {};

  my @inheritable = qw(on_off visibility viewLimits maxHeightPixels);
  my $data = {};
  
  if ($node->has_child_nodes) {
    foreach my $child (@{$node->child_nodes}) {
      $data = $child->data;
      my $inherit = {};
      foreach (@inheritable) {
        $inherit->{$_} = $data->{$_} if defined $data->{$_};
      }
      $self->process_tree($child, $tracks, $inherit);
    }
  }
  else {
    $data = $node->data;
    ## Overwrite inherited values
    while (my($k, $v) = each (%$inherited)) {
      $data->{$k} = $v if defined $v;
    }
    $data->{'shortLabel'} = strip_HTML($data->{'shortLabel'});
    ## Translate between UCSC terms and Ensembl ones
    $data->{'on_off'} = $data->{'visibility'} eq 'hide' ? 'off' : 'on';
    my $default = $style_mappings->{$data->{'type'}}{$data->{'visibility'}}
                  || $style_mappings->{$data->{'type'}}{'default'}
                  || 'normal';
    $data->{'default'} = $default;
    delete($data->{'visibility'});
    ## OK, done!
    push @$tracks, $data;
  }
}

  # TODO - build dimensions in JavaScript
  # my ($dimX, $dimY);
  # my $dimLabels = {};
  # foreach my $track (@{$data||[]}) {
  #   if ($track->{'dimensions'} && !@{$final->{'dimensions'}||[]}) {
  #     ## We only need this information once
  #     $dimX = $track->{'dimensions'}{'x'};
  #     $dimY = $track->{'dimensions'}{'y'};
  #     ## Create a lookup for all the dimensions' individual values
  #     my %combined_hash = (%{$track->{'subGroup1'}}, %{$track->{'subGroup2'}});
  #     while (my($k, $v) = each (%combined_hash)) {
  #       ## Skip the information about the dimensions themselves
  #       next if ($k eq 'name' || $k eq 'label');
  #       (my $pretty_label = $v) =~ s/_/ /g;
  #       $dimLabels->{$k} = $pretty_label;
  #     }

  #     $final->{'dimensions'} = [$dimX, $dimY];
  #     $final->{'data'}{$dimX}{'name'}     = $dimX;
  #     $final->{'data'}{$dimX}{'label'}    = $track->{'subGroup1'}{'label'};
  #     $final->{'data'}{$dimX}{'listType'} = 'simpleList';
  #     $final->{'data'}{$dimX}{'data'}     = {};
  #     $final->{'data'}{$dimY}{'name'}     = $dimY;
  #     $final->{'data'}{$dimY}{'label'}    = $track->{'subGroup2'}{'label'};
  #     $final->{'data'}{$dimY}{'listType'} = 'simpleList';
  #     $final->{'data'}{$dimY}{'data'}     = {};
  #   }
  #   elsif ($track->{'bigDataUrl'}) {
  #     ## Only add tracks that are displayable, i.e. not superTracks/composites/etc
  #     my $keyX    = $track->{'subGroups'}{$dimX};
  #     my $keyY    = $track->{'subGroups'}{$dimY};
  #     my $labelX  = $dimLabels->{$keyX};
  #     my $labelY  = $dimLabels->{$keyY};

  #     push @{$final->{'data'}{$dimX}{'data'}{$keyX}}, {'dimension' => $dimY, 'val' => $keyY, 'defaultState' => 'track-'.$track->{'on_off'}};
  #     push @{$final->{'data'}{$dimY}{'data'}{$keyY}}, $keyX;
  #   }
  # }

  # ## Adjust interface based on number of values in dimensions
  # if (scalar keys %{$final->{'data'}{$dimX}{'data'}} > 20) {
  #   $final->{'data'}{$dimX}{'listType'} = 'alphabetRibbon';
  # }
  # if (scalar keys %{$final->{'data'}{$dimY}{'data'}} > 20) {
  #   $final->{'data'}{$dimY}{'listType'} = 'alphabetRibbon';
  # }

1;

