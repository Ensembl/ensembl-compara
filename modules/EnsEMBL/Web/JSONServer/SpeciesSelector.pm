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

sub create_tree {
  my $self = shift;
  my $division_json = $self->{species_selector_data}->{division_json};

  my @nodes = map { $self->traverse($_) } @{$division_json->{child_nodes}};
  my $final = create_node($division_json, 1, 1);
  $final->{children} = [@nodes];
  return $final;
}

# Traverse through the ensembl taxonomy divisions and create the dynatree json
sub traverse() {
  my $self = shift;
  my $node = shift;
  my @tree;
  my $species_is_available = $self->{species_selector_data}->{available_species}->{$node->{key}} ? 1 : 0;
  my $value = $self->{species_selector_data}->{available_species}->{$node->{key}};

  if ($node->{is_leaf} && $species_is_available) {
    $node->{value} = $value if $value;
    if ($self->{species_selector_data}->{extras} && $self->{species_selector_data}->{extras}->{$node->{key}}) {
      # create folder for special types like human self alignments
      map { push @{$node->{children}}, @$_ } create_folder_for_special_types($node, $self->{species_selector_data}->{extras}->{$node->{key}}, $self->{species_selector_data}->{internal_node_select});
    }
    return create_node($node, 1);
  }
  else {
    if ($node->{child_nodes}) {
      my @children;
      my $type;
      my $other_types;
      my $assembly_group;

      my @child_nodes = $node->{child_nodes};

      foreach (@{$node->{child_nodes}}) {
        if ($_->{type}) { # for strains and stuff that could come from configpacker
          push @{$type->{$_->{type}}}, $self->traverse($_);
        }
        elsif ($self->{species_selector_data}->{sp_assembly_map} &&
               $self->{species_selector_data}->{sp_assembly_map}->{$_->{common_name} || $_->{key}} &&
               scalar @{$self->{species_selector_data}->{sp_assembly_map}->{$_->{common_name} || $_->{key}}} > 1 &&
               $_->{display_name} !~/reference/) {
          # Group same species but different assemblies
          push @{$assembly_group->{$_->{common_name}}}, $self->traverse($_);
        }
        else {
          # normal internal node as defined in the e_divisions.json template
          push @children, $self->traverse($_);
        }
      }
      if (scalar keys %$type > 0) {
        map { push @children, @$_ } $self->create_children_for_types($type);
      }

      if (scalar keys %$assembly_group > 0) {
        map { push @children, @$_ } $self->create_children_for_types($assembly_group);
      }

      # Sorting
      if (!$node->{is_submenu}) {
        # Bring Human and Mouse reference to the top of the list and sort the rest alphabetically
        my @ch_arr1 = grep { $_->{key} =~/Homo_sapiens$|Mus_musculus$/ } @children;
        my @ch_arr2 = grep { $_->{key} !~/Homo_sapiens$|Mus_musculus$/ } sort {$a->{title} cmp $b->{title}} @children;
        @children = (@ch_arr1, @ch_arr2);
      }

      if ($#children >= 0) {
        my $obj = {
          key => $node->{key},
          title    => $node->{display_name},
          isFolder => 1,
          is_submenu => $node->{is_submenu},
          isInternalNode => $node->{is_internal_node},
          hideCheckbox => $node->{hideCheckbox},
          children => [@children],
        };
        if (!$self->{species_selector_data}->{internal_node_select}) {
          $obj->{hideCheckbox} = $obj->{unselectable} = 1;
        }
        push @tree, $obj;
      }
    }
  }
  return @tree;
}

# Returns a dynatree style node/branch
sub create_node {
  my $n = shift;
  my $searchable = shift || 0;
  my $isFolder = shift || 0;

  my $obj = { 
    key        => $n->{key} || '',
    scientific_name => $n->{scientific_name} || '',
    title           => $n->{display_name} || $n->{scientific_name} || '',
    tooltip         => $n->{scientific_name} || '',
    searchable => $searchable,
    img_url => ($n->{image} ? '/i/species/' . $n->{image} : '/img/e_bang') . '.png',
    isFolder => $isFolder,
    children => $n->{children} && scalar @{$n->{children}} > 0 ? $n->{children} : [],
    value => $n->{value} || '',
    special_type => $n->{parent_node_species} ? $n->{parent_node_species} : ''  # for human self alignment folder, parent node species will be human
  };

  $obj->{unselectable} = $n->{unselectable} if ($n->{unselectable});
  $obj->{hideCheckbox} = $n->{hideCheckbox} if ($n->{hideCheckbox});
  return $obj;

}

# Create child nodes for different types such as
# strains that is generated in Configpacker and
# same species but different assemblies grouping
sub create_children_for_types {
  my $self = shift;
  my $type = shift;
  my $internal_node_select = $self->{species_selector_data}->{internal_node_select};
  my $children = [];
  foreach (keys %$type) {
    if (scalar @{$type->{$_}} > 0) { # Create only if children are present
      if ($_ !~ /Mouse/) {
        push @$children, {
          key => $_,
          title => ucfirst($_),
          isFolder => 1,
          unselectable => !!!$internal_node_select,
          hideCheckbox => !!!$internal_node_select,
          children => $type->{$_}
        };
      }
      else {
        push @$children, @{$type->{$_}};
      }
    }
  }
  return $children;
}

# Create child nodes for different types such as
# haplotypes and patches coming from Region comparison
# primary assembly or self alignments coming from Region comparison
sub create_folder_for_special_types {
  my $parent_node = shift;   # e.g. Homo_sapiens for Human Primary assembly folder
  my $special_type_data = shift;
  my $internal_node_select = shift;
  my $extra_dyna = [];
  my $children = [];

  foreach my $k (keys %$special_type_data) {
    $children = [];
    # For sorting based on chromosome numbers
    my @extras_data_array;
    if ($k =~ /primary assembly/i) {
      @extras_data_array = sort {$a->{assembly_target} <=> $b->{assembly_target}} @{$special_type_data->{$k}->{data}};
    }
    else {
      @extras_data_array = sort {$a->{display_name} cmp $b->{display_name}} @{$special_type_data->{$k}->{data}};
    }

    foreach my $n_data (@extras_data_array) {
      $n_data->{parent_node_species} = $parent_node->{key};
      push @$children, create_node($n_data, 1);
    }

    if (scalar @$children > 0) {
      # Create folder if opted
      if ($special_type_data->{$k}->{create_folder} == 1) {
        my $folder = {};
        $folder->{key}          = $k;
        $folder->{title}        = ucfirst($k);
        $folder->{isFolder}     = 1;
        $folder->{children}     = [];
        $folder->{searchable}   = 0;
        push @{$folder->{children}}, @$children;
        push @$extra_dyna, $folder;
      }
      else {
        push @$extra_dyna, @$children;
      }
    }
  }
  return $extra_dyna;
}

1;
