#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use strict;
use warnings;
use Data::Dumper;

use Bio::EnsEMBL::Registry;


# The wanted/unwanted species

#my $species_list = {"rat"=>1, "cow"=>1, "mouse"=>1, "tetraodon"=>0};
my $species_list = {"rat"=>1, "cow"=>1};



# Auto-configure the registry
Bio::EnsEMBL::Registry->load_registry_from_db(-host=>'ensembldb.ensembl.org', -user=>'anonymous') ;

my $homology_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Multi", "Compara", "Homology");
my $mlss_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Multi", "compara", "MethodLinkSpeciesSet");
my $genome_db_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Multi", "compara", "GenomeDB");


# The same list as species_list, but with genome_db_ids
my %genomedbid_list;
# Translation back from genome_db_id to species name
my %gdbid2name;
# Used to seed the initial orthologue search
my $tmp1;
my $tmp2;
# The number of species that we expect in a cluster
my $n_goodspecies = 0;
# Contains the mlss objects for each pair of species
my %mlss_cache;

my $genome_dbs = $genome_db_adaptor->fetch_all_by_mixed_ref_lists(-SPECIES_LIST => [keys %{$species_list}]);
# Finds all pairs of species, and initializes the above variables
foreach my $gdb1 (@$genome_dbs) {
	my $gdb_id1 = $gdb1->dbID;
	my $gdb_name1 = $gdb1->name;
	$gdbid2name{$gdb_id1} = $gdb_name1;
	$genomedbid_list{$gdb_id1} = ${$species_list}{$gdb_name1};
	$tmp1 = $gdb_id1 if ${$species_list}{$gdb_name1} == 1;
	$n_goodspecies += 1 if ${$species_list}{$gdb_name1} == 1;
	$mlss_cache{$gdb_id1} = {};
	foreach my $gdb2 (@$genome_dbs) {
		my $gdb_id2 = $gdb2->dbID;
		$mlss_cache{$gdb_id1}{$gdb_id2} = $mlss_adaptor->fetch_by_method_link_type_genome_db_ids('ENSEMBL_ORTHOLOGUES', [$gdb_id1, $gdb_id2]) if ($gdb_id1 != $gdb_id2);
		$tmp2 = $gdb_id2 if (${$species_list}{$gdb2->name} == 1) and ($tmp1 ne $gdb_id2);
	}
}


# All the orthologues between two arbitrary species. It is more efficient than trying all the gene of a given species
my $homologies = $homology_adaptor->fetch_all_by_MethodLinkSpeciesSet($mlss_cache{$tmp1}->{$tmp2});
foreach my $homology (@{$homologies}) {
	my $gene_member = $homology->get_all_Members->[0];
	my $member_set = {};
	my $ok = _recursive_get_orthocluster($gene_member, {}, {},  $member_set);

	# now, ok is 0 if an unwanted species is in the cluster, 1 otherwise
	# member_set is a hash which associates species names to the list of corresponding genes

	if ($ok == 1) {
		if (scalar(keys %{$member_set}) == $n_goodspecies) {

			# Cluster content can be accessed like this:
			print "cluster content: ";
			foreach my $species (keys %{$member_set} ) {
				print "$species: ", join("-", (map {$_->stable_id}  @{$member_set->{$species}})), ", ";
			}
			print "\n";

		} else {
			# invalid cluster because a wanted species is missing
		}
	} else {
		# invalid cluster because an unwanted species is present
	}

}


# Recursively download all the homologies within the species of interest
sub _recursive_get_orthocluster {
	my $gene = shift;
	my $ortho_set = shift;
	my $tmp_set = shift;
	my $member_set = shift;

	# Don't go further if we have already visited the gene
	return 1 if ($tmp_set->{$gene->dbID});
	$tmp_set->{$gene->dbID} = 1;

	# Stores the current gene
	my $name = $gdbid2name{$gene->genome_db_id};
	${$member_set}{$name} = [] if not defined ${$member_set}{$name};
	push @{ ${$member_set}{$name} }, $gene;
	
	# Search links with all the species of interest
	foreach my $genome_db_id (keys %genomedbid_list) {

		# we don't want paralogues
		next if $gene->genome_db_id eq $genome_db_id;

		# list of orthologues
		my $homologies = $homology_adaptor->fetch_all_by_Member($gene->gene_member, -METHOD_LINK_SPECIES_SET => $mlss_cache{$gene->genome_db_id}->{$genome_db_id});

		# stop iteration if an unwanted species is found
		return 0 if (($genomedbid_list{$gene->genome_db_id} == 0) and (scalar(@{$homologies}) != 0));

		foreach my $homology (@{$homologies}) {

			# to avoid using the same homology twice
			next if($ortho_set->{$homology->dbID});
			$ortho_set->{$homology->dbID} = 1;

			foreach my $member (@{$homology->get_all_Members}) {
				next if($member->dbID == $gene->dbID); #skip query gene
				return 0 unless _recursive_get_orthocluster($member, $ortho_set, $tmp_set, $member_set);
			}
		}
	}
	return 1;
}


