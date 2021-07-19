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

package EnsEMBL::Web::JSONServer::SpeciesSelector::Compara_Alignments;

use strict;
use warnings;

use JSON;
use HTML::Entities qw(encode_entities);
use parent qw(EnsEMBL::Web::JSONServer::SpeciesSelector);
no warnings 'numeric';

sub object_type {
  return 'Location';
}

sub json_fetch_species {
  my $self = shift;  
  my $hub          = $self->hub;
  my $sd           = $hub->species_defs;
  my $cdb          = shift || $hub->param('cdb') || 'compara';
  my $db_hash      = $sd->multi_hash;
  my $url          = $hub->url({ %{$hub->multi_params}, align => undef }, 1);
  my $extra_inputs = join '', map qq(<input type="hidden" name="$_" value="$url->[1]{$_}" />), sort keys %{$url->[1] || {}};
  my $alignments   = $db_hash->{'DATABASE_COMPARA' . ($cdb =~ /pan_ensembl/ ? '_PAN_ENSEMBL' : '')}{'ALIGNMENTS'} || {}; # Get the compara database hash
  my $species_info = $hub->get_species_info;
  my $species      = $sd->IS_STRAIN_OF ? ucfirst $sd->SPECIES_PRODUCTION_NAME($hub->species) : $hub->species;
  my $species_hash_multiple = ();

  # Order by number of species (name is in the form "6 primates EPO")
  foreach my $row (sort { $a->{'name'} <=> $b->{'name'} } grep { $_->{'class'} !~ /pairwise/ && $_->{'species'}->{$species} } values %$alignments) {
    (my $name = $row->{name}) =~ s/ /_/g;
    my $t = {};
    $t->{key}        = encode_entities($name);
    $t->{title}      = encode_entities($row->{name});
    $t->{value}      = $row->{'id'};
    $t->{searchable} = 1;
    $t->{isFolder}   = 1;
    $t->{expand}     = 0;
    $t->{children}   = [];
    my @children;

    foreach (sort keys %{$row->{'species'}}) {
      my $url_name  = $hub->species_defs->production_name_mapping($_);
      my $prod_name = $hub->species_defs->get_config($url_name, 'SPECIES_PRODUCTION_NAME');
      my $ancestral = 0;
      if ($_ =~/ancestral_sequences/i) {
        $url_name = ucfirst($_);
        $prod_name = $_;
        $ancestral = 1;
      }

      next unless $prod_name;
      $prod_name = encode_entities($prod_name);
      my $t_child = {};
      $t_child->{key}        = join '_', ('species', $row->{id}, lc($prod_name));
      $t_child->{title}      = encode_entities($ancestral ? '--Ancestral_sequences--' : $species_info->{$url_name}->{display_name});
      $t_child->{value}      = $row->{id};
      $t_child->{scientific_name} = $prod_name;
      $t_child->{img_url}    = $sd->ENSEMBL_IMAGE_ROOT . '/species/' . $url_name . '.png';
      $t_child->{searchable} = 0;

      if (lc($prod_name) eq lc($species)) {
        $t_child->{unselectable} = 1;
        $t_child->{tooltip} = 'Selection disabled on primary species';
        $t_child->{hideCheckbox} = 1;
      }
      push @children, $t_child;
    }

    push @{$t->{children}}, sort { $a->{title} cmp $b->{title} } @children;
    push @{$species_hash_multiple}, $t;
  }

  my $dynatree_multiple = {};

  my $dynatree_root = {};
  $dynatree_root->{key}            = 'All_Alignments';
  $dynatree_root->{title}          = 'All Alignments';
  $dynatree_root->{isFolder}       = 1;
  $dynatree_root->{is_submenu}     = 1;
  $dynatree_root->{isInternalNode} = "true";
  $dynatree_root->{unselectable}   = "true";

  if ($#$species_hash_multiple >= 0) {
    $dynatree_multiple->{key}            = 'Multiple';
    $dynatree_multiple->{title}          = 'Multiple';
    $dynatree_multiple->{isFolder}       = 1;
    $dynatree_multiple->{isInternalNode} = "true";
    $dynatree_multiple->{unselectable}   = 1;
    $dynatree_multiple->{hideCheckbox} = 1;


    push @{$dynatree_multiple->{children}}, @$species_hash_multiple;
    push @{$dynatree_root->{children}}, $dynatree_multiple;
  }

  # For the variation compara view, only allow multi-way alignments
  my $available_species_map = {};

  if ($hub->type ne 'Variation') {
    my $available_alignments = {};
    foreach my $align_id (grep { $alignments->{$_}{'class'} =~ /pairwise/ } keys %$alignments) {
      foreach (keys %{$alignments->{$align_id}->{'species'}}) {
        if ($alignments->{$align_id}{'species'}->{$species} && $_ ne $species) {
          # Creating a new hash with species_set_id as the key to handle available multiple alignment methods for each species.
          # and thus return one based on hierarchy of available alignments [ENSWEB-3343]
          $available_alignments->{$align_id} = $alignments->{$align_id};
        }
      }
    }

    # Select alignments based on available alignments hierarchy
    my $final_alignments = $self->object->filter_alignments_by_method($available_alignments);
    foreach my $align_id (keys %$final_alignments) {
      foreach (keys %{$final_alignments->{$align_id}->{'species'}}) {
        if ($alignments->{$align_id}{'species'}->{$species} && $_ ne $species) {
          $_ = $hub->species_defs->production_name_mapping($_);
          $available_species_map->{$_} = $align_id;
        }
      }
    }
  }

  my $json = {};
  my $sp_assembly_map = $sd->SPECIES_ASSEMBLY_MAP;

  $self->{species_selector_data} = {
    division_json => $sd->ENSEMBL_TAXONOMY_DIVISION,
    sp_assembly_map => $sd->SPECIES_ASSEMBLY_MAP,
    available_species => $available_species_map,
    internal_node_select => 0
  };

  my @dyna_tree = $self->create_tree();

  if (scalar @dyna_tree) {
    my $dynatree_pairwise = {};
    $dynatree_pairwise->{key} = 'Pairwise';
    $dynatree_pairwise->{title} = 'Pairwise';
    $dynatree_pairwise->{isFolder} = 1;
    $dynatree_pairwise->{is_submenu} = 1;
    $dynatree_pairwise->{isInternalNode} = "true";
    $dynatree_pairwise->{unselectable} = "true";
    push @{$dynatree_pairwise->{children}}, ($#dyna_tree >=0 && $dyna_tree[0]->{children}) ? @{$dyna_tree[0]->{children}} : [];

    # Push pairwise tree into dynatree root node;
    if (scalar(@{$dynatree_pairwise->{children}}) > 0) {
      push @{$dynatree_root->{children}}, $dynatree_pairwise;
    }
  }

  return { json => [$dynatree_root] };
}

1;
