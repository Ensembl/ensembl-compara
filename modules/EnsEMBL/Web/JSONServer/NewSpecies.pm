=head1 LICENSE
our $final = {};

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

package EnsEMBL::Web::JSONServer::NewSpecies;

use strict;
use warnings;

use JSON;
use EnsEMBL::Web::DBSQL::ArchiveAdaptor;


use parent qw(EnsEMBL::Web::JSONServer);
our $final = {};

sub json_data {
  my $self = shift;
  my $hub             = $self->hub;
  my $species_defs    = $hub->species_defs;
  my $division_json   = $species_defs->multi_val('ENSEMBL_TAXONOMY_DIVISION');
  ## get assembly info for each species
  my $adaptor = EnsEMBL::Web::DBSQL::ArchiveAdaptor->new($hub);
  my $assemblies = $adaptor->fetch_archive_assemblies();
  my $this_release = $species_defs->ENSEMBL_VERSION;

  if ($hub->param('release') > $this_release) {
    print "Please specify a valid release\n\n";
    return {};
  }

  my $from_rel = $hub->param('release') || $this_release;
  my $json = {};

  if ($hub->param('release') eq 0) {
    push @{$json->{new_species}}, keys %{$hub->get_species_info};
  }
  else {
    foreach my $sp (keys %$assemblies) {
      if ($assemblies->{$sp}->{$from_rel} &&
          !$assemblies->{$sp}->{$from_rel-1} ) {
        push @{$json->{new_species}}, $sp;
      }
      else {
        if (  $assemblies->{$sp}->{$from_rel} &&
              $assemblies->{$sp}->{$from_rel-1} &&
              ($assemblies->{$sp}->{$from_rel}->{assembly} ne
              $assemblies->{$sp}->{$from_rel-1}->{assembly}) ) {
          push @{$json->{new_assembly}}, $sp;

        }
      }
    }
  }

  if (!$hub->param('format')) {
    if ($hub->param('pretty')) {
      print "Release: ", $hub->param('release'),"\n\n";
      print Data::Dumper::Dumper $json;
      return {};
    }
    else {
      return $json;
    }
  }
  else {
    my @paths = map {get_taxonomy_path($_, $division_json)} @{$json->{new_species}};
    my $hash = {};
    $hash->{new_species} = create_hash_from_path(\@paths);
    @paths = map {get_taxonomy_path($_, $division_json)} @{$json->{new_assembly}};
    $hash->{new_assembly} = create_hash_from_path(\@paths);

    if ($hub->param('format') eq 'd3') {

      my $available_species_map = {};
      map { $available_species_map->{$_} = 1 } @{$json->{new_species}};

      $self->{species_selector_data} = {
        division_json => $division_json,
        available_species => $available_species_map,
      };

      my @nodes = map { $self->traverse($_) } @{$division_json->{child_nodes}};
      my $final_json = {};

      if ($#nodes >= 0) {
        $final_json = {
          name => 'All Divisions',
          children => [@nodes],
          total => scalar @{$json->{new_species}}
        };
      }

      if ($hub->param('pretty')) {
        print "Release: ", $hub->param('release'),"\n\n";
        print Data::Dumper::Dumper $final_json;
        return {};
      }
      else {
        return $final_json;
      }
    }
    else {
      if ($hub->param('pretty')) {
        print "Release: ", $hub->param('release'),"\n\n";
        print Data::Dumper::Dumper $hash;
        return {};
      }
      else {
        return $hash;
      }
    }
  }
}

sub traverse {
# Traverse through the ensembl taxonomy divisions and create the dynatree json
  my $self = shift;
  my $node = shift;
  my @tree;
  my $species_is_available = $self->{species_selector_data}->{available_species}->{$node->{key}} ? 1 : 0;
  my $value = $self->{species_selector_data}->{available_species}->{$node->{key}};
  if ($node->{is_leaf} && $species_is_available) {
    return {
      name => $node->{key},
      display_name => $node->{display_name}
    };
  }
  else {
    if ($node->{child_nodes}) {
      my @children;
      my @child_nodes = $node->{child_nodes};

      foreach (@{$node->{child_nodes}}) {
        push @children, $self->traverse($_);
      }

      if ($#children >= 0) {
        push @tree, {
          name => $node->{display_name} . ' (' . scalar(@children) . ')' ,
          children => [@children],
          display_name => $node->{display_name}
        };
      }
    }
  }
  return @tree;
}

sub create_hash_from_path {
  my $paths = shift;
  my $hash = {};
  my $arr = ();

  foreach my $p (@$paths) {
    @$arr = split(',', $p);
    if (!$hash->{$arr->[0]}->{$arr->[1]}) {
      $hash->{$arr->[0]}->{$arr->[1]} = {};
    }

    if ($arr->[2] && !$hash->{$arr->[0]}->{$arr->[1]}->{$arr->[2]}) {
      $hash->{$arr->[0]}->{$arr->[1]}->{$arr->[2]} = {};
    }

    if ($arr->[3] && !$hash->{$arr->[0]}->{$arr->[1]}->{$arr->[2]}->{$arr->[3]}) {
      $hash->{$arr->[0]}->{$arr->[1]}->{$arr->[2]}->{$arr->[3]} = {};
    }
  }
  return $hash;
}


sub get_taxonomy_path {
  my $key = shift;
  my $node = shift;
  my $path = '';

  sub search {
    my ($path, $obj, $target) = @_;
    if ((defined $obj->{key} && $obj->{key} eq $target) || (defined $obj->{extras_key} && $obj->{extras_key} eq $target)) {
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

