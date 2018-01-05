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

#
# This script fetches clusters of one2one and/or one2many orthologues between a given set of species.
#

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::ConnectedComponents;

use Getopt::Long;
use Data::Dumper;
use List::Util qw(max);
use List::Util qw( reduce );

# Parameters
#-----------------------------------------------------------------------------------------------------
#URL to the compara database containing the homologies
my $compara_url;

#Directory to print out the results
my $out_dir;

#Add extra debug information to STDOUT
my $debug;

#Text file containing a list of one species per line
my $species_set_file;

#Number of species to be used as a cutoff when printing the orthologue clusters (e.g.: species_threshold=25 will only report the clusters with 25 species on it).
# If not defined the script will report all the clusters
my $species_threshold;

#Used to report the average GOC values accross all the homologues in a particular group. If not defined it will not be reported.
my $report_goc;

#-----------------------------------------------------------------------------------------------------

# Parse command line
#-----------------------------------------------------------------------------------------------------
GetOptions( "compara_url=s"       => \$compara_url,
            "species_set_file=s"  => \$species_set_file,
            "outdir=s"            => \$out_dir,
            "debug"               => \$debug,
            "species_threshold=i" => \$species_threshold,
            "report_goc"          => \$report_goc ) or
  die("Error in command line arguments\n");

die "Error in command line arguments [compara_url = mysql://user\@server/db] [species_set_file = file_with_list_of_species (one per line)] [outdir = /your/directory/]"
  if ( ( !$compara_url ) || ( !$species_set_file ) || !$out_dir );

#-----------------------------------------------------------------------------------------------------

#Prepare the list with the species names.
#-----------------------------------------------------------------------------------------------------
my @list_of_species;
open my $fh_species_list, $species_set_file || die "Could not open file $species_set_file";
while (<$fh_species_list>) {
    chomp($_);
    push( @list_of_species, $_ );
}
close($fh_species_list);

#-----------------------------------------------------------------------------------------------------

# Adaptors
#-----------------------------------------------------------------------------------------------------
my $compara_dba         = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -url => $compara_url );
my $homology_adaptor    = $compara_dba->get_HomologyAdaptor;
my $mlss_adaptor        = $compara_dba->get_MethodLinkSpeciesSetAdaptor;
my $genome_db_adaptor   = $compara_dba->get_GenomeDBAdaptor;
my $gene_member_adaptor = $compara_dba->get_GeneMemberAdaptor;

#-----------------------------------------------------------------------------------------------------

#List of genome_db objects
#-----------------------------------------------------------------------------------------------------
my @gdbs = sort( @{ $genome_db_adaptor->fetch_all_by_mixed_ref_lists( -SPECIES_LIST => \@list_of_species ) } );
my @all_species_names = sort( map { $_->name } @gdbs );
print STDERR "species_list:@all_species_names\n";

#-----------------------------------------------------------------------------------------------------

#Main variables used to store the homology
#-----------------------------------------------------------------------------------------------------
my %combined_score_list;

# $combined_score_list is Used to track down one2many that map to different species to assure we choose the one with the max overal goc score
#e.g.:
#((gene_1,gene_2),(gene_3,(gene_4,gene_5)));
#
#gene_1 => species_A
#gene_2 => species_B
#gene_3 => species_C
#gene_4 => species_D
#gene_5 => species_D
#
#Orthologues:
#one2one:
#           gene_1 <-> gene_2
#           gene_1 <-> gene_3
#           gene_2 <-> gene_3
#
#one2many:
#           gene_1 <-> [gene_4,gene_5]
#                        =>GOC:
#                          `----> gene_4 = 0
#                          `----> gene_5 = 100
#
#           gene_2 <-> [gene_4,gene_5]
#                        =>GOC:
#                          `----> gene_4 = 25
#                          `----> gene_5 = 100
#
#           gene_3 <-> [gene_4,gene_5]
#                        =>GOC:
#                          `----> gene_4 = 100
#                          `----> gene_5 = 75
#
#
#
# In this example the gene_4 will be selected as the best candicate for promoting to one2one when using gene_3 as reference.
# But in the overall gene_5 was a better candidate, scoring better accross the rest of the tree.
# This is a single tree example, this cases will happen accross multiple trees.
#-----------------------------------------------------------------------------------------------------

my $connected_homologies = new Bio::EnsEMBL::Compara::Utils::ConnectedComponents;
my %phylogeny_ready_homology_promoted;
my %phylogeny_ready_homology_pure_121;

#List of all the available clusters, before doing any promotions
my %allclusters = ();

#Main loop to iterate through all the pairs
#-----------------------------------------------------------------------------------------------------
for ( my $i = 0; $i < scalar(@gdbs); $i++ ) {
    my $sp1_gdb = $gdbs[$i];
    for ( my $j = $i + 1; $j < scalar(@gdbs); $j++ ) {

        my $sp2_gdb = $gdbs[$j];

        print STDERR "i=$i|j=$j [species_set:$species_set_file]\n";

        print STDERR "# Fetching ", $sp1_gdb->name, " - ", $sp2_gdb->name, " orthologues \n";
        my $mlss_orth = $mlss_adaptor->fetch_by_method_link_type_GenomeDBs( 'ENSEMBL_ORTHOLOGUES', [ $sp1_gdb, $sp2_gdb ] );

        #one2one orthologues
        my @orthologies = @{ $homology_adaptor->fetch_all_by_MethodLinkSpeciesSet( $mlss_orth, -ORTHOLOGY_TYPE => ['ortholog_one2one','ortholog_one2many'] ) };

        #Preloading all homologies.
        my $sms_homology = Bio::EnsEMBL::Compara::Utils::Preloader::expand_Homologies( $orthologies[0]->adaptor->db->get_AlignedMemberAdaptor, \@orthologies );
        Bio::EnsEMBL::Compara::Utils::Preloader::load_all_GeneMembers( $orthologies[0]->adaptor->db->get_GeneMemberAdaptor, $sms_homology );

        my $count_homology       = 0;
        my $total_count_homology = scalar @orthologies;
        foreach my $ortholog (@orthologies) {

            #transform the undef's returned by GOC analysis to -100
            my $goc = $ortholog->goc_score() // -100;

            # Create a hash of stable_id pairs with genome name as subkey
            my ( $gene1, $gene2 ) = @{ $ortholog->get_all_Members };

            #make sure it is present in all the species
            # *100+$gene1->perc_id is a formula to take the identity into account
            my $combined_score = max( $goc*100 + $gene1->perc_id, $goc*100 + $gene2->perc_id );

            $count_homology++;
            print STDERR "homology: [$count_homology/$total_count_homology]\n" if ( 0 == $count_homology % 1000 );

            $combined_score_list{ $gene1->gene_member_id }{ $gene2->gene_member_id } = $combined_score;
            $combined_score_list{ $gene2->gene_member_id }{ $gene1->gene_member_id } = $combined_score;

            print "SCORE:|".$gene1->gene_member_id."|=|".$gene2->gene_member_id." = $combined_score\n" if ($debug);
            print "SCORE|".$gene2->gene_member_id."|=|".$gene1->gene_member_id." = $combined_score\n" if ($debug);

            #add the homologies int the connection object
            $connected_homologies->add_connection( $gene1->gene_member_id, $gene2->gene_member_id );
        }
    } ## end for ( my $j = $i + 1; $j...)
} ## end for ( my $i = 0; $i < scalar...)

#-----------------------------------------------------------------------------------------------------

my $cluster_id = 0;

my %member_data_map = map { $_->dbID => { 'species' => $_->genome_db->name, 'stable_id' => $_->stable_id } } @{ $gene_member_adaptor->fetch_all_by_dbID_list( [ map { @$_ } @{ $connected_homologies->get_components } ] ) };

foreach my $comp ( sort @{ $connected_homologies->get_components } ) {
    $allclusters{$cluster_id} = { 'members' => $comp };
    $cluster_id++;
}

foreach my $cluster ( keys %allclusters ) {
    my @members_list      = @{ $allclusters{$cluster}->{members} };
    my $member_list_count = scalar(@members_list);

    print "----------\nCluster:$cluster\n\tsize:" . $member_list_count . "\n" if ($debug);

    print Dumper @members_list if ($debug);

    #--------------------------------------------------------------------------
    # Get species count per cluster
    my %species_count_tmp;
    foreach my $member (@members_list) {
        $species_count_tmp{ $member_data_map{$member}{'species'} }++;
    }
    my $species_count = scalar( keys %species_count_tmp );

    #--------------------------------------------------------------------------

    if ( $member_list_count < $species_threshold ) {
        #skip
        print "cluster has less members than species threshold: $species_threshold\n" if ($debug);
    }
    elsif ( $species_count < $species_threshold ) {
        #skip
        print "Impossible to promote: There are $member_list_count members but only $species_count species, with the threshold set to: $species_threshold, meaning that we cannot promote this cluster\n" if ($debug);
    }
    elsif ( $member_list_count == $species_threshold ) {
        #check for paralogues
        print "Need to check for paralogs:\n" if ($debug);

        #Flag for cluster paralogy
        my $is_paralog = 0;

        foreach my $species ( keys %species_count_tmp ) {
            if ( $species_count_tmp{$species} > 1 ) {
                $is_paralog = 1;
            }
        }

        if ( !$is_paralog ) {
            #No action needed, cluster already has the right amount of members/species
            print "\tNo action needed, cluster already has the right amount of members/species.\n" if ($debug);
            foreach my $member (@members_list) {
                $phylogeny_ready_homology_pure_121{$cluster}{$member} = 1;
            }
        }
        else {
            print "\tParalogues found, discarding it.\n" if ($debug);
        }
    } ## end elsif ( $member_list_count... [ if ( $member_list_count...)])
    else {
        #promote
        print "cluster $cluster needs pruning:\n" if ($debug);

        #1 - check if there are at least the same number of wanted species
        if ( $species_count >= $species_threshold ) {

            #2 - identify the species being repeated
            my %species_status;
            my %repeated_core_species;

            #get list of core species and repeated species
            foreach my $member (@members_list) {
                $repeated_core_species{ $member_data_map{$member}{'species'} }++;
            }

            foreach my $member (@members_list) {
                my $species_from_member = $member_data_map{$member}{'species'};

                if ( $repeated_core_species{ $species_from_member } == 1 ) {
                    $species_status{'core'}{ $member_data_map{$member}{'species'} }{$member} = 1;
                    $phylogeny_ready_homology_promoted{$cluster}{$member} = 1;
                }
                else {
                    $species_status{'repeated'}{ $species_from_member }{$member} = 1;
                }
            }

            my %averaged_goc;
            print "\nThere are " . scalar( keys %{ $species_status{'repeated'} } ) . " repeated species\n" if ($debug);

            foreach my $repeated_species ( keys %{ $species_status{'repeated'} } ) {
                foreach my $repeated_member ( keys %{ $species_status{'repeated'}{$repeated_species} } ) {
                    print "\trepeated:\t$repeated_member\tspecies:$repeated_species\n" if ($debug);
                }
            }
            foreach my $core_species ( keys %{ $species_status{'core'} } ) {
                foreach my $core_member ( keys %{ $species_status{'core'}{$core_species} } ) {
                    print "\tcore:\t$core_member\tspecies:$core_species\n" if ($debug);
                }
            }

            #Build the GOC-score average among all the members of all the species withing the homology so we can choose the one with the highest overall GOC score.
            foreach my $repeated_species ( keys %{ $species_status{'repeated'} } ) {
                foreach my $repeated_member ( keys %{ $species_status{'repeated'}{$repeated_species} } ) {
                    my $total_goc       = 0;
                    my $species_counter = 0;
                    foreach my $core_species ( keys %{ $species_status{'core'} } ) {
                        foreach my $core_member ( keys %{ $species_status{'core'}{$core_species} } ) {
                            if (exists $combined_score_list{$repeated_member}{$core_member}){
                                my $species_from_core_member = $member_data_map{$core_member}{'species'};
                                my $species_from_repeated_member = $member_data_map{$repeated_member}{'species'};

                                $total_goc += $combined_score_list{$repeated_member}{$core_member};
                                print " + " . $combined_score_list{$repeated_member}{$core_member} if ($debug);
                                $species_counter++;
                            }
                        }
                    }

                    if ($species_counter == 0){
                        #There are no core species/member or no combined score available for the pair
                        $averaged_goc{$repeated_species}{$repeated_member} = 0;
                    }
                    else{
                        $averaged_goc{$repeated_species}{$repeated_member} = $total_goc/$species_counter;
                    }
                    print "\naveraged_goc:$repeated_member\t$total_goc/$species_counter\t=\t" . $averaged_goc{$repeated_species}{$repeated_member} . "\n" if ($debug);
                }

                #3 - get the best member of the repeated species
                my $max_val_key = List::Util::reduce { $averaged_goc{$repeated_species}{$b} > $averaged_goc{$repeated_species}{$a} ? $b : $a } keys %{ $averaged_goc{$repeated_species} };

                #actual promotion
                $phylogeny_ready_homology_promoted{$cluster}{$max_val_key} = 1;

                print "\n\t\tPROMOTED:$repeated_species|$max_val_key:\t" . $averaged_goc{$repeated_species}{$max_val_key} . "\n" if ($debug);

            } ## end foreach my $repeated_species...
        } ## end if ( $species_count >=...)
    } ## end else [ if ( $member_list_count... [... [elsif ( $member_list_count...)]])]

} ## end foreach my $cluster ( keys ...)

open( my $fh_promoted, '>', "$out_dir/promoted_ids.txt" ) || die "Could not open output file at $out_dir";
foreach my $cluster ( keys %phylogeny_ready_homology_promoted ) {
    my @n_members = keys %{ $phylogeny_ready_homology_promoted{$cluster} };
    if ( scalar(@n_members) == $species_threshold ) {

        #print $fh_promoted scalar(@n_members) . "\t";
        foreach my $member ( keys %{ $phylogeny_ready_homology_promoted{$cluster} } ) {
            print $fh_promoted $member_data_map{$member}{'stable_id'} . "\t";
        }
        print $fh_promoted "\n";
    }
}
close($fh_promoted);

open( my $fh_pure, '>', "$out_dir/pure_one2ones.txt" ) || die "Could not open output file at $out_dir";
foreach my $cluster ( keys %phylogeny_ready_homology_pure_121 ) {
    my @n_members = keys %{ $phylogeny_ready_homology_pure_121{$cluster} };
    if ( scalar(@n_members) == $species_threshold ) {

        #print $fh_pure scalar(@n_members) . "\t";
        foreach my $member ( keys %{ $phylogeny_ready_homology_pure_121{$cluster} } ) {
            print $fh_pure $member_data_map{$member}{'stable_id'} . "\t";
        }
        print $fh_pure "\n";
    }
}
close($fh_pure);
printf( "%d elements split into %d distinct components\n", $connected_homologies->get_element_count, $connected_homologies->get_component_count ) if ($debug);

