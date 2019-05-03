#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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
use Cwd qw(abs_path);
use File::Spec::Functions qw(catfile);
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

$| = 1;

# Parameters:
my $help = 0;
# URL to the Compara database
my $compara_url;
# Output directory where the taxonomy table will be saved
my $out_dir = Cwd::abs_path();
# Handle input arguments
GetOptions("help"          => \$help,
           "compara_url=s" => \$compara_url,
           "outdir=s"      => \$out_dir
          ) or die("Error in command line arguments\n");
die "Error in command line arguments -compara_url " .
    "mysql://user:pass\@host:port/db_name [-outdir /your/directory/]"
    if (!$compara_url);

# Create new Compara database adaptor and get the GenomeDB adaptor
my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -url => $compara_url, -species => 'Multi');
my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();
# Get all the Genome DBs
my $list_ref_of_gdbs = $genome_db_adaptor->fetch_all();
# Declare the taxonomic ranks of interest (sorted)
my @target_ranks = qw(class superorder order suborder family subfamily species);
# Create the taxonomy template: if a rank is missing, assign "N/A"
my %rank_template = map {$_ => "N/A"} @target_ranks;
# Default output file name
my $out_file = "taxonomy_table.tsv";
# Recursive function to flatten the taxonomy hash into an array with one string
# per species' taxonomy (ranks separated by "\t"), and each rank sorted in
# alphabetical order
sub flatten {
    my ($in_hash, $out_array, $already_flatted) = @_;
    # The first call will have only two arguments
    $already_flatted = "" unless(defined $already_flatted);
    for my $key (sort keys %$in_hash) {
        my $value = $in_hash->{$key};
        if (ref $value eq 'HASH') {
            flatten($value, $out_array, $already_flatted . $key . "\t");
        } else {
            push(@{$out_array}, $already_flatted . $key);
        }
    }
}
# Store all the taxonomic information in a mutidimensional hash, following the
# same order as in @target_ranks
my $taxonomy_db = {};
foreach my $ref (@{$list_ref_of_gdbs}) {
    my $node;
    # There are some $ref that may not have 'taxon_id', so we need to handle the
    # exception, report the troubling $ref and move to the next one
    eval {
        $node = $ref->taxon();
    } or do {
        warn "Undefined taxon_id for '", $ref->name(), "'.\n";
        next;
    };
    # Copy taxonomy template and fill it in
    my %taxonomy = %rank_template;
    while ($node->name() ne 'root') {
        my $rank = $node->rank();
        if (defined $rank && exists $taxonomy{$rank}) {
            $taxonomy{$rank} = $node->name();
        }
        $node = $node->parent();
    }
    # Replace species name by GenomeDB name
    if (grep(/^species$/, @target_ranks)) {
        $taxonomy{'species'} = $ref->name();
    }
    # Push the template into the taxonomy hash
    my $level = $taxonomy_db;
    foreach my $rank (@target_ranks) {
        my $classification = $taxonomy{$rank};
        if (! exists($level->{$classification})) {
            # Each rank has a hash as value except "species" (this has a 1)
            $level->{$classification} = ($rank eq $target_ranks[-1]) ? 1 : {};
        }
        $level = $level->{$classification};
    }
}
# Flatten the taxonomy hash into an array of one element per species
my @taxonomy_table;
flatten($taxonomy_db, \@taxonomy_table);
# Write the array into the output file with @target_ranks as headers
my $out_abs_path = catfile($out_dir, $out_file);
open(my $file, ">$out_abs_path") or
    die "Couldn't create file '$out_abs_path', $!";
print $file join("\t", map(ucfirst, @target_ranks)), "\n";
print $file join("\n", @taxonomy_table), "\n";
close($file);
