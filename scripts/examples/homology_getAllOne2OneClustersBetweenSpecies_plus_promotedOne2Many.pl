#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2017] EMBL-European Bioinformatics Institute
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

#
# This script fetches clusters of one2one and/or one2many orthologues between a given set of species.
#

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use Getopt::Long;
use Data::Dumper;
use List::Util qw(max);

my $species_set;
my $one2one_flag;
my $one2many_flag;
my $out_dir;

GetOptions( "species_set=s" => \$species_set, "one2one" => \$one2one_flag, "one2many" => \$one2many_flag, "outdir=s" => \$out_dir ) or die("Error in command line arguments\n");

die "Error in command line arguments [species_set = all_species|species_set_1] [one2one || one2many needs to be defined] [outdir = /your/directory/]"
  if ( ( !$species_set ) || ( ( $species_set ne "all_species" ) && ( $species_set ne "species_set_1" ) && ( $species_set ne "test" ) ) || ( !$one2one_flag && !$one2many_flag ) || !$out_dir );

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -host    => 'mysql-treefam-prod',
                                              -user    => 'ensadmin',
                                              -pass    => $ENV{'ENSADMIN_PSW'},
                                              -port    => 4401,
                                              -species => 'Multi',
                                              -dbname  => 'mateus_tuatara_86', );

my $homology_adaptor    = Bio::EnsEMBL::Registry->get_adaptor( "Multi", "Compara", "Homology" );
my $mlss_adaptor        = Bio::EnsEMBL::Registry->get_adaptor( "Multi", "compara", "MethodLinkSpeciesSet" );
my $genome_db_adaptor   = Bio::EnsEMBL::Registry->get_adaptor( "Multi", "compara", "GenomeDB" );
my $gene_member_adaptor = Bio::EnsEMBL::Registry->get_adaptor( "Multi", "compara", "GeneMember" );

# The first species is the "reference" species
# The script will download the one2one orthologies between it and all the
# other species, and combine the sets

my @list_of_species;

if ( $species_set eq "test" ) {
    @list_of_species = sort ( "tuatara", "gallus_gallus", "alligator_sinensis" );
}

if ( $species_set eq "species_set_1" ) {

    @list_of_species = sort( "tuatara", "gallus_gallus", "alligator_sinensis", "chelonia_mydas", "anolis_carolinensis", "ophiophagus_hannah",
                             "ophisaurus_gracilis", "gekko_japonicus", "homo_sapiens", "xenopus_tropicalis", "lepisosteus_oculatus" );

}

if ( $species_set eq "all_species" ) {

    @list_of_species = sort( "alligator_mississippiensis", "alligator_sinensis", "anas_platyrhynchos", "anolis_carolinensis",
                             "chelonia_mydas",               "chrysemys_picta",           "danio_rerio",         "ficedula_albicollis",
                             "gallus_gallus",                "gekko_japonicus",           "homo_sapiens",        "lepisosteus_oculatus",
                             "meleagris_gallopavo",          "monodelphis_domestica",     "mus_musculus",        "ophiophagus_hannah",
                             "ophisaurus_gracilis",          "ornithorhynchus_anatinus",  "pelodiscus_sinensis", "pogona_vitticeps",
                             "protobothrops_mucrosquamatus", "python_molurus_bivittatus", "taeniopygia_guttata", "thamnophis_sirtalis",
                             "tuatara",                      "xenopus_tropicalis" );
}

my @gdbs = sort( @{ $genome_db_adaptor->fetch_all_by_mixed_ref_lists( -SPECIES_LIST => \@list_of_species ) } );
my @all_species_names = sort( map { $_->name } @gdbs );

print STDERR "species_list:@all_species_names\n";

my $present_in_all_one2one  = undef;
my $present_in_all_one2many = undef;
my $promoted_one2one        = undef;
my $goc_list_one2one        = undef;
my $species_list_one2many   = undef;

for ( my $i = 0; $i < scalar(@gdbs); $i++ ) {
    my $sp1_gdb = $gdbs[$i];
    for ( my $j = $i; $j < scalar(@gdbs); $j++ ) {

        my $sp2_gdb = $gdbs[$j];
        print STDERR "i=$i|j=$j [species_set:$species_set]\n";
        next if ( $sp1_gdb eq $sp2_gdb );

        print STDERR "# Fetching ", $sp1_gdb->name, " - ", $sp2_gdb->name, " orthologues \n";
        my $mlss_orth = $mlss_adaptor->fetch_by_method_link_type_GenomeDBs( 'ENSEMBL_ORTHOLOGUES', [ $sp1_gdb, $sp2_gdb ] );

        if ($one2one_flag) {

            #one2one orthologues
            my @one2one_orthologies = @{ $homology_adaptor->fetch_all_by_MethodLinkSpeciesSet( $mlss_orth, -ORTHOLOGY_TYPE => 'ortholog_one2one' ) };
            my $count               = 0;
            my $total_count         = scalar @one2one_orthologies;
            foreach my $ortholog (@one2one_orthologies) {

                my $goc = $ortholog->goc_score() || 0;

                # Create a hash of stable_id pairs with genome name as subkey
                my ( $gene1, $gene2 ) = @{ $ortholog->get_all_Members };
                $count++;
                print STDERR "one2one: [$count/$total_count]\n" if ( 0 == $count % 1000 );
                $present_in_all_one2one->{ $gene1->gene_member_id }{ $sp1_gdb->name }{ $gene2->gene_member_id } = 1;
                $present_in_all_one2one->{ $gene1->gene_member_id }{ $sp2_gdb->name }{ $gene2->gene_member_id } = 1;
                $present_in_all_one2one->{ $gene2->gene_member_id }{ $sp1_gdb->name }{ $gene1->gene_member_id } = 1;
                $present_in_all_one2one->{ $gene2->gene_member_id }{ $sp2_gdb->name }{ $gene1->gene_member_id } = 1;

                $goc_list_one2one->{ $gene1->gene_member_id } = $goc;
                $goc_list_one2one->{ $gene2->gene_member_id } = $goc;
            }
        }

        if ($one2many_flag) {

            #one2many orthologues
            my @one2many_orthologies = @{ $homology_adaptor->fetch_all_by_MethodLinkSpeciesSet( $mlss_orth, -ORTHOLOGY_TYPE => 'ortholog_one2many' ) };

            #Preloading all the homologies.
            my $sms = Bio::EnsEMBL::Compara::Utils::Preloader::expand_Homologies( $one2many_orthologies[0]->adaptor->db->get_AlignedMemberAdaptor, \@one2many_orthologies );
            Bio::EnsEMBL::Compara::Utils::Preloader::load_all_GeneMembers( $one2many_orthologies[0]->adaptor->db->get_GeneMemberAdaptor, $sms );

            my $count       = 0;
            my $total_count = scalar @one2many_orthologies;

            foreach my $ortholog_many (@one2many_orthologies) {

                #transform the undef's returned by GOC analysis to -100
                my $goc = $ortholog_many->goc_score() // -100;

                # Create a hash of stable_id pairs with genome name as subkey
                my ( $gene1, $gene2 ) = @{ $ortholog_many->get_all_Members };
                my $g1 = $gene1->gene_member_id;
                my $g2 = $gene2->gene_member_id;

                #make sure it is present in all the species
                # *100+$gene1->perc_id is a formula to take the identity into account
                my $ideal_score = max( $goc*100 + $gene1->perc_id, $goc*100 + $gene2->perc_id );

                $count++;
                print STDERR "one2many: [$count/$total_count]\n" if ( 0 == $count % 1000 );

                $present_in_all_one2many->{ $gene1->gene_member_id }{ $gene1->genome_db->name }{ $gene2->gene_member_id } = $ideal_score;
                $present_in_all_one2many->{ $gene1->gene_member_id }{ $gene2->genome_db->name }{ $gene2->gene_member_id } = $ideal_score;
                $present_in_all_one2many->{ $gene2->gene_member_id }{ $gene1->genome_db->name }{ $gene1->gene_member_id } = $ideal_score;
                $present_in_all_one2many->{ $gene2->gene_member_id }{ $gene2->genome_db->name }{ $gene1->gene_member_id } = $ideal_score;

                #list of species per gene
                $species_list_one2many->{ $gene1->gene_member_id } = $gene1->genome_db->name;
                $species_list_one2many->{ $gene2->gene_member_id } = $gene2->genome_db->name;

            } ## end foreach my $ortholog_many (...)

            #create a list with with a key to gene1 and gene2 as subkey.
            #the idea here is to use the hash properties to exclude the repetitions.
            #By later selecting only the keys that have at least >1 subkeys
            my $list = undef;
            foreach my $g1 ( keys %{$present_in_all_one2many} ) {
                foreach my $sp ( keys %{ $present_in_all_one2many->{$g1} } ) {
                    foreach my $g2 ( keys %{ $present_in_all_one2many->{$g1}->{$sp} } ) {
                        $list->{$g1}{$g2} = $present_in_all_one2many->{$g1}->{$sp}->{$g2};
                        $list->{$g2}{$g1} = $present_in_all_one2many->{$g2}->{$sp}->{$g1};
                    }
                }
            }

            #Promoting one2many to one2ones.
            foreach my $l ( keys %{$list} ) {
                foreach my $g ( keys( %{ $list->{$l} } ) ) {

                    my $species = $species_list_one2many->{$g};
                    my $goc     = $list->{$l}{$g};

                    #defining for the first time
                    if ( !defined( $promoted_one2one->{$l}{$species} ) ) {
                        $promoted_one2one->{$l}{$species}{'one2one'} = $g;
                        $promoted_one2one->{$l}{$species}{'goc'}     = $goc;

                    }
                    elsif ( $goc > $promoted_one2one->{$l}{$species}{'goc'} ) {
                        $promoted_one2one->{$l}{$species}{'one2one'} = $g;
                        $promoted_one2one->{$l}{$species}{'goc'}     = $goc;
                    }
                }
            }
        } ## end if ($one2many_flag)
    } ## end for ( my $j = $i; $j < ...)
} ## end for ( my $i = 0; $i < scalar...)

#Printing results
#my $out_dir = "/nfs/production/panda/ensembl/compara/mateus/tuatara_phylogeny/$species_set/promoted/";
system("mkdir -p $out_dir");

#one2one
if ($one2one_flag) {
    print STDERR "Loading the gene names\n";
    my %gene_member_id_2_stable_id = map { $_->dbID => $_->stable_id } @{ $gene_member_adaptor->fetch_all_by_dbID_list( [ keys %$present_in_all_one2one ] ) };

    my %uniq_keys;

    # This code below is optional and is only to sort out cases where all
    # genomes are in the list and print the list of ids if it is the case
    print STDERR "Printing the orthology groups\n";
    foreach my $gene_member_id ( keys %$present_in_all_one2one ) {
        next if scalar( keys %{ $present_in_all_one2one->{$gene_member_id} } ) != scalar(@all_species_names);
        my $goc = $goc_list_one2one->{$gene_member_id};
        my $gene_member_ids;
        $gene_member_ids->{$gene_member_id} = 1;
        foreach my $name (@all_species_names) {

            foreach my $id ( keys %{ $present_in_all_one2one->{$gene_member_id}{$name} } ) {
                $gene_member_ids->{$id} = 1;
            }
        }
        $uniq_keys{ join( ",", sort map { $gene_member_id_2_stable_id{$_} } keys %$gene_member_ids ) } = $goc;
    }

    open( ONE, ">$out_dir/pure_one2one_with_goc.txt" );
    foreach my $one2one ( keys %uniq_keys ) {
        print ONE $uniq_keys{$one2one} . "|$one2one\n";
    }
    close(ONE);

} ## end if ($one2one_flag)

#one2many
if ($one2many_flag) {

    #Bio::EnsEMBL::Compara::Utils::Preloader::load_all_GeneMembers( $gene_member_adaptor, [ keys %$present_in_all_one2many ] );
    print STDERR "Loading the gene names\n";
    my %gene_member_id_2_stable_id_many = map { $_->dbID => $_->stable_id } @{ $gene_member_adaptor->fetch_all_by_dbID_list( [ keys %$present_in_all_one2many ] ) };

    print STDERR "Printing results\n";
    open( PROMOTED, ">$out_dir/promoted_one2one_filtered_with_goc_and_identity.txt" );
    print PROMOTED "species_count|gene_list|average_goc_score\n";
    foreach my $p ( keys %{$promoted_one2one} ) {
        my $gene1 = $gene_member_adaptor->fetch_by_dbID($p)->stable_id;
        print PROMOTED "S_" . scalar( keys( %{ $promoted_one2one->{$p} } ) ) . "|$gene1";

        my $average_goc_score = 0;
        my $goc_total;

        foreach my $specie ( keys %{ $promoted_one2one->{$p} } ) {
            my $gene2 = $gene_member_adaptor->fetch_by_dbID( $promoted_one2one->{$p}{$specie}{'one2one'} )->stable_id;
            my $goc   = $promoted_one2one->{$p}{$specie}{'goc'};
            $goc_total += $goc;

            #print PROMOTED ",$specie:$gene2:$goc";
            print PROMOTED ",$gene2";
        }
        $average_goc_score = $goc_total/scalar( keys %{ $promoted_one2one->{$p} } );
        print PROMOTED "|$average_goc_score\n";
    }
    close(PROMOTED);
} ## end if ($one2many_flag)
