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

package EnsEMBL::Web::JSONServer::SpeciesSelector::Multi;

use strict;
use warnings;

use JSON;
use List::MoreUtils qw/ uniq /;
use URI::Escape qw(uri_escape);
use HTML::Entities qw(encode_entities);
use EnsEMBL::Web::IOWrapper::Indexed;

use parent qw(EnsEMBL::Web::JSONServer::SpeciesSelector);

sub object_type {
  return 'Location';
}

sub json_fetch_species {
  my $self = shift;
  my $hub             = $self->hub;
  my $species_defs    = $hub->species_defs;
  my $params          = $hub->multi_params; 
  my $alignments      = $species_defs->multi_hash->{'DATABASE_COMPARA'}->{'ALIGNMENTS'} || {};
  my $primary_species = $species_defs->IS_STRAIN_OF ? ucfirst $species_defs->SPECIES_PRODUCTION_NAME($hub->species) : $hub->species;
  my $species_label   = $species_defs->species_label($primary_species, 1);
  my %shown           = map { $params->{"s$_"} => $_ } grep s/^s(\d+)$/$1/, keys %$params; # get species (and parameters) already shown on the page
  my $object          = $self->object;
  my $chr             = $object->seq_region_name;
  my $start           = $object->seq_region_start;
  my $end             = $object->seq_region_end;
  my $intra_species   = ($hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'INTRA_SPECIES_ALIGNMENTS'} || {})->{'REGION_SUMMARY'}{$primary_species};
  my $chromosomes     = $species_defs->ENSEMBL_CHROMOSOMES;
  my $species_info    = $hub->get_species_info;
  my (%available_species, %included_regions);

  my $available_species_map = {};
  my $extras = {};
  my $uniq_assembly = {};

  # Adding haplotypes / patches
  foreach my $alignment (grep $start < $_->{'end'} && $end > $_->{'start'}, @{$intra_species->{$object->seq_region_name}}) {
    my $type = lc $alignment->{'type'};
    my ($s)  = grep /--$alignment->{'target_name'}$/, keys %{$alignment->{'species'}};
    my ($sp, $target) = split '--', $s;
    s/_/ /g for $type, $target;

    $available_species{$s} = $species_defs->species_label($sp, 1) . (grep($target eq $_, @$chromosomes) ? ' chromosome' : '') . " $target - $type";
    my $tmp = {};
    $tmp->{scientific_name} = $s;
    $tmp->{key} = $s;
    if (grep($target eq $_, @$chromosomes)) {
      $tmp->{display_name} = 'Chromosome ' . "$target";
      $tmp->{assembly_target} = $target;
      if (!$uniq_assembly->{$target}) {
        push @{$extras->{$sp}->{'primary assembly'}->{data}}, $tmp;
        $uniq_assembly->{$target} = 1; # to remove duplicates
      }
      if (!$extras->{$sp}->{'primary assembly'}->{create_folder}) {
        $extras->{$sp}->{'primary assembly'}->{create_folder} = 1;
      }
    }
    else {
      $tmp->{display_name} = "$target";
      $extras->{$sp}->{'haplotypes and patches'}->{create_folder} = 1;
      push @{$extras->{$sp}->{'haplotypes and patches'}->{data}}, $tmp;
    }
  }

  foreach (grep !$available_species{$_}, keys %shown) {
    my ($sp, $target) = split '--';
    $included_regions{$target} = $intra_species->{$target} if $sp eq $primary_species;
  }

  foreach my $target (keys %included_regions) {
    my $s     = "$primary_species--$target";
    my $label = $species_label . (grep($target eq $_, @$chromosomes) ? ' chromosome' : '');
    
    foreach (grep $_->{'target_name'} eq $chr, @{$included_regions{$target}}) {
      (my $type = lc $_->{'type'}) =~ s/_/ /g;
      (my $t    = $target)         =~ s/_/ /g;
      $available_species{$s} = "$label $t - $type";
    }
  }

  foreach my $alignment (grep { $_->{'species'}{$primary_species} && $_->{'class'} =~ /pairwise/ } values %$alignments) {
    foreach (keys %{$alignment->{'species'}}) {
      $_ = $hub->species_defs->production_name_mapping($_);
      if ($_ ne $primary_species) {
        my $type = lc $alignment->{'type'};
           $type =~ s/_net//;
           $type =~ s/_/ /g;
        if ($available_species{$_}) {
          $available_species{$_} .= "/$type";
        } else {
          $available_species{$_} = $species_defs->species_label($_, 1) . " - $type";
        }
      }
    }
  }

  if ($shown{$primary_species}) {
    my ($chr) = split ':', $params->{"r$shown{$primary_species}"};
    $available_species{$primary_species} = "$species_label - chromosome $chr";
  }

  # create a map of all available species including the haplotypes etc
  # Insert missing species into species_info for haplpotypes so that
  # the species is displayed on the tree and thus its children as haplotypes
  map { $available_species_map->{$_} = 1 } keys %$extras, keys %available_species;

  my $division_json = $species_defs->ENSEMBL_TAXONOMY_DIVISION;
  my $sp_assembly_map = $species_defs->SPECIES_ASSEMBLY_MAP;

  $self->{species_selector_data} = {
    division_json => $division_json,
    available_species => $available_species_map,
    internal_node_select => 1,
    extras => $extras,
    sp_assembly_map => $sp_assembly_map
  };
  my @dyna_tree = $self->create_tree();

   return { json => \@dyna_tree };
}

1;

