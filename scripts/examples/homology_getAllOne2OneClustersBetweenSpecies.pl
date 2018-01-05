#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;


#
# This script fetches clusters of one2one orthologies between a
# given set of species
#

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
     -host => 'mysql-treefam-prod',
     -user => 'ensadmin',
     -pass => $ENV{'ENSADMIN_PSW'},
     -port => 4401,
     -species => 'Multi',
     -dbname => 'mateus_tuatara_86',
);


my $homology_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Multi", "Compara", "Homology");
my $mlss_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Multi", "compara", "MethodLinkSpeciesSet");
my $genome_db_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Multi", "compara", "GenomeDB");
my $gene_member_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Multi", "compara", "GeneMember");


# The first species is the "reference" species
# The script will download the one2one orthologies between it and all the
# other species, and combine the sets

my @list_of_species = ("tuatara","gallus_gallus", "alligator_sinensis", "chelonia_mydas", "anolis_carolinensis", "ophiophagus_hannah", "ophisaurus_gracilis", "gekko_japonicus", "homo_sapiens", "xenopus_tropicalis", "lepisosteus_oculatus");
#my @list_of_species = ("alligator_mississippiensis","alligator_sinensis","anas_platyrhynchos","anolis_carolinensis","chelonia_mydas","chrysemys_picta","danio_rerio","ficedula_albicollis","gallus_gallus","gekko_japonicus","homo_sapiens","lepisosteus_oculatus","meleagris_gallopavo","monodelphis_domestica","mus_musculus","ophiophagus_hannah","ophisaurus_gracilis","ornithorhynchus_anatinus","pelodiscus_sinensis","pogona_vitticeps","protobothrops_mucrosquamatus","python_molurus_bivittatus","taeniopygia_guttata","thamnophis_sirtalis","tuatara","xenopus_tropicalis");

my @gdbs = @{ $genome_db_adaptor->fetch_all_by_mixed_ref_lists(-SPECIES_LIST => \@list_of_species) };
my @all_species_names = sort(map {$_->name} @gdbs);

print STDERR "species_list:@all_species_names\n";

my $present_in_all = undef;

for ( my $i = 0; $i<scalar(@gdbs); $i++ ) {
    my $sp1_gdb = $gdbs[$i];
    for ( my $j = $i; $j<scalar(@gdbs); $j++ ) {

        my $sp2_gdb = $gdbs[$j];
        print STDERR "i=$i|j=$j\n";
        next if ( $sp1_gdb eq $sp2_gdb );

    print STDERR "# Fetching ", $sp1_gdb->name, " - ", $sp2_gdb->name, " orthologues \n";
    my $mlss_orth = $mlss_adaptor->fetch_by_method_link_type_GenomeDBs('ENSEMBL_ORTHOLOGUES', [$sp1_gdb, $sp2_gdb]);
    my @one2one_orthologies = @{$homology_adaptor->fetch_all_by_MethodLinkSpeciesSet($mlss_orth, -ORTHOLOGY_TYPE => 'ortholog_one2one')};
    my $count = 0; my $total_count = scalar @one2one_orthologies;
    foreach my $ortholog (@one2one_orthologies) {

      # Create a hash of stable_id pairs with genome name as subkey
      my ($gene1,$gene2) = @{$ortholog->get_all_Members};
      $count++;
      print STDERR "[$count/$total_count]\n" if (0 == $count % 1000);
      $present_in_all->{$gene1->gene_member_id}{$sp1_gdb->name}{$gene2->gene_member_id} = 1;
      $present_in_all->{$gene1->gene_member_id}{$sp2_gdb->name}{$gene2->gene_member_id} = 1;
      $present_in_all->{$gene2->gene_member_id}{$sp1_gdb->name}{$gene1->gene_member_id} = 1;
      $present_in_all->{$gene2->gene_member_id}{$sp2_gdb->name}{$gene1->gene_member_id} = 1;
    }
  }
}

print STDERR "Loading the gene names\n";
my %gene_member_id_2_stable_id = map {$_->dbID => $_->stable_id} @{$gene_member_adaptor->fetch_all_by_dbID_list([keys %$present_in_all])};

my %uniq_keys;

# This code below is optional and is only to sort out cases where all
# genomes are in the list and print the list of ids if it is the case
print STDERR "Printing the orthology groups\n";
foreach my $gene_member_id (keys %$present_in_all) {
    next if scalar(keys %{$present_in_all->{$gene_member_id}}) != scalar(@all_species_names);
    my $gene_member_ids;
    $gene_member_ids->{$gene_member_id} = 1;
    foreach my $name (@all_species_names) {
      foreach my $id (keys %{$present_in_all->{$gene_member_id}{$name}}) {
        $gene_member_ids->{$id} = 1;
      }
    }
    $uniq_keys{join(",", sort map {$gene_member_id_2_stable_id{$_}} keys %$gene_member_ids)} = 1;
}

foreach my $one2one (keys %uniq_keys) {
    print "$one2one\n";
}
