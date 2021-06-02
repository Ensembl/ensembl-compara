#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
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


# This script can be used to extract information from the Gene Order Conservation score (GOC)
# It only generates the inputs to be plotted separately.
# It does not use the API.

# cmd line example:
# perl generateGocBreakout.pl -outdir /homes/mateus/goc -user ensro -database mateus_tuatara_86 -hostname mysql-treefam-prod:4401

# SELECT node_name, nb_genes, nb_long_genes, nb_short_genes, nb_orphan_genes, nb_genes_in_tree, nb_genes_in_tree_single_species, nb_orphan_genes, nb_dup_nodes, nb_gene_splits, (nb_genes-nb_genes_in_tree) AS nb_missing_genes
# FROM species_tree_node_attr
# JOIN species_tree_node USING (node_id)
# WHERE node_id IN (
#     SELECT node_id
#     FROM species_tree_node
#     WHERE genome_db_id IS NOT NULL AND root_id = 40001000
#     GROUP BY genome_db_id
# );

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

=head2 match_species_name_to_taxon list
    Arg[1]     :  Bio::EnsEMBL::Compara::GenomeDB $genome_db
    Arg[2]     :  (arrayref) $taxon_list
    Description:  Match starting from lowest taxonomic rank climbing, returning string variable at first match.
    Example    :  my $ref_clade = match_species_name_to_taxon_list($genome_db, $taxon_list);
    Return     :  (string) $taxon_name or undef
    Exceptions :  Throws if both (or neither) $genome_db and $taxon_list are provided
=cut

sub match_species_name_to_taxon_list {
    my ($genome_db, $taxon_list) = (@_);

    throw ("genome_db and taxon_list need to be provided") unless $genome_db && $taxon_list;

    my @taxon_list = @$taxon_list;
    my $parent     = $genome_db->taxon->parent;

    while ( $parent->name ne "root" ) {
        if ( grep { $parent->name eq $_ } @taxon_list ) {
            return $parent->name;
        }
        else {
            $parent = $parent->parent;
        }
    }
    return undef;
}

# Parameters
#-----------------------------------------------------------------------------------------------------
# Directory to print out the results
my $out_dir;

# MySQL user used to query the database
my $user;

# Database to use
my $database;

# Hostname used in the query
my $hostname;

#-----------------------------------------------------------------------------------------------------

# Parse command line
#-----------------------------------------------------------------------------------------------------
GetOptions( "outdir=s" => \$out_dir, "user=s" => \$user, "database=s" => \$database, "hostname=s" => \$hostname ) or die("Error in command line arguments\n");
die "Error in command line arguments [outdir = /your/directory/] [user = your_sql_username] [database = your_database] [hostname = your_host:port] " if ( !$out_dir || !$user || !$database || !$hostname );

# DB connection
#-----------------------------------------------------------------------------------------------------
my $dsn      = "DBI:mysql:database=$database;host=$hostname";
my $dbh      = DBI->connect( $dsn, $user );
#-----------------------------------------------------------------------------------------------------

my %mlss_ids;
my %names;
my @sorted_names;
my %sorted_scores;
my %perc_orth_above_goc_thresh;

my $sql1 = "
    SELECT method_link_species_set_id
    FROM method_link_species_set_attr
    WHERE perc_orth_above_goc_thresh IS NOT NULL AND perc_orth_above_goc_thresh != 0
";
my $sth1 = $dbh->prepare($sql1);
$sth1->execute();
while ( my @row1 = $sth1->fetchrow_array() ) {
    my $mlss_id = $row1[0];
    my $sql2 = "
        SELECT gdb.name
        FROM method_link_species_set
        JOIN species_set USING (species_set_id)
        JOIN genome_db AS gdb USING (genome_db_id)
        WHERE method_link_species_set_id = $mlss_id
    ";
    my $sth2 = $dbh->prepare($sql2);
    $sth2->execute();
    while ( my @row2 = $sth2->fetchrow_array() ) {
        push( @{ $names{$mlss_id}{'names'} }, $row2[0] );
    }

    my $sql3 = "
        SELECT goc_score, COUNT(*)
        FROM homology
        WHERE method_link_species_set_id = $mlss_id
        GROUP BY goc_score
    ";
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
    if ($mlss_ids{$mlss_id}{'NULL'}) {
        $mlss_ids{$mlss_id}{'0'} += $mlss_ids{$mlss_id}{'NULL'};
        delete $mlss_ids{$mlss_id}{'NULL'};
    }

    foreach my $goc_score ( sort keys %{ $mlss_ids{$mlss_id} } ) {
        $mlss_ids{$mlss_id}{$goc_score} /= $total;
    }
}

# Define the taxonomic groups
my $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(
                    -url => 'mysql://' . $user . '@' . $hostname . '/' . $database,
                    -species => 'Multi');

my @taxon_list = qw( Mammalia Sauropsida Amphibia Actinopterygii Tunicata Hyperotreti Gnathostomata Ecdysozoa Fungi Cyclostomata );

my %taxon;
foreach my $genome_db (@{$compara_dba->get_GenomeDBAdaptor->fetch_all}){
    my $species_name = $genome_db->name;
    $taxon{$species_name} = match_species_name_to_taxon_list( $genome_db, \@taxon_list);
}

# Define the colours to plot
my %colors;
$colors{'Mammalia'}       = "chartreuse4";
$colors{'Sauropsida'}     = "blue";
$colors{'Amphibia'}       = "darkslateblue";
$colors{'Actinopterygii'} = "wheat4";
$colors{'Tunicata'}       = "darkorange2";
$colors{'Hyperotreti'}    = "red";
$colors{'Gnathostomata'}  = "darkcyan";
$colors{'Ecdysozoa'}      = "black";
$colors{'Fungi'}          = "darkorchid1";
$colors{'Cyclostomata'}   = "deeppink";

my $sql4 = "
    SELECT name
    FROM genome_db
    JOIN ncbi_taxa_node USING (taxon_id)
    ORDER BY left_index
";
my $sth4 = $dbh->prepare($sql4);
$sth4->execute();
while ( my @row = $sth4->fetchrow_array() ) {
    my $name = $row[0];
    push( @sorted_names, $name );
}

# Define which species to use as references
my @references = ( "homo_sapiens", "sphenodon_punctatus" );

foreach my $reference (@references) {
    # File with breakout of the different GOC levels
    open( my $fh_out, '>', "$out_dir/$reference\_ref.dat" ) || die "Could not open output file at $out_dir";

    # File with the above and bollow 0.5 GOC threasholds
    open( my $fh_out_above_with, '>', "$out_dir/$reference\_above_with_splits.dat" ) || die "Could not open output file at $out_dir";

    # File with the percentage of scores above 0.5
    open( my $fh_out_above, '>', "$out_dir/$reference\_ref_above_threshold.dat" ) || die "Could not open output file at $out_dir";

    print $fh_out "species;goc;threshold;taxon\n";
    print $fh_out_above "species;perc_orth_above_goc_thresh;taxon\n";
    print $fh_out_above_with "species;goc;threshold;taxon\n";

    my @uniq_mlss_ids = keys(%mlss_ids);

    foreach my $uniq_mlss_id (@uniq_mlss_ids) {
        my $names = join( "", @{ $names{$uniq_mlss_id}{'names'} } );
        if ( $names =~ /$reference/ ) {
            $names =~ s/$reference//;
            my $sql5 = "
                SELECT perc_orth_above_goc_thresh
                FROM method_link_species_set_attr
                WHERE method_link_species_set_id = $uniq_mlss_id
            ";
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

        # Forcing all scores to be declared
        my @scores = ( "0", "25", "50", "75", "100" );
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
                if ($goc_score < 50) {
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

#---------------------------------------------------------------------------------------------------
#           Data used to generate a heatmap
#---------------------------------------------------------------------------------------------------

open( my $fh_heatmap, '>', "$out_dir/heatmap.data" ) || die "Could not open output file at $out_dir";

print $fh_heatmap "name1\tname2\tn_goc_0\tn_goc_25\tn_goc_50\tn_goc_75\tn_goc_100\tgoc_eq_0\tgoc_gte_25\tgoc_gte_50\tgoc_gte_75\tgoc_eq_100\n";

my $sql_heatmap = "
    SELECT
        gdb1.name AS name1,
        gdb2.name AS name2,
        IFNULL(n_goc_0,0),
        IFNULL(n_goc_25,0),
        IFNULL(n_goc_50,0),
        IFNULL(n_goc_75,0),
        IFNULL(n_goc_100,0),
        IFNULL(n_goc_0,0) / (IFNULL(n_goc_0,0) + IFNULL(n_goc_25,0) + IFNULL(n_goc_50,0) + IFNULL(n_goc_75,0) + IFNULL(n_goc_100,0)) AS goc_eq_0,
        (IFNULL(n_goc_25,0) + IFNULL(n_goc_50,0) + IFNULL(n_goc_75,0) + IFNULL(n_goc_100,0)) / (IFNULL(n_goc_0,0) + IFNULL(n_goc_25,0) + IFNULL(n_goc_50,0) + IFNULL(n_goc_75,0) + IFNULL(n_goc_100,0)) AS goc_gte_25,
        (IFNULL(n_goc_50,0) + IFNULL(n_goc_75,0) + IFNULL(n_goc_100,0)) / (IFNULL(n_goc_0,0) + IFNULL(n_goc_25,0) + IFNULL(n_goc_50,0) + IFNULL(n_goc_75,0) + IFNULL(n_goc_100,0)) AS goc_gte_50,
        (IFNULL(n_goc_75,0) + IFNULL(n_goc_100,0)) / (IFNULL(n_goc_0,0) + IFNULL(n_goc_25,0) + IFNULL(n_goc_50,0) + IFNULL(n_goc_75,0) + IFNULL(n_goc_100,0)) AS goc_gte_75,
        IFNULL(n_goc_100,0) / (IFNULL(n_goc_0,0) + IFNULL(n_goc_25,0) + IFNULL(n_goc_50,0) + IFNULL(n_goc_75,0) + IFNULL(n_goc_100,0)) AS goc_eq_100
    FROM method_link_species_set_attr mlssa
    INNER JOIN method_link_species_set mlss USING (method_link_species_set_id)
    INNER JOIN species_set ss1 ON mlss.species_set_id = ss1.species_set_id
    INNER JOIN species_set ss2 ON mlss.species_set_id = ss2.species_set_id
    INNER JOIN genome_db gdb1 ON ss1.genome_db_id = gdb1.genome_db_id
    INNER JOIN genome_db gdb2 ON ss2.genome_db_id = gdb2.genome_db_id
 	WHERE mlss.method_link_id = 201
 	      AND gdb1.name <> gdb2.name
 	      AND gdb1.name NOT LIKE ('mus_musculus_%' OR 'sus_scrofa_%')
 	      AND gdb2.name NOT LIKE ('mus_musculus_%' OR 'sus_scrofa_%')
 	ORDER BY gdb1.name, gdb2.name
";

my $sth_heatmap = $dbh->prepare($sql_heatmap);
$sth_heatmap->execute();
while ( my @row = $sth_heatmap->fetchrow_array() ) {
    print $fh_heatmap join("\t", @row) . "\n";
}

close($fh_heatmap);

# File with average and median GOC score for each pair of genomes
open( my $fh_heatmap_stats, '>', "$out_dir/heatmap_avg_median.data" ) || die "Could not open output file at $out_dir";

print $fh_heatmap_stats "name1\tname2\tgoc_avg\tgoc_median\n";

my $sql_pairwise_stats = "
    SELECT
        gdb1.name AS name1,
        gdb2.name AS name2,
        ( IFNULL(n_goc_25,0) * 25 + IFNULL(n_goc_50,0) * 50 + IFNULL(n_goc_75,0) * 75 + IFNULL(n_goc_100,0) * 100 ) / ( IFNULL(n_goc_0,0) + IFNULL(n_goc_25,0) + IFNULL(n_goc_50,0) + IFNULL(n_goc_75,0) + IFNULL(n_goc_100,0) ) AS goc_avg,
        IFNULL(n_goc_0,0) / ( IFNULL(n_goc_0,0) + IFNULL(n_goc_25,0) + IFNULL(n_goc_50,0) + IFNULL(n_goc_75,0) + IFNULL(n_goc_100,0) ) AS goc_eq_0,
        ( IFNULL(n_goc_0,0) + IFNULL(n_goc_25,0) ) / ( IFNULL(n_goc_0,0) + IFNULL(n_goc_25,0) + IFNULL(n_goc_50,0) + IFNULL(n_goc_75,0) + IFNULL(n_goc_100,0) ) AS goc_lte_25,
        ( IFNULL(n_goc_0,0) + IFNULL(n_goc_25,0) + IFNULL(n_goc_50,0) ) / ( IFNULL(n_goc_0,0) + IFNULL(n_goc_25,0) + IFNULL(n_goc_50,0) + IFNULL(n_goc_75,0) + IFNULL(n_goc_100,0) ) AS goc_lte_50,
        ( IFNULL(n_goc_0,0) + IFNULL(n_goc_25,0) + IFNULL(n_goc_50,0) + IFNULL(n_goc_75,0) ) / ( IFNULL(n_goc_0,0) + IFNULL(n_goc_25,0) + IFNULL(n_goc_50,0) + IFNULL(n_goc_75,0) + IFNULL(n_goc_100,0) ) AS goc_lte_75
    FROM method_link_species_set_attr mlssa
    INNER JOIN method_link_species_set mlss USING (method_link_species_set_id)
    INNER JOIN species_set ss1 ON mlss.species_set_id = ss1.species_set_id
    INNER JOIN species_set ss2 ON mlss.species_set_id = ss2.species_set_id
    INNER JOIN genome_db gdb1 ON ss1.genome_db_id = gdb1.genome_db_id
    INNER JOIN genome_db gdb2 ON ss2.genome_db_id = gdb2.genome_db_id
 	WHERE mlss.method_link_id = 201
 	      AND gdb1.name <> gdb2.name
 	      AND gdb1.name NOT LIKE ('mus_musculus_%' OR 'sus_scrofa_%')
 	      AND gdb2.name NOT LIKE ('mus_musculus_%' OR 'sus_scrofa_%')
 	ORDER BY gdb1.name, gdb2.name
";

my $sth_pairwise_stats = $dbh->prepare($sql_pairwise_stats);
$sth_pairwise_stats->execute();

while ( my @row = $sth_pairwise_stats->fetchrow_array() ) {
	if ( $row[3] >= 0.5 ) {
		print $fh_heatmap_stats "$row[0]\t$row[1]\t$row[2]\t0\n";
	}
	elsif ( $row[4] >= 0.5 ) {
		print $fh_heatmap_stats "$row[0]\t$row[1]\t$row[2]\t25\n";
	}
	elsif ( $row[5] >= 0.5 ) {
		print $fh_heatmap_stats "$row[0]\t$row[1]\t$row[2]\t50\n";
	}
	elsif ( $row[6] >= 0.5 ) {
		print $fh_heatmap_stats "$row[0]\t$row[1]\t$row[2]\t75\n";
	}
	else {
		print $fh_heatmap_stats "$row[0]\t$row[1]\t$row[2]\t100\n";
	}
}

close($fh_heatmap_stats);

#---------------------------------------------------------------------------------------------------
#           Stats for the whole dataset
#---------------------------------------------------------------------------------------------------

# File with average and median GOC score
open( my $fh_dataset_stats, '>', "$out_dir/dataset_stats.txt" ) || die "Could not open output file at $out_dir";

print $fh_dataset_stats "Average GOC score: ";

my $sql_goc_avg = "
    SELECT
        ( SUM(IFNULL(n_goc_25,0)) * 25 + SUM(IFNULL(n_goc_50,0)) * 50 + SUM(IFNULL(n_goc_100,0)) * 100 ) /
		( SUM(IFNULL(n_goc_0,0)) + SUM(IFNULL(n_goc_25,0)) + SUM(IFNULL(n_goc_50,0)) + SUM(IFNULL(n_goc_100,0)) ) as goc_avg
    FROM method_link_species_set_attr mlssa
    INNER JOIN method_link_species_set mlss USING (method_link_species_set_id)
    INNER JOIN species_set ss1 ON mlss.species_set_id = ss1.species_set_id
    INNER JOIN species_set ss2 ON mlss.species_set_id = ss2.species_set_id
    INNER JOIN genome_db gdb1 ON ss1.genome_db_id = gdb1.genome_db_id
    INNER JOIN genome_db gdb2 ON ss2.genome_db_id = gdb2.genome_db_id
 	WHERE mlss.method_link_id = 201
 	      AND gdb1.name <> gdb2.name
 	      AND gdb1.name NOT LIKE ('mus_musculus_%' OR 'sus_scrofa_%')
 	      AND gdb2.name NOT LIKE ('mus_musculus_%' OR 'sus_scrofa_%')
 	ORDER BY gdb1.name, gdb2.name;
";

my $sth_goc_avg = $dbh->prepare($sql_goc_avg);
$sth_goc_avg->execute();
my @row = $sth_goc_avg->fetchrow_array();
print $fh_dataset_stats join("\t", @row) . "\n";

print $fh_dataset_stats "Median GOC score: ";

my $sql_goc_median = "
    SELECT
        SUM(IFNULL(n_goc_0,0)) / ( SUM(IFNULL(n_goc_0,0)) + SUM(IFNULL(n_goc_25,0)) + SUM(IFNULL(n_goc_50,0)) + SUM(IFNULL(n_goc_75,0)) + SUM(IFNULL(n_goc_100,0)) ) AS goc_eq_0,
        ( SUM(IFNULL(n_goc_0,0)) + SUM(IFNULL(n_goc_25,0)) ) / ( SUM(IFNULL(n_goc_0,0)) + SUM(IFNULL(n_goc_25,0)) + SUM(IFNULL(n_goc_50,0)) + SUM(IFNULL(n_goc_75,0)) + SUM(IFNULL(n_goc_100,0)) ) AS goc_lte_25,
        ( SUM(IFNULL(n_goc_0,0)) + SUM(IFNULL(n_goc_25,0)) + SUM(IFNULL(n_goc_50,0)) ) / ( SUM(IFNULL(n_goc_0,0)) + SUM(IFNULL(n_goc_25,0)) + SUM(IFNULL(n_goc_50,0)) + SUM(IFNULL(n_goc_75,0)) + SUM(IFNULL(n_goc_100,0)) ) AS goc_lte_50,
        ( SUM(IFNULL(n_goc_0,0)) + SUM(IFNULL(n_goc_25,0)) + SUM(IFNULL(n_goc_50,0)) + SUM(IFNULL(n_goc_75,0)) ) / ( SUM(IFNULL(n_goc_0,0)) + SUM(IFNULL(n_goc_25,0)) + SUM(IFNULL(n_goc_50,0)) + SUM(IFNULL(n_goc_75,0)) + SUM(IFNULL(n_goc_100,0)) ) AS goc_lte_75
    FROM method_link_species_set_attr mlssa
    INNER JOIN method_link_species_set mlss USING (method_link_species_set_id)
    INNER JOIN species_set ss1 ON mlss.species_set_id = ss1.species_set_id
    INNER JOIN species_set ss2 ON mlss.species_set_id = ss2.species_set_id
    INNER JOIN genome_db gdb1 ON ss1.genome_db_id = gdb1.genome_db_id
    INNER JOIN genome_db gdb2 ON ss2.genome_db_id = gdb2.genome_db_id
 	WHERE mlss.method_link_id = 201
 	      AND gdb1.name <> gdb2.name
 	      AND gdb1.name NOT LIKE ('mus_musculus_%' OR 'sus_scrofa_%')
 	      AND gdb2.name NOT LIKE ('mus_musculus_%' OR 'sus_scrofa_%')
 	ORDER BY gdb1.name, gdb2.name
";

my $sth_goc_median = $dbh->prepare($sql_goc_median);
$sth_goc_median->execute();
my @row = $sth_goc_median->fetchrow_array();
if ( $row[0] >= 0.5 ) {
	print $fh_dataset_stats "0\n";
} elsif ( $row[1] >= 0.5 ) {
	print $fh_dataset_stats "25\n";
} elsif ( $row[2] >= 0.5 ) {
	print $fh_dataset_stats "50\n";
} elsif ( $row[3] >= 0.5 ) {
	print $fh_dataset_stats "75\n";
} else {
	print $fh_dataset_stats "100\n";
}

#---------------------------------------------------------------------------------------------------
# Additional plots
#---------------------------------------------------------------------------------------------------

# Homology count
#---------------------------------------------------------------------------------------------------
my %homology;
my $sql_homology = "
    SELECT genome_db.name, description, COUNT(*)
    FROM homology
    JOIN method_link_species_set USING (method_link_species_set_id)
    JOIN species_set USING (species_set_id)
    JOIN genome_db USING (genome_db_id)
    GROUP BY genome_db_id, description
";

my $sth_homology = $dbh->prepare($sql_homology);
$sth_homology->execute();
while ( my @row = $sth_homology->fetchrow_array() ) {
    $homology{$row[0]}{$row[1]} = $row[2];
}

open( my $fh_homology, '>', "$out_dir/homology.data" ) || die "Could not open output file at $out_dir";

print $fh_homology "species\tgene_split\tortholog_many2many\tortholog_one2many\t ortholog_one2one\t  within_species_paralog\n";

foreach my $species ( sort keys %homology ) {
    print $fh_homology "$species\t";

    my @values;

    foreach my $description ( sort keys %{ $homology{$species} } ) {
        push( @values, $homology{$species}{$description} );
    }

    print $fh_homology join("\t", @values) . "\n";
}
close($fh_homology);

# Gene count
#---------------------------------------------------------------------------------------------------
my %gene_count;
my $sql_gene_count = "
    SELECT node_name, nb_genes, nb_long_genes, nb_short_genes, nb_orphan_genes, nb_genes_in_tree, nb_genes_in_tree_single_species, nb_dup_nodes, nb_gene_splits
    FROM species_tree_node_attr
    JOIN species_tree_node USING (node_id)
    WHERE node_id IN (
        SELECT node_id
        FROM species_tree_node
        WHERE genome_db_id IS NOT NULL
        GROUP BY genome_db_id
    )
    ORDER BY node_name
";

open( my $fh_gene_count, '>', "$out_dir/gene_count.data" ) || die "Could not open output file at $out_dir";
print $fh_gene_count "species\tnb_genes\tnb_long_genes\tnb_short_genes\tnb_orphan_genes\tnb_genes_in_tree\tnb_genes_in_tree_single_species\tnb_dup_nodes\tnb_gene_splits\n";

my $sth_gene_count = $dbh->prepare($sql_gene_count);
$sth_gene_count->execute();
while ( my @row = $sth_gene_count->fetchrow_array() ) {
    print $fh_gene_count join("\t", @row) . "\n";
}
close($fh_gene_count);


sub num { $a <=> $b }
