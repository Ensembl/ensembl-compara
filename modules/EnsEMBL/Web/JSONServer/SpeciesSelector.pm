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
use EnsEMBL::Web::IOWrapper::Indexed;
use EnsEMBL::Web::Utils::FileHandler qw(file_get_contents);

use parent qw(EnsEMBL::Web::JSONServer);

sub object_type {
  my $self = shift;
  return 'SpeciesSelector';
}

sub json_fetch_species {
  my $self    = shift;
  my $hub     = $self->hub;
  my $object  = $self->object;
  my $panel_type = $hub->param('panel_type');
  my $json = {};
  if ($panel_type eq 'Blast') {
    $json = create_json_for_blast($self, $panel_type);
  }

  if (!$json) {
    return {'err', 'Couldn\'t find e_species_division.json file'};
  }
  return { json => $json };
}

sub create_json_for_blast {
  my $self = shift;
  my $hub = $self->hub;
  my $sd = $hub->species_defs;
  my @species_list = $sd->valid_species;
  my $file = $sd->ENSEMBL_SPECIES_SELECT_DIVISION;
  my $division_json = from_json(file_get_contents($file));
  my $json = {};
  my $species_info  = $hub->get_species_info;

  my $available_internal_nodes = get_available_internal_nodes($division_json, $species_info);

  sub json_to_dynatree { 
    my $tree_hash = shift;
    my $species_info = shift;
    my $available_internal_nodes = shift;
    my @dyna_tree = ();
    my @child_nodes = ();
    my $is_strain = 0;
    if ($tree_hash->{child_nodes}) {
      @child_nodes = @{$tree_hash->{child_nodes}};
    }

    if ($tree_hash->{is_leaf}) {
      if($species_info->{$tree_hash->{key}}) {
        my $sp = $species_info->{$tree_hash->{key}};
        my $t = {
          key             => $tree_hash->{key},
          scientific_name => $sp->{scientific},
          title           => $sp->{common} eq 'Mouse' ? 'Mouse (' . $sp->{assembly_version} . ')' : $sp->{common},
          tooltip         => $sp->{scientific} || ''
        };
        if ($sp->{strain} ne '') {
          $t->{isStrain} = "true" ;
          $t->{tooltip} = "Strain: " . $sp->{strain};
        }
        push @dyna_tree, $t;
      }
    }

    if (scalar @child_nodes > 0) {
      my @children = map { json_to_dynatree($_, $species_info, $available_internal_nodes) } @child_nodes;

      if ($available_internal_nodes->{$tree_hash->{display_name}}) {    
        my $t = {
          key      => $tree_hash->{display_name},
          title    => $tree_hash->{display_name},
          children => [ @children ],
          isFolder => 1,
          isInternalNode => $tree_hash->{is_internal_node}
        };
        if(defined $tree_hash->{is_submenu} && $tree_hash->{is_submenu} eq 'true') {
          $t->{is_submenu} = 1;
        }
        push @dyna_tree, $t;
      }
    }


    return @dyna_tree;
  }

  my @dyna_tree = json_to_dynatree($division_json, $species_info, $available_internal_nodes);

  return \@dyna_tree;
}

# Get sub node display names as array to see all available internal nodes
# This is used to remove all paths that doesnt have any child
sub get_available_internal_nodes {
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
