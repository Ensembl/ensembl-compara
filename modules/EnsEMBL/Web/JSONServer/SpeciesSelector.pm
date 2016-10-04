=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::JSONServer::SpeciesSelector;

use strict;
use warnings;
use JSON;
use List::MoreUtils qw/ uniq /;
use URI::Escape qw(uri_escape);
use HTML::Entities qw(encode_entities);
use EnsEMBL::Web::IOWrapper::Indexed;

use parent qw(EnsEMBL::Web::JSONServer);

sub init {
  my $self    = shift;
  my $hub     = $self->hub;
  my $panel_type = $hub->param('panel_type');
}

sub json_to_dynatree {
  my $self = shift;
  my $division_hash = shift;
  my $species_info = shift;
  my $available_internal_nodes = shift;
  my $internal_node_select = shift;
  my $extras = shift || {};
  my @dyna_tree = ();
  my @child_nodes = ();

  if ($division_hash->{child_nodes}) {
    @child_nodes = @{$division_hash->{child_nodes}};
  }

  if ($division_hash->{is_leaf}) {
    if($species_info->{$division_hash->{key}}) {
      my $sp = $species_info->{$division_hash->{key}};

      my $t = {
        key             => $division_hash->{key},
        scientific_name => $sp->{scientific},
        title           => $sp->{common} . ' ' . $sp->{strain},
        tooltip         => $sp->{scientific} || '',
        searchable      => 1,
        icon            => '/i/species/16/' . $sp->{key} . '.png'
      };
      if ($sp->{strain} && $sp->{strain} ne '') {
        $t->{isStrain} = "true" ;
        $t->{tooltip}  = "Strain: " . $sp->{strain};
      }
      if ($sp->{value}) {
        $t->{value}    = $sp->{value};
      }


      # Add extra groups like strains / haplotypes_and_patches etc
      if($extras->{$division_hash->{key}} or ($division_hash->{extras_key} && $extras->{$division_hash->{extras_key}})) {
        my $extra_dyna = get_extras_as_dynatree($division_hash->{key}, $extras->{$division_hash->{key}}, $internal_node_select);
        $t->{isFolder} = 1;
        $t->{searchable} = 1;
        # Make it unselectable if it is not in the available species_list
        # $t->{unselectable} = 1 if (!$sp->{$division_hash->{key}});
        $t->{children} = $extra_dyna;
      }

      push @dyna_tree, $t;

    }
  }

  if (scalar @child_nodes > 0) {
    my @children = map { $self->json_to_dynatree($_, $species_info, $available_internal_nodes, $internal_node_select, $extras) } @child_nodes;
    if ($available_internal_nodes->{$division_hash->{display_name}}) {
      my $t = {
        key            => $division_hash->{display_name},
        title          => $division_hash->{display_name},
        children       => [ @children ],
        isFolder       => 1,
        searchable     => 1,
        # Get a display tree starting from the first internal node on a bottom up search
        isInternalNode => $division_hash->{is_internal_node},
        unselectable   => !$internal_node_select
      };
      if(defined $division_hash->{is_submenu} && $division_hash->{is_submenu} eq 'true') {
        $t->{is_submenu} = 1;
      }

      # Add extra groups like strains / haplotypes_and_patches etc
      my $x = $extras->{$division_hash->{key}} || ($division_hash->{extras_key} ? $extras->{$division_hash->{extras_key}} : '');
      if($x) {
        my $extra_dyna = get_extras_as_dynatree($division_hash->{key}, $x, $internal_node_select);
        $t->{isFolder} = 1;
        $t->{searchable} = 1;
        push @{$t->{children}}, @$extra_dyna;
      }
      push @dyna_tree, $t;
    }
  }

  return @dyna_tree;
}

sub get_extras_as_dynatree {
  my $species = shift;
  my $extras = shift;
  my $internal_node_select = shift;
  my $extra_dyna = [];

  foreach my $k (keys %$extras) {
    my $folder = {};
    $folder->{key}          = $k;
    $folder->{title}        = ucfirst($k);
    $folder->{isFolder}     = 1;
    $folder->{children}     = [];
    $folder->{searchable}   = 0;
    $folder->{unselectable} = !$internal_node_select;
    foreach my $hash (@{$extras->{$k}}) {
      my $icon = '';
      if ($k =~/haplotype/ and $hash->{key} =~/--/) {
        my ($sp, $type) = split('--', $hash->{key});
        $icon = '/i/species/16/' . $sp . '.png';        
      }
      else {
        $icon = '/i/species/16/' . $hash->{key} . '.png';        
      }

      my $t = {
        key             => $hash->{scientific},
        scientific_name => $hash->{scientific},
        title           => $hash->{common},
        tooltip         => $k . ': ' . $hash->{common},
        extra           => 1, # used to get image file of the parent node, say for a haplotype
        searchable      => 1,
        icon            => $icon
      };
      push @{$folder->{children}}, $t;
    }

    push @$extra_dyna, $folder;

  }
  return $extra_dyna;
}

# Get sub node display names as array to see all available internal nodes
# This is used to remove all paths that doesnt have any child
sub get_available_internal_nodes {
  my $self = shift;
  my $json = shift;
  my $species_info = shift;
  my $available_paths = {};

  foreach my $key (%$species_info) {
    my $path = get_path($key, $json);
    if ($path) {
      foreach my $p (split(',', $path)){
        $available_paths->{$p}++;
      }
    }
  }
  return $available_paths;
}

sub get_path {
  my $key = shift;
  my $node = shift;
  my $path = '';

  sub search {
    my ($path, $obj, $target) = @_;
    if (defined $obj->{key} && $obj->{key} eq $target) {
      if (defined $obj->{is_submenu}) {
        $path .= $obj->{key};
      }
      return $path;
    }
    if ($obj->{child_nodes}) {
      $path .= $obj->{display_name} . ',';
      foreach my $child (@{$obj->{child_nodes}}) {
        my $result = search($path, $child, $target);
        if ($result) {
          return $result;
        }
      }
    }
    return '';
  }
  $path = search($path, $node, $key);
  $path =~s/,$//g;
  return $path;
}

1;
