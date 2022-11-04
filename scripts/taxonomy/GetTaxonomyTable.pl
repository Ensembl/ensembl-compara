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

use strict;
use warnings;

use Getopt::Long;
use JSON qw(decode_json);

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::IO qw(slurp);

# Parameters:
# URL to the Compara database
my ($compara_url, $species_json);
# Group ranks in taxonomy table?
# E.g.:
#   CLASS     SUPERORDER        ORDER     SUBORDER     FAMILY   SUBFAMILY       SPECIES             GENOMEDB NAME
#   Mammalia  Euarchontoglires  Primates  Haplorrhini  Cebidae  Callitrichinae  Callithrix jacchus  callithrix_jacchus
#   Mammalia  Euarchontoglires  Primates  Haplorrhini  Cebidae  Cebinae         Cebus capucinus     cebus_capucinus
# will be printed like
#   CLASS     SUPERORDER        ORDER     SUBORDER     FAMILY   SUBFAMILY       SPECIES             GENOMEDB NAME
#   Mammalia  Euarchontoglires  Primates  Haplorrhini  Cebidae  Callitrichinae  Callithrix jacchus  callithrix_jacchus
#   ''        ''                ''        ''           ''       Cebinae         Cebus capucinus     cebus_capucinus
my $group_ranks = 0;
# Handle input arguments
GetOptions("compara_url=s"  => \$compara_url,
           "group"          => \$group_ranks,
           "species_json=s" => \$species_json,
          ) or die("Error in command line arguments\n");
die "Error in command line arguments: -compara_url mysql://user:pass\@host:port/db_name"
    if (!$compara_url);

# Create new Compara database adaptor and get the GenomeDB adaptor
my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url => $compara_url);
# Declare the taxonomic ranks of interest (sorted)
my @target_ranks = qw(class superorder order suborder family subfamily species);
# Number of ranks (plus the default addition of "GenomeDB name" as last rank)
my $num_ranks = $#target_ranks + 1;
# Create the taxonomy template: if a rank is missing, assign "N/A"
my $null_value = 'N/A';
my %rank_template = map {$_ => $null_value} @target_ranks;
# Get the taxon node for each species either in the species JSON file or in the genome_db table
my %taxon_hash;
if ($species_json) {
    my $species_list = decode_json(slurp($species_json));
    my $taxon_adaptor = $compara_dba->get_NCBITaxonAdaptor();
    foreach my $species (@$species_list) {
        my $species_name = ($species =~ s/_/ /gr);
        $taxon_hash{$species} = $taxon_adaptor->fetch_node_by_name($species_name);
    }
} else {
    my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();
    # Get all the Genome DBs
    my $list_of_gdbs = $genome_db_adaptor->fetch_all();
    foreach my $gdb (@{$list_of_gdbs}) {
        # There are some $gdb that may not have 'taxon_id', so we need to handle the
        # exception, report the troubling $gdb and move to the next one
        if (!$gdb->taxon_id() || !defined($gdb->taxon())) {
            warn "Undefined taxon_id for '", $gdb->name(), "'.\n";
            next;
        }
        $taxon_hash{$gdb->name()} = $gdb->taxon();
    }
}
# @taxonomy_table will have one string per species' taxonomy in tab-separated
# values (TSV) format
my @taxonomy_table;
foreach my $species (keys %taxon_hash) {
    my $node = $taxon_hash{$species};
    # Copy taxonomy template and fill it in
    my %taxonomy = %rank_template;
    while ($node->name() ne 'root') {
        my $rank = $node->rank();
        if (exists($taxonomy{$rank})) {
            $taxonomy{$rank} = $node->name();
        }
        $node = $node->parent();
    }
    # Get the taxonomy in a TSV-like string, add GenomeDB name as the last
    # level/rank and append it to the taxonomy table
    my $taxonomy_str = join("\t", (map {$taxonomy{$_}} @target_ranks), $species);
    push(@taxonomy_table, $taxonomy_str);
}
# Sort the rows in alphabetical order
@taxonomy_table = sort(@taxonomy_table);
if ($group_ranks) {
    # Group ranks in taxonomy table, replacing duplicates by "''"
    # Get the first row as reference to see how many ranks are the same
    my @prev_taxonomy = split(/\t/, $taxonomy_table[0]);
    foreach my $i (1 .. $#taxonomy_table) {
        my @taxonomy = split(/\t/, $taxonomy_table[$i]);
        # Grouped version of the taxonomy (string)
        my $grouped_taxonomy = "";
        # Flag when two consecutive species have a not-null matching rank
        my $not_null_match_found = 0;
        # Loop over each rank to compare it with the value in the previous row
        foreach my $j (0 .. $num_ranks) {
            if ($prev_taxonomy[$j] eq $taxonomy[$j]) {
                # Get the flag to True if the ranks are not null and equal
                if ($taxonomy[$j] ne $null_value) {
                    $not_null_match_found = 1;
                }
            } else {
                # If there is a not-null match, all the ranks matched can be
                # replaced by "''". If not, it means all the ranks were missing
                # until this point, so leave the null value.
                my @values;
                if ($not_null_match_found) {
                    @values = ("''") x $j;
                } else {
                    @values = ($null_value) x $j;
                }
                # As soon as one rank is different, the remaining will be too
                $grouped_taxonomy .= join("\t", @values, @taxonomy[$j .. $num_ranks]);
                last;
            }
        }
        # Replace the string by its grouped version
        $taxonomy_table[$i] = $grouped_taxonomy;
        # Get the current taxonomy as reference for the next step
        @prev_taxonomy = @taxonomy;
    }
}
# Write the array into STDOUT with @target_ranks as headers
print join("\t", map(ucfirst, @target_ranks), 'Requested name'), "\n",
      join("\n", @taxonomy_table), "\n";

