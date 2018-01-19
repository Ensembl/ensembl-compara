=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

sub simpletree {
  my $self = shift;
  my $division_hash = shift;
  my $species_info = shift;
  my $available_internal_nodes = shift;
  my $internal_node_select = shift;
  my $extras = shift || {};
  my $sp_assembly_map = shift || {};
  my @nodes = map { traverse($_) } @{$division_hash->{child_nodes}}; 
# print Data::Dumper::Dumper $division_hash;

  my $final = create_node($division_hash, 1, 1);
  $final->{children} = [@nodes];
  return $final;

  sub traverse() {
    my $node = shift;
    my @tree;

    if ($node->{is_leaf}) {
      my $t = $node;

      if ($extras->{$_->{key}}) {
        map { push @{$t->{children}}, @$_ } create_folder_for_special_types($extras->{$_->{key}});
      }
      return create_node($t, 1);

    }
    else {
      if ($node->{child_nodes}) {
        my @children;
        my $type;
        my $other_types;
        my $assembly_group;
        foreach (@{$node->{child_nodes}}) {
          if ($_->{type}) {
            push @{$type->{$_->{type}}}, traverse($_);
          }
          elsif ($sp_assembly_map->{$_->{scientific_name}} && scalar @{$sp_assembly_map->{$_->{scientific_name}}} > 1) {
            # Group same species but different assemblies
            # print  Data::Dumper::Dumper $_;
            push @{$assembly_group->{$_->{scientific_name}}}, traverse($_);
          }
          else {
            push @children, traverse($_);
          }
        }

        if (scalar keys %$type > 0) {
          map { push @children, @$_ } create_children_for_types($type);
        }

        if (scalar keys %$assembly_group > 0) {
# print Data::Dumper::Dumper $assembly_group;
          map { push @children, @$_ } create_children_for_types($assembly_group);
        }

        push @tree, {
          key => $node->{key},
          title    => $node->{display_name},
          isFolder => 1,
          is_submenu => $node->{is_submenu},
          isInternalNode => $node->{is_internal_node},
          children => [@children]
        };
      }
    }
    return @tree;
  }
}

sub create_node {
  my $n = shift;
  my $searchable = shift || 0;
  my $isFolder = shift || 0;

  return { 
    key        => $n->{key} || '',
    scientific_name => $n->{key} || '',
    title           => $n->{display_name} || $n->{scientific_name} || '',
    tooltip         => $n->{scientific_name} || '',
    searchable => $searchable,
    isFolder => $isFolder,
    children => $n->{children} && scalar @{$n->{children}} > 0 ? $n->{children} : []
  };
}
sub create_children_for_types {
  my $type = shift;
  # my $display_name
  my $children = ();
  foreach (keys %$type) {
    push @$children, {
      key => $_,
      title => ucfirst($_),
      isFolder => 1,
      children => $type->{$_}
    };
  }
  return $children;
}

sub create_folder_for_special_types {
  my $type = shift;

  # my $children = ();
  # foreach (keys %$type) {
  #   push @$children, {
  #     key => $_,
  #     title => ucfirst($_),
  #     isFolder => 1,
  #     children => $type->{$_}
  #   };
  # }
  # return $children;

  my $internal_node_select = shift;
  my $extra_dyna = [];
  my $children = [];

  foreach my $k (keys %$type) {
    $children = [];
    # For sorting based on chromosome numbers
    my @extras_data_array;
    if ($k =~ /primary assembly/i) {
      @extras_data_array = sort {$a->{assembly_target} <=> $b->{assembly_target}} @{$type->{$k}->{data}};
    }
    else {
      @extras_data_array = sort {$a->{common} cmp $b->{common}} @{$type->{$k}->{data}};
    }

    foreach my $hash (@extras_data_array) {
      push @$children, create_node($hash, 1, 1);
    }

    # Create folder if opted
    if ($type->{$k}->{create_folder} == 1) {
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
# print Data::Dumper::Dumper $extra_dyna;
  return $extra_dyna;
}



# Get sub node display names as array to see all available internal nodes
# This is used to remove all paths that doesnt have any child
sub get_available_internal_nodes {
  my $self = shift;
  my $json = shift;
  my $species_info = shift;
  my $available_paths = {};

  foreach my $key (keys %$species_info) {
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

    if ((defined $obj->{key} && lc($obj->{key}) eq lc($target)) || (defined $obj->{extras_key} && $obj->{extras_key} eq $target)) {
      $path .= $obj->{key};
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
