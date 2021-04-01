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


#This script can be used to extract information from the Gene Order Conservation score (GOC)
#It only generates the inputs to be plotted separately.
#It does not use the API.

#cmd line example:
#perl generateGocBreakout.pl -outdir /homes/mateus/goc -user ensro -database mateus_tuatara_86 -hostname mysql-treefam-prod:4401

#SELECT node_name, nb_genes, nb_long_genes, nb_short_genes, nb_orphan_genes, nb_genes_in_tree, nb_genes_in_tree_single_species, nb_orphan_genes, nb_dup_nodes, nb_gene_splits, (nb_genes-nb_genes_in_tree) as nb_missing_genes FROM species_tree_node_attr JOIN species_tree_node USING (node_id) WHERE node_id IN (SELECT node_id FROM species_tree_node where genome_db_id IS NOT NULL AND root_id = 40001000 group by genome_db_id);

use strict;
use DBI;
use Getopt::Long;

# Parameters
#-----------------------------------------------------------------------------------------------------
#Directory to print out the results
my $out_dir;

#MySQL user used to query the database
my $user;

#Database to use
my $database;

#Hostname used in the query
my $hostname;

#-----------------------------------------------------------------------------------------------------

# Parse command line
#-----------------------------------------------------------------------------------------------------
GetOptions( "outdir=s" => \$out_dir, "user=s" => \$user, "database=s" => \$database, "hostname=s" => \$hostname ) or die("Error in command line arguments\n");
die "Error in command line arguments [outdir = /your/directory/] [user = your_sql_username] [database = your_database] [hostname = your_host:port] " if ( !$out_dir || !$user || !$database || !$hostname );

#DB connection.
#-----------------------------------------------------------------------------------------------------
my $dsn      = "DBI:mysql:database=$database;host=$hostname";
my $dbh      = DBI->connect( $dsn, $user );
#-----------------------------------------------------------------------------------------------------

#---------------------------------------------------------------------------------------------------
#           Data used to generate a heatmap
#---------------------------------------------------------------------------------------------------

open( my $fh_heatmap_avg, '>', "$out_dir/heatmap_avg.data" ) || die "Could not open output file at $out_dir";
open( my $fh_heatmap_median, '>', "$out_dir/heatmap_median.data" ) || die "Could not open output file at $out_dir";

print $fh_heatmap_avg "name1\tname2\tgoc_avg\n";
print $fh_heatmap_median "name1\tname2\tgoc_median\n";

my $sql_heatmap_avg = "
    SELECT
        replace(ntn1.name, ' ', '_') AS name1,
        replace(ntn2.name, ' ', '_') AS name2,
        (IFNULL(n_goc_25,0) * 25 + IFNULL(n_goc_50,0) * 50 + IFNULL(n_goc_75,0) * 75 + IFNULL(n_goc_100,0) * 100)/(IFNULL(n_goc_0,0) + IFNULL(n_goc_25,0) + IFNULL(n_goc_50,0) + IFNULL(n_goc_75,0) + IFNULL(n_goc_100,0)) AS goc_avg
    FROM
        method_link_species_set_attr mlssa inner JOIN   method_link_species_set
        mlss using (method_link_species_set_id) inner JOIN   species_set ss1 on
        mlss.species_set_id = ss1.species_set_id inner JOIN   species_set ss2 on
        mlss.species_set_id = ss2.species_set_id inner JOIN   genome_db gdb1 on
        ss1.genome_db_id = gdb1.genome_db_id inner JOIN   genome_db gdb2 on
        ss2.genome_db_id = gdb2.genome_db_id inner JOIN   ncbi_taxa_name ntn1 on
        gdb1.taxon_id = ntn1.taxon_id inner JOIN   ncbi_taxa_name ntn2 on
        gdb2.taxon_id = ntn2.taxon_id where   mlss.method_link_id = 201 AND
        ntn1.name <> ntn2.name AND   ntn1.name_class = 'scientific name' AND
        ntn2.name_class = 'scientific name' GROUP by ntn1.name, ntn2.name;
";

my $sth_heatmap_avg = $dbh->prepare($sql_heatmap_avg);
$sth_heatmap_avg->execute();
while ( my @row = $sth_heatmap_avg->fetchrow_array() ) {
    print $fh_heatmap_avg join("\t", @row) . "\n";
}

my $sql_heatmap_median = "
    SELECT
        replace(ntn1.name, ' ', '_') AS name1,
        replace(ntn2.name, ' ', '_') AS name2,
        IFNULL(n_goc_0,0) / (IFNULL(n_goc_0,0) + IFNULL(n_goc_25,0) + IFNULL(n_goc_50,0) + IFNULL(n_goc_75,0) + IFNULL(n_goc_100,0)) AS goc_eq_0,
        (IFNULL(n_goc_0,0) + IFNULL(n_goc_25,0)) / (IFNULL(n_goc_0,0) + IFNULL(n_goc_25,0) + IFNULL(n_goc_50,0) + IFNULL(n_goc_75,0) + IFNULL(n_goc_100,0)) AS goc_lte_25,
        (IFNULL(n_goc_0,0) + IFNULL(n_goc_25,0) + IFNULL(n_goc_50,0)) / (IFNULL(n_goc_0,0) + IFNULL(n_goc_25,0) + IFNULL(n_goc_50,0) + IFNULL(n_goc_75,0) + IFNULL(n_goc_100,0)) AS goc_lte_50,
        (IFNULL(n_goc_0,0) + IFNULL(n_goc_25,0) + IFNULL(n_goc_50,0) + IFNULL(n_goc_75,0)) / (IFNULL(n_goc_0,0) + IFNULL(n_goc_25,0) + IFNULL(n_goc_50,0) + IFNULL(n_goc_75,0) + IFNULL(n_goc_100,0)) AS goc_lte_75
    FROM
        method_link_species_set_attr mlssa inner JOIN   method_link_species_set
        mlss using (method_link_species_set_id) inner JOIN   species_set ss1 on
        mlss.species_set_id = ss1.species_set_id inner JOIN   species_set ss2 on
        mlss.species_set_id = ss2.species_set_id inner JOIN   genome_db gdb1 on
        ss1.genome_db_id = gdb1.genome_db_id inner JOIN   genome_db gdb2 on
        ss2.genome_db_id = gdb2.genome_db_id inner JOIN   ncbi_taxa_name ntn1 on
        gdb1.taxon_id = ntn1.taxon_id inner JOIN   ncbi_taxa_name ntn2 on
        gdb2.taxon_id = ntn2.taxon_id where   mlss.method_link_id = 201 AND
        ntn1.name <> ntn2.name AND   ntn1.name_class = 'scientific name' AND
        ntn2.name_class = 'scientific name' GROUP by ntn1.name, ntn2.name;
";

my $sth_heatmap_median = $dbh->prepare($sql_heatmap_median);
$sth_heatmap_median->execute();
while ( my @row = $sth_heatmap_median->fetchrow_array() ) {
	if ( $row[2] >= 0.5 ) {
		print $fh_heatmap_median "$row[0]\t$row[1]\t0\n";
	}
	elsif ( $row[3] >= 0.5 ) {
		print $fh_heatmap_median "$row[0]\t$row[1]\t25\n";
	}
	elsif ( $row[4] >= 0.5 ) {
		print $fh_heatmap_median "$row[0]\t$row[1]\t50\n";
	}	
	elsif ( $row[5] >= 0.5 ) {
		print $fh_heatmap_median "$row[0]\t$row[1]\t75\n";
	}
	else {
		print $fh_heatmap_median "$row[0]\t$row[1]\t100\n";	
	}	
}

close($fh_heatmap_avg);
close($fh_heatmap_median);

#---------------------------------------------------------------------------------------------------
#           Stats for the whole dataset
#---------------------------------------------------------------------------------------------------

open( my $fh_dataset_stats, '>', "$out_dir/dataset_stats.txt" ) || die "Could not open output file at $out_dir";

print $fh_dataset_stats "Average GOC score: ";

my $sql_goc_avg = "
 SELECT AVG(goc_avg) FROM  ( 
    SELECT
        replace(ntn1.name, ' ', '_') AS name1,
        replace(ntn2.name, ' ', '_') AS name2,
        (IFNULL(n_goc_25,0) * 25 + IFNULL(n_goc_50,0) * 50 + IFNULL(n_goc_75,0) * 75 + IFNULL(n_goc_100,0) * 100)/(IFNULL(n_goc_0,0) + IFNULL(n_goc_25,0) + IFNULL(n_goc_50,0) + IFNULL(n_goc_75,0) + IFNULL(n_goc_100,0)) AS goc_avg
    FROM
        method_link_species_set_attr mlssa inner JOIN   method_link_species_set
        mlss using (method_link_species_set_id) inner JOIN   species_set ss1 on
        mlss.species_set_id = ss1.species_set_id inner JOIN   species_set ss2 on
        mlss.species_set_id = ss2.species_set_id inner JOIN   genome_db gdb1 on
        ss1.genome_db_id = gdb1.genome_db_id inner JOIN   genome_db gdb2 on
        ss2.genome_db_id = gdb2.genome_db_id inner JOIN   ncbi_taxa_name ntn1 on
        gdb1.taxon_id = ntn1.taxon_id inner JOIN   ncbi_taxa_name ntn2 on
        gdb2.taxon_id = ntn2.taxon_id where   mlss.method_link_id = 201 AND
        ntn1.name <> ntn2.name AND   ntn1.name_class = 'scientific name' AND
        ntn2.name_class = 'scientific name' GROUP by ntn1.name, ntn2.name
        ) AS t;
";

my $sth_goc_avg = $dbh->prepare($sql_goc_avg);
$sth_goc_avg->execute();
my @row = $sth_goc_avg->fetchrow_array();
print $fh_dataset_stats join("\t", @row) . "\n";

print $fh_dataset_stats "Median GOC score: ";

my $sql_goc_median = "
      SELECT
        SUM(IFNULL(n_goc_0,0))/(SUM(IFNULL(n_goc_0,0)) + SUM(IFNULL(n_goc_25,0)) + SUM(IFNULL(n_goc_50,0)) + SUM(IFNULL(n_goc_75,0)) + SUM(IFNULL(n_goc_100,0))) AS goc_eq_0,
        (SUM(IFNULL(n_goc_0,0)) + SUM(IFNULL(n_goc_25,0)))/(SUM(IFNULL(n_goc_0,0)) + SUM(IFNULL(n_goc_25,0)) + SUM(IFNULL(n_goc_50,0)) + SUM(IFNULL(n_goc_75,0)) + SUM(IFNULL(n_goc_100,0))) AS goc_lte_25,
        (SUM(IFNULL(n_goc_0,0)) + SUM(IFNULL(n_goc_25,0)) + SUM(IFNULL(n_goc_50,0)))/(SUM(IFNULL(n_goc_0,0)) + SUM(IFNULL(n_goc_25,0)) + SUM(IFNULL(n_goc_50,0)) + SUM(IFNULL(n_goc_75,0)) + SUM(IFNULL(n_goc_100,0))) AS goc_lte_50,
        (SUM(IFNULL(n_goc_0,0)) + SUM(IFNULL(n_goc_25,0)) + SUM(IFNULL(n_goc_50,0)) + SUM(IFNULL(n_goc_75,0)))/(SUM(IFNULL(n_goc_0,0)) + SUM(IFNULL(n_goc_25,0)) + SUM(IFNULL(n_goc_50,0)) + SUM(IFNULL(n_goc_75,0)) + SUM(IFNULL(n_goc_100,0))) AS goc_lte_75
    FROM
        method_link_species_set_attr mlssa inner JOIN   method_link_species_set
        mlss using (method_link_species_set_id) inner JOIN   species_set ss1 on
        mlss.species_set_id = ss1.species_set_id inner JOIN   species_set ss2 on
        mlss.species_set_id = ss2.species_set_id inner JOIN   genome_db gdb1 on
        ss1.genome_db_id = gdb1.genome_db_id inner JOIN   genome_db gdb2 on
        ss2.genome_db_id = gdb2.genome_db_id inner JOIN   ncbi_taxa_name ntn1 on
        gdb1.taxon_id = ntn1.taxon_id inner JOIN   ncbi_taxa_name ntn2 on
        gdb2.taxon_id = ntn2.taxon_id where   mlss.method_link_id = 201 AND
        ntn1.name <> ntn2.name AND   ntn1.name_class = 'scientific name' AND
        ntn2.name_class = 'scientific name';
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
my $sql_homology = "SELECT genome_db.name, description, COUNT(*) FROM homology JOIN method_link_species_set USING (method_link_species_set_id) JOIN species_set USING (species_set_id) JOIN genome_db USING (genome_db_id) GROUP BY genome_db_id, description";

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
my $sql_gene_count = "SELECT node_name, nb_genes, nb_long_genes, nb_short_genes, nb_orphan_genes, nb_genes_in_tree, nb_genes_in_tree_single_species, nb_dup_nodes, nb_gene_splits FROM species_tree_node_attr JOIN species_tree_node USING (node_id) WHERE node_id IN (SELECT node_id FROM species_tree_node where genome_db_id IS NOT NULL GROUP BY genome_db_id) ORDER BY node_name";

open( my $fh_gene_count, '>', "$out_dir/gene_count.data" ) || die "Could not open output file at $out_dir";
print $fh_gene_count "species\tnb_genes\tnb_long_genes\tnb_short_genes\tnb_orphan_genes\tnb_genes_in_tree\tnb_genes_in_tree_single_species\tnb_dup_nodes\tnb_gene_splits\n";

my $sth_gene_count = $dbh->prepare($sql_gene_count);
$sth_gene_count->execute();
while ( my @row = $sth_gene_count->fetchrow_array() ) {
    print $fh_gene_count join("\t", @row) . "\n";
}
close($fh_gene_count);


sub num { $a <=> $b }

