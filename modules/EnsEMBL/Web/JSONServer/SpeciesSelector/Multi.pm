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

package EnsEMBL::Web::JSONServer::SpeciesSelector::Multi;

use strict;
use warnings;

use JSON;
use List::MoreUtils qw/ uniq /;
use URI::Escape qw(uri_escape);
use HTML::Entities qw(encode_entities);
use EnsEMBL::Web::IOWrapper::Indexed;
use EnsEMBL::Web::Utils::FileHandler qw(file_get_contents);

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
  my $primary_species = $hub->species;
  my $species_label   = $species_defs->species_label($primary_species, 1);
  my %shown           = map { $params->{"s$_"} => $_ } grep s/^s(\d+)$/$1/, keys %$params; # get species (and parameters) already shown on the page
  my $object          = $self->object;
  my $chr             = $object->seq_region_name;
  my $start           = $object->seq_region_start;
  my $end             = $object->seq_region_end;
  my $intra_species   = ($hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'INTRA_SPECIES_ALIGNMENTS'} || {})->{'REGION_SUMMARY'}{$primary_species};
  my $chromosomes     = $species_defs->ENSEMBL_CHROMOSOMES;
  my $species_info    = $hub->get_species_info;
  my (%species, %included_regions);

  my $final_hash      = {};
  my $all_species     = {};
  my $extras = {};

  # Adding haplotypes / patches
  foreach my $alignment (grep $start < $_->{'end'} && $end > $_->{'start'}, @{$intra_species->{$object->seq_region_name}}) {
    my $type = lc $alignment->{'type'};
    my ($s)  = grep /--$alignment->{'target_name'}$/, keys %{$alignment->{'species'}};
    my ($sp, $target) = split '--', $s;
    s/_/ /g for $type, $target;

    $species{$s} = $species_defs->species_label($sp, 1) . (grep($target eq $_, @$chromosomes) ? ' chromosome' : '') . " $target - $type";

    my $tmp = {};
    $tmp->{scientific} = $s;
    $tmp->{key} = $s;
    $tmp->{common}      = (grep($target eq $_, @$chromosomes) ? 'Chromosome ' : '') . "$target";

    push (@{$extras->{$sp}->{'haplotypes and patches'}}, $tmp);
  }

  foreach (grep !$species{$_}, keys %shown) {
    my ($sp, $target) = split '--';
    $included_regions{$target} = $intra_species->{$target} if $sp eq $primary_species;
  }

  foreach my $target (keys %included_regions) {
    my $s     = "$primary_species--$target";
    my $label = $species_label . (grep($target eq $_, @$chromosomes) ? ' chromosome' : '');
    
    foreach (grep $_->{'target_name'} eq $chr, @{$included_regions{$target}}) {
      (my $type = lc $_->{'type'}) =~ s/_/ /g;
      (my $t    = $target)         =~ s/_/ /g;
      $species{$s} = "$label $t - $type";
    }
  }

  foreach my $alignment (grep { $_->{'species'}{$primary_species} && $_->{'class'} =~ /pairwise/ } values %$alignments) {
    foreach (keys %{$alignment->{'species'}}) {
      $_ = $hub->species_defs->production_name_mapping($_);
      if ($_ ne $primary_species) {
        my $type = lc $alignment->{'type'};
           $type =~ s/_net//;
           $type =~ s/_/ /g;
        if ($species{$_}) {
          $species{$_} .= "/$type";
        } else {
          $species{$_} = $species_defs->species_label($_, 1) . " - $type";
          my $tmp = {};
          $tmp->{scientific} = $_;
          $tmp->{key} = $_;
          $tmp->{common} = $species_info->{$_}->{common};
          if ($species_info->{$_}->{strain_collection} and $species_info->{$_}->{strain} !~ /reference/) {
            # push @{$extras->{$species_info->{$_}->{strain_collection}}->{'strains'}}, $tmp;
            # $all_species->{$species_info->{$_}->{strain_collection}} = $tmp;
          }
          else {
            $final_hash->{species_info}->{$_} = $tmp;
            $all_species->{$_} = $tmp;
          }
        }
      }
    }
  }

  if ($shown{$primary_species}) {
    my ($chr) = split ':', $params->{"r$shown{$primary_species}"};
    $species{$primary_species} = "$species_label - chromosome $chr";
  }

  # Insert missing species into species info for all haplpotypes

  foreach (keys %$extras) {
    my $tmp = {};
    if (!$final_hash->{species_info}->{$_}) {
      $final_hash->{species_info}->{$_}->{scientific} = $_;
      $final_hash->{species_info}->{$_}->{key} = $_;
      $final_hash->{species_info}->{$_}->{common} = $species_info->{$_}->{common};
    }
  }

  my $file = $species_defs->ENSEMBL_SPECIES_SELECT_DIVISION;
  my $division_json = from_json(file_get_contents($file));
  my $json = {};

  my $available_internal_nodes = $self->get_available_internal_nodes($division_json, $all_species);
  my @dyna_tree = $self->json_to_dynatree($division_json, $final_hash->{species_info}, $available_internal_nodes, 1, $extras);

   return { json => \@dyna_tree };
}

1;

