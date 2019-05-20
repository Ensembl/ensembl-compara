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

  my $ic_type = $hub->param('ictype');
  my $species = $hub->param('th_species');
  my $menu    = $hub->param('submenu');
  my $tree    = $hub->get_imageconfig({type => $ic_type, species => $species});
  return {} unless ($menu && $tree);

  my $node = $tree->get_node($menu);
  return {} unless $node;

  my $metadata = {};
  while (my ($k, $v) = each (%{$node->data})) {
    if ($k eq 'shortLabel' || $k eq 'dimensions') {
      $metadata->{$k} = $v;
    }
    elsif ($k =~ /subGroup/) {
      my $k2 = $v->{'name'};
      delete($v->{'name'});
      $metadata->{$k2} = $v;
    }
  }

  my $tracks = [];
  ## Only use the fields we need to draw the matrix, to prevent the JSON becoming too large
  my @fields = qw(track shortLabel longLabel subGroups format display default_display);
  foreach my $child (@{$node->child_nodes||[]}) {
    my $hash = {'id' => $child->id};
    foreach (@fields) {
      $hash->{$_} = $child->data->{$_} if defined $child->data->{$_};
    }
    push @$tracks, $hash;
  }

  my $data = {
    'metadata' => $metadata,
    'tracks'   => $tracks
  };
  #use Data::Dumper;
  #$Data::Dumper::Sortkeys = 1;
  #$Data::Dumper::Maxdepth = 2;
  #warn Dumper($data);
  return $data;
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

