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


#This script can be used to extract information from the Gene Order Conservation score (GOC)
#It only generates the inputs to be plotted separately.
#It does not use the API.

#SELECT node_name, nb_genes, nb_long_genes, nb_short_genes, nb_orphan_genes, nb_genes_in_tree, nb_genes_in_tree_single_species, nb_orphan_genes, nb_dup_nodes, nb_gene_splits, (nb_genes-nb_genes_in_tree) as nb_missing_genes FROM species_tree_node_attr JOIN species_tree_node USING (node_id) WHERE node_id IN (SELECT node_id FROM species_tree_node where genome_db_id IS NOT NULL AND root_id = 40001000 group by genome_db_id);

use strict;
use DBI;
use Getopt::Long;

# Parameters
#-----------------------------------------------------------------------------------------------------
#Directory to print out the results
my $out_dir;

#-----------------------------------------------------------------------------------------------------

# Parse command line
#-----------------------------------------------------------------------------------------------------
GetOptions( "outdir=s" => \$out_dir ) or die("Error in command line arguments\n");

die "Error in command line arguments [outdir = /your/directory/]" if ( !$out_dir );

#DB connection.
my $user     = "ensadmin";
my $password = $ENV{'ENSADMIN_PSW'};
my $database = "mp14_Tuatara_ProteinTree_86";
my $hostname = "compara4";
my $dsn      = "DBI:mysql:database=$database;host=$hostname";
my $dbh      = DBI->connect( $dsn, $user, $password );

my %mlss_ids;
my %names;
my @sorted_names;
my %sorted_scores;
my %perc_orth_above_goc_thresh;

my $sql1 = "SELECT method_link_species_set_id FROM method_link_species_set_attr where n_goc_null IS NOT NULL";
my $sth1 = $dbh->prepare($sql1);
$sth1->execute();
while ( my @row1 = $sth1->fetchrow_array() ) {
    my $mlss_id = $row1[0];
    my $sql2 =
      "SELECT gdb.name FROM method_link_species_set JOIN species_set USING (species_set_id) JOIN genome_db as gdb USING (genome_db_id) where method_link_species_set_id = $mlss_id";
    my $sth2 = $dbh->prepare($sql2);
    $sth2->execute();
    while ( my @row2 = $sth2->fetchrow_array() ) {
        push( @{ $names{$mlss_id}{'names'} }, $row2[0] );
    }

    my $sql3 = "SELECT goc_score , COUNT(*) FROM homology where method_link_species_set_id = $row1[0] GROUP BY goc_score";
    my $sth3 = $dbh->prepare($sql3);
    $sth3->execute();
    my $total = 0;
    while ( my @row3 = $sth3->fetchrow_array() ) {
        if ( $row3[0] eq "" ) {
            $row3[0] = "NULL";
        }
        $mlss_ids{$mlss_id}{ $row3[0] } = $row3[1];
        $total += $row3[1];
    }

    foreach my $goc_score ( sort keys %{ $mlss_ids{$mlss_id} } ) {
        $mlss_ids{$mlss_id}{$goc_score} /= $total;
    }
}

my %taxon;

#Manually define the taxonomic groups:
$taxon{'alligator_mississippiensis'}   = "Crocodylia";
$taxon{'alligator_sinensis'}           = "Crocodylia";
$taxon{'anas_platyrhynchos'}           = "Birds";
$taxon{'anolis_carolinensis'}          = "Squamata";
$taxon{'chelonia_mydas'}               = "Testudines";
$taxon{'chrysemys_picta'}              = "Testudines";
$taxon{'danio_rerio'}                  = "Fish";
$taxon{'ficedula_albicollis'}          = "Birds";
$taxon{'gallus_gallus'}                = "Birds";
$taxon{'gekko_japonicus'}              = "Squamata";
$taxon{'homo_sapiens'}                 = "Mammals";
$taxon{'lepisosteus_oculatus'}         = "Fish";
$taxon{'meleagris_gallopavo'}          = "Birds";
$taxon{'monodelphis_domestica'}        = "Mammals";
$taxon{'mus_musculus'}                 = "Mammals";
$taxon{'ophiophagus_hannah'}           = "Squamata";
$taxon{'ophisaurus_gracilis'}          = "Squamata";
$taxon{'ornithorhynchus_anatinus'}     = "Mammals";
$taxon{'pelodiscus_sinensis'}          = "Testudines";
$taxon{'pogona_vitticeps'}             = "Squamata";
$taxon{'protobothrops_mucrosquamatus'} = "Squamata";
$taxon{'python_molurus_bivittatus'}    = "Squamata";
$taxon{'taeniopygia_guttata'}          = "Birds";
$taxon{'thamnophis_sirtalis'}          = "Squamata";
$taxon{'tuatara'}                      = "Squamata";
$taxon{'xenopus_tropicalis'}           = "Amphibia";

#Define the colours to plot
my %colors;
$colors{'Crocodylia'} = "chartreuse4";
$colors{'Birds'}      = "blue";
#$colors{'Squamata'}   = "darkslateblue";
#$colors{'Squamata'}   = "wheat4";
$colors{'Squamata'}   = "darkorange2";
$colors{'Mammals'}    = "red";
$colors{'Fish'}       = "darkcyan";
$colors{'Testudines'} = "black";
#$colors{'Amphibia'}   = "darkorchid1";
$colors{'Amphibia'}   = "deeppink";

my $sql4 = "select name from genome_db JOIN ncbi_taxa_node USING (taxon_id) ORDER by left_index;";
my $sth4 = $dbh->prepare($sql4);
$sth4->execute();
while ( my @row = $sth4->fetchrow_array() ) {
    my $name = $row[0];
    push( @sorted_names, $name );
}

#Define which species to use as references:
my @references = ( "homo_sapiens", "tuatara" );

foreach my $reference (@references) {
    #File with breakout of the different GOC levels
    open( my $fh_out, '>', "$out_dir/$reference\_ref.txt" ) || die "Could not open output file at $out_dir";

    #File with the above and bollow 0.5 GOC threasholds
    open( my $fh_out_above_with, '>', "$out_dir/$reference\_above_with_splits.txt" ) || die "Could not open output file at $out_dir";

    #File with the  percentage of scores above 0.5
    open( my $fh_out_above, '>', "$out_dir/$reference\_ref_above_threshold.txt" ) || die "Could not open output file at $out_dir";

    print $fh_out "species;goc;threshold;taxon\n";
    print $fh_out_above "species;perc_orth_above_goc_thresh;taxon\n";
    print $fh_out_above_with "species;goc;threshold;taxon\n";

    my @uniq_mlss_ids = keys(%mlss_ids);

    foreach my $uniq_mlss_id (@uniq_mlss_ids) {
        my $names = join( "", @{ $names{$uniq_mlss_id}{'names'} } );
        if ( $names =~ /$reference/ ) {
            $names =~ s/$reference//;
            my $sql5 = "select perc_orth_above_goc_thresh from method_link_species_set_attr where method_link_species_set_id = $uniq_mlss_id";
            my $sth5 = $dbh->prepare($sql5);
            $sth5->execute();
            while ( my @row5 = $sth5->fetchrow_array() ) {
                print $fh_out_above "$names;$row5[0];$colors{$taxon{$names}}\n";
            }
        }
    }
    close($fh_out_above);

    foreach my $mlss_id ( keys %mlss_ids ) {
        my $names = join( "", @{ $names{$mlss_id}{'names'} } );

        #forcing all scores to be declared:
        my @scores = ( "NULL", "0", "25", "50", "75", "100" );
        foreach my $score (@scores) {
            if ( !$mlss_ids{$mlss_id}{$score} ) {
                $mlss_ids{$mlss_id}{$score} = 0;
            }
        }

        if ( $names =~ /$reference/ ) {
            $names =~ s/$reference//;
            my $sum_under_50 = 0;
            my $sum_above_50 = 0;

            foreach my $goc_score ( sort num keys %{ $mlss_ids{$mlss_id} } ) {
                print $fh_out "$names;$mlss_ids{$mlss_id}{$goc_score};X_$goc_score;$colors{$taxon{$names}}\n";
                if (($goc_score < 50) || ($goc_score eq "NULL")){
                        $sum_under_50 += $mlss_ids{$mlss_id}{$goc_score}; 
                }else{
                        $sum_above_50 += $mlss_ids{$mlss_id}{$goc_score}; 
                }
            }
            print $fh_out_above_with "$names;$sum_under_50;under;$colors{$taxon{$names}}\n";
            print $fh_out_above_with "$names;$sum_above_50;above;$colors{$taxon{$names}}\n";
        }
    }
    close($fh_out);
    close($fh_out_above_with);
}
}

sub num { $a <=> $b }

