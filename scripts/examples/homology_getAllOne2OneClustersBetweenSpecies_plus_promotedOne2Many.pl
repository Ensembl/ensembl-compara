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
my %present_in_all_one2one;
my %present_in_all_one2many;
my %goc_list_one2one;
my %species_list_one2many;
my %global_optimum_one2many;

# $global_optimum_one2many Used to track down one2many that map to different species to assure we choose the one with the max overal goc score
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
        my @one2one_orthologies = @{ $homology_adaptor->fetch_all_by_MethodLinkSpeciesSet( $mlss_orth, -ORTHOLOGY_TYPE => 'ortholog_one2one' ) };

        #Preloading all the homologies.
        my $sms_one2one = Bio::EnsEMBL::Compara::Utils::Preloader::expand_Homologies( $one2one_orthologies[0]->adaptor->db->get_AlignedMemberAdaptor, \@one2one_orthologies );
        Bio::EnsEMBL::Compara::Utils::Preloader::load_all_GeneMembers( $one2one_orthologies[0]->adaptor->db->get_GeneMemberAdaptor, $sms_one2one );

        my $count_one2one       = 0;
        my $total_count_one2one = scalar @one2one_orthologies;
        foreach my $ortholog (@one2one_orthologies) {

            #transform the undef's returned by GOC analysis to -100
            my $goc = $ortholog->goc_score() // -100;

            # Create a hash of stable_id pairs with genome name as subkey
            my ( $gene1, $gene2 ) = @{ $ortholog->get_all_Members };

            #make sure it is present in all the species
            # *100+$gene1->perc_id is a formula to take the identity into account
            my $combined_score = max( $goc*100 + $gene1->perc_id, $goc*100 + $gene2->perc_id );

            $count_one2one++;
            print STDERR "one2one: [$count_one2one/$total_count_one2one]\n" if ( 0 == $count_one2one % 1000 );
            $present_in_all_one2one{ $gene1->gene_member_id }{ $gene1->genome_db->name }{ $gene2->gene_member_id } = $combined_score;
            $present_in_all_one2one{ $gene1->gene_member_id }{ $gene2->genome_db->name }{ $gene2->gene_member_id } = $combined_score;
            $present_in_all_one2one{ $gene2->gene_member_id }{ $gene1->genome_db->name }{ $gene1->gene_member_id } = $combined_score;
            $present_in_all_one2one{ $gene2->gene_member_id }{ $gene2->genome_db->name }{ $gene1->gene_member_id } = $combined_score;

            $goc_list_one2one{ $gene1->gene_member_id } = $combined_score;
            $goc_list_one2one{ $gene2->gene_member_id } = $combined_score;
        }

        #one2many orthologues
        my @one2many_orthologies = @{ $homology_adaptor->fetch_all_by_MethodLinkSpeciesSet( $mlss_orth, -ORTHOLOGY_TYPE => 'ortholog_one2many' ) };

        #Preloading all the homologies.
        my $sms = Bio::EnsEMBL::Compara::Utils::Preloader::expand_Homologies( $one2many_orthologies[0]->adaptor->db->get_AlignedMemberAdaptor, \@one2many_orthologies );
        Bio::EnsEMBL::Compara::Utils::Preloader::load_all_GeneMembers( $one2many_orthologies[0]->adaptor->db->get_GeneMemberAdaptor, $sms );

        my $count_one2many       = 0;
        my $total_count_one2many = scalar @one2many_orthologies;

        foreach my $ortholog_many (@one2many_orthologies) {

            #transform the undef's returned by GOC analysis to -100
            my $goc = $ortholog_many->goc_score() // -100;

            # Create a hash of stable_id pairs with genome name as subkey
            my ( $gene1, $gene2 ) = @{ $ortholog_many->get_all_Members };
            my $g1 = $gene1->gene_member_id;
            my $g2 = $gene2->gene_member_id;

            #make sure it is present in all the species
            # *100+$gene1->perc_id is a formula to take the identity into account
            my $combined_score = max( $goc*100 + $gene1->perc_id, $goc*100 + $gene2->perc_id );

            $count_one2many++;
            print STDERR "one2many: [$count_one2many/$total_count_one2many]\n" if ( 0 == $count_one2many % 1000 );

            $present_in_all_one2many{ $gene1->gene_member_id }{ $gene1->genome_db->name }{ $gene2->gene_member_id } = $combined_score;
            $present_in_all_one2many{ $gene1->gene_member_id }{ $gene2->genome_db->name }{ $gene2->gene_member_id } = $combined_score;
            $present_in_all_one2many{ $gene2->gene_member_id }{ $gene1->genome_db->name }{ $gene1->gene_member_id } = $combined_score;
            $present_in_all_one2many{ $gene2->gene_member_id }{ $gene2->genome_db->name }{ $gene1->gene_member_id } = $combined_score;

            #list of species per gene
            $species_list_one2many{ $gene1->gene_member_id } = $gene1->genome_db->name;
            $species_list_one2many{ $gene2->gene_member_id } = $gene2->genome_db->name;

        } ## end foreach my $ortholog_many (...)
    } ## end for ( my $j = $i + 1; $j...)
} ## end for ( my $i = 0; $i < scalar...)

#-----------------------------------------------------------------------------------------------------

#=======================================================================
#Computing global GOC values
#Temporary list used to compute the global values for the GOC scores
my %tmp_id_list;
my %same_species_avg;

print STDERR "Building global_optimum_one2many\n";

my $ortholog_cluster_id_counter = 0;

foreach my $gene_member_id ( keys %present_in_all_one2one ) {

    #if the species set is incomplete
    if ( scalar( keys %{ $present_in_all_one2one{$gene_member_id} } ) != scalar(@all_species_names) ) {

        $ortholog_cluster_id_counter++;

        foreach my $s (@all_species_names) {
            if ( !defined $present_in_all_one2one{$gene_member_id}{$s} ) {

                #Extract the info from the one2many hash
                if ( defined $present_in_all_one2many{$gene_member_id}{$s} ) {
                    my %rep_hash =
                      map { $_->dbID => $_->stable_id } @{ $gene_member_adaptor->fetch_all_by_dbID_list( [ keys( $present_in_all_one2many{$gene_member_id}{$s} ) ] ) };

              #here we need not just to check the current goc, but the one with the overall best goc, to avoid using a "local optimum" and assure we use the overall best orthologue
                    foreach my $replace ( keys %rep_hash ) {
                        $tmp_id_list{$replace}{$s}{$gene_member_id} = $present_in_all_one2many{$gene_member_id}{$s}{$replace};
                        $same_species_avg{$replace}{$gene_member_id} = $present_in_all_one2many{$gene_member_id}{$s}{$replace};
                    }
                }
            }
        }
    }
} ## end foreach my $gene_member_id ...

#Compute the global_max
#-----------------------------------------------------------------------------------------------------
foreach my $replace ( keys %same_species_avg ) {
    my $total_goc = 0;

    my $gene_member         = $gene_member_adaptor->fetch_by_dbID($replace);
    my $replace_stable_id   = $gene_member->stable_id; 

    print "REPLACING:$replace|$replace_stable_id\n" if ($debug);

    foreach my $ref_id ( keys %{ $same_species_avg{$replace} } ) {
        if ($debug){
            my $ref_stable_id = $gene_member_adaptor->fetch_by_dbID($ref_id)->stable_id;
            print "\t$ref_id|$ref_stable_id\t=\t" . $same_species_avg{$replace}{$ref_id} . "\n";
        }
        $total_goc += $same_species_avg{$replace}{$ref_id};
    }
    my $average_goc = $total_goc/scalar( keys %{ $same_species_avg{$replace} } );

    foreach my $ref_id ( keys %{ $same_species_avg{$replace} } ) {
        $global_optimum_one2many{$ref_id}{$replace} = $average_goc;
    }

    print "replace_avg:$average_goc\n" if ($debug);
}

if ($debug) {
    foreach my $g1 ( keys %global_optimum_one2many ) {
        print $gene_member_adaptor->fetch_by_dbID($g1)->stable_id . "\t$g1\n";
        foreach my $g2 ( keys %{ $global_optimum_one2many{$g1} } ) {
            print "\t$g2\t" . $global_optimum_one2many{$g1}{$g2} . "\n";
        }
    }
}

#-----------------------------------------------------------------------------------------------------

#Printing results
#-----------------------------------------------------------------------------------------------------
system("mkdir -p $out_dir");

#one2one
print STDERR "Loading the gene names\n";
my %gene_member_id_2_stable_id = map { $_->dbID => $_->stable_id } @{ $gene_member_adaptor->fetch_all_by_dbID_list( [ keys %present_in_all_one2one ] ) };

my %uniq_keys_one2one;

# This code below is optional and is only to sort out cases where all
# genomes are in the list and print the list of ids if it is the case
print STDERR "Printing the orthology groups\n";
foreach my $gene_member_id ( keys %present_in_all_one2one ) {

    #next if scalar( keys %{ $present_in_all_one2one->{$gene_member_id} } ) != scalar(@all_species_names);
    if ( scalar( keys %{ $present_in_all_one2one{$gene_member_id} } ) == scalar(@all_species_names) ) {
        my %gene_member_ids_goc_values;

        #add the first gene
        $gene_member_ids_goc_values{$gene_member_id} = $goc_list_one2one{$gene_member_id};

        #add the genes from the available species
        foreach my $name (@all_species_names) {
            foreach my $id ( keys %{ $present_in_all_one2one{$gene_member_id}{$name} } ) {
                $gene_member_ids_goc_values{$id} = $goc_list_one2one{$id};
            }
        }
        my $average_goc = 0;
        my $goc_total;
        foreach my $m ( keys %gene_member_ids_goc_values ) {
            my $goc = $gene_member_ids_goc_values{$m};
            $goc_total += $goc;
        }
        $average_goc = $goc_total/scalar( keys %gene_member_ids_goc_values );
        my $num_species_in_group = scalar( keys %gene_member_ids_goc_values );
        my $uniq_key = join( ",", sort map { $gene_member_id_2_stable_id{$_} } keys %gene_member_ids_goc_values );

        #We can flag the keys to separate them from the others later.
        #$uniq_keys_one2one{"121_$uniq_key"}{'goc'}       = $average_goc;
        #$uniq_keys_one2one{"121_$uniq_key"}{'n_species'} = $num_species_in_group;
        $uniq_keys_one2one{$uniq_key}{'goc'}       = $average_goc;
        $uniq_keys_one2one{$uniq_key}{'n_species'} = $num_species_in_group;

    } ## end if ( scalar( keys %{ $present_in_all_one2one...}))
    else {
        #complement with one2many
        #1 - identify the missing species
        my %gene_member_ids_goc_values;
        my @missing_species;
        my $goc;
        $gene_member_ids_goc_values{$gene_member_id} = $goc_list_one2one{$gene_member_id};

        my %multiple_ids_same_species;

        foreach my $s (@all_species_names) {
            if ( defined $present_in_all_one2one{$gene_member_id}{$s} ) {

                #if species is defined we should use as much as we can from the one2one hash
                foreach my $id ( keys %{ $present_in_all_one2one{$gene_member_id}{$s} } ) {

                    $gene_member_ids_goc_values{$id} = $goc_list_one2one{$id};
                }
            }
            else {
                #2 - extract the info from the one2many hash
                if ( defined $present_in_all_one2many{$gene_member_id}{$s} ) {
                    my %rep_hash =
                      map { $_->dbID => $_->stable_id } @{ $gene_member_adaptor->fetch_all_by_dbID_list( [ keys( $present_in_all_one2many{$gene_member_id}{$s} ) ] ) };

                    my $id = $gene_member_adaptor->fetch_by_dbID($gene_member_id)->stable_id;

                    print "missing species:$s for gene:$gene_member_id|$id\n" if ($debug);

                    #instead of looping, we should just get the highest value?
                    my $max_val_key = reduce { $global_optimum_one2many{$gene_member_id}{$a} >= $global_optimum_one2many{$gene_member_id}{$b} ? $a : $b }
                    keys %{ $global_optimum_one2many{$gene_member_id} };
                    my $promoted_id  = $max_val_key;
                    my $promoted_goc = $global_optimum_one2many{$gene_member_id}{$max_val_key};

                    if ($debug){
                        my $stable = $gene_member_adaptor->fetch_by_dbID($promoted_id)->stable_id;
                        print "MAX for:$gene_member_id|$max_val_key|$promoted_goc|$stable\n";
                        print "replacement: " . $promoted_id . "|" . $stable . "\n";
                    }

                    $gene_member_ids_goc_values{$promoted_id} = $promoted_goc;
                }
            } ## end else [ if ( defined $present_in_all_one2one...)]
        } ## end foreach my $s (@all_species_names)

        my $average_goc = 0;
        my $goc_total   = 0;

        my $gene_members = $gene_member_adaptor->fetch_all_by_dbID_list( [ keys %gene_member_ids_goc_values ] );
        my $num_species_in_group = scalar( @$gene_members );

        foreach my $m ( @$gene_members ) {
            my $goc = $gene_member_ids_goc_values{$m->dbID};
            print "observed_goc:" . $m->dbID . "|" . $m->stable_id . ":$goc\n" if ($debug);
            $goc_total += $goc;
        }
        $average_goc = $goc_total/$num_species_in_group;
        print "\tobserved_goc_avg:$average_goc\n" if ($debug);

        #add to uniq keys
        my $uniq_key = join( ",", sort map { $_->stable_id } @$gene_members );

        #We can flag the keys to separate them from the others later.
        #$uniq_keys_one2one{"M_$uniq_key"}{'goc'}       = $average_goc;
        #$uniq_keys_one2one{"M_$uniq_key"}{'n_species'} = $num_species_in_group;
        $uniq_keys_one2one{$uniq_key}{'goc'}       = $average_goc;
        $uniq_keys_one2one{$uniq_key}{'n_species'} = $num_species_in_group;

    } ## end else [ if ( scalar( keys %{ $present_in_all_one2one...}))]
} ## end foreach my $gene_member_id ...

open( my $fh, '>', "$out_dir/one2one_plus_promoted_one2many_with_goc_identity_score.txt" ) || die "Could not open output file at $out_dir";
foreach my $one2one ( sort keys %uniq_keys_one2one ) {

    # Skip the cluster if a threshold has been defined and is not met
    next if $species_threshold && ( $uniq_keys_one2one{$one2one}{'n_species'} != $species_threshold );

    if ($report_goc) {
        #print $fh "S_" . $uniq_keys_one2one{$one2one}{'n_species'} . "\t" . $uniq_keys_one2one{$one2one}{'goc'} . "\t" . $one2one . "\n";
        print $fh $uniq_keys_one2one{$one2one}{'goc'} . "\t" . $one2one . "\n";
    }
    else {
        print $fh $one2one . "\n";
    }
}
close($fh);

#-----------------------------------------------------------------------------------------------------
