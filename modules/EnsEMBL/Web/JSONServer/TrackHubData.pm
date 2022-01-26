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
  my $menu    = $hub->param('menu');
  my $tree    = $hub->get_imageconfig({type => $ic_type, species => $species});
  return {} unless ($menu && $tree);

  my $node = $tree->get_node($menu);
  return {} unless $node;

  my $metadata = {};
  my %ok_dimensions;
  while (my ($k, $v) = each (%{$node->data})) {
    if ($k eq 'shortLabel' || $k eq 'dimensions' || $k eq 'dimLookup') {
      $metadata->{$k} = $v;
    }
    if ($k eq 'dimensions') {
      %ok_dimensions = map {$v->{$_}{'key'} => 1} keys %$v; 
    }
  }

  my $tracks = [];
  ## Only use the fields we need to draw the matrix, to prevent the JSON becoming too large
  my @fields = qw(track shortLabel longLabel subGroups format display);
  foreach my $child (@{$node->child_nodes||[]}) {
    my $hash = {'id' => $child->id};
    foreach (@fields) {
      $hash->{$_} = $child->data->{$_} if defined $child->data->{$_};
    }
    ## Remove unused subgroups, because Blueprint
    while (my ($k, $v) = each(%{$hash->{'subGroups'}||{}})) {
      delete $hash->{'subGroups'}{$k} unless $ok_dimensions{$k};
    } 
    ## Change case on default_display because of JS dot notation
    $hash->{'defaultDisplay'} = $child->data->{'default_display'};
    push @$tracks, $hash;
  }

  my $data = {
    'metadata' => $metadata,
    'tracks'   => $tracks
  };
  return $data;
}

1;

