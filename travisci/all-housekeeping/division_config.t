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


use File::Basename;
use File::Spec;
use JSON qw(decode_json);
use Test::Exception;
use Test::More;
use XML::LibXML;

use Bio::EnsEMBL::Utils::IO qw(slurp);
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Compara::Utils::Test;

my $xml_parser = XML::LibXML->new(line_numbers => 1);
my %mlss_xml_genome_paths = (
    'genome'             => ['name'],
    'ref_for_taxon'      => ['name'],
    'pairwise_alignment' => ['ref_genome', 'target_genome'],
    'one_vs_all'         => ['ref_genome'],
    'all_vs_one'         => ['target_genome'],
);


sub test_division {
    my ($division, $division_dir) = @_;

    # Track if we have anything to test for this division
    my $has_files_to_test;

    # Load allowed_species.json if it exists
    my %allowed_species;
    my $allowed_species_file = File::Spec->catfile($division_dir, 'allowed_species.json');
    if (-e $allowed_species_file) {
        my $names = decode_json(slurp($allowed_species_file));
        %allowed_species = map {$_ => 1} @$names;
        foreach my $name (@$names) {
            unlike($name, qr/\s/, "'$name' does not contain a space");
        }
    }

    # Load the species-tree if there is one
    my %species_in_tree;
    my $species_tree_file;
    foreach my $tree_type (qw(topology branch_len)) {
        $species_tree_file = File::Spec->catfile($division_dir, "species_tree.$tree_type.nw");
        if ($species_tree_file && -e $species_tree_file) {
            my $content = slurp($species_tree_file);
            my $tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($content);
            %species_in_tree = map {$_->name => 1} grep {$_->name} @{$tree->get_all_leaves};
            last;
        }
    }

    if (%allowed_species && %species_in_tree) {
        # 1. All species in allowed_species.json must be in the species-trees
        $has_files_to_test = 1;
        subtest "$allowed_species_file vs $species_tree_file" => sub {
            foreach my $name (keys %allowed_species) {
                ok(exists $species_in_tree{$name}, "'$name' is in the species tree");
            }
        };
    }

    # Load the MLSS XML file if it exists
    my $mlss_file = File::Spec->catfile($division_dir, 'mlss_conf.xml');
    if (-e $mlss_file) {
        my $xml_document = $xml_parser->parse_file($mlss_file);
        my $root_node    = $xml_document->documentElement();
        my @names_to_test;
        while (my ($node_name, $attr_names) = each %mlss_xml_genome_paths) {
            foreach my $genome_node (@{$root_node->findnodes("//$node_name")}) {
                foreach my $attr_name (@$attr_names) {
                    my $name = $genome_node->getAttribute($attr_name);
                    push @names_to_test, [$name, "<$node_name $attr_name='$name'>"];
                }
            }
        }

        if ($division ne 'citest' && %species_in_tree) {
            # 2. All species listed in mlss_conf.xml exist in the species-trees
            $has_files_to_test = 1;
            subtest "$mlss_file vs $species_tree_file" => sub {
                foreach my $a (@names_to_test) {
                    my ($name, $node) = @$a;
                    ok(exists $species_in_tree{$name}, "$node is in the species tree");
                }
            };
        }
        if (%allowed_species) {
            # 3. All species listed in mlss_conf.xml exist in allowed_species.json
            $has_files_to_test = 1;
            subtest "$mlss_file vs $allowed_species_file" => sub {
                foreach my $a (@names_to_test) {
                    my ($name, $node) = @$a;
                    ok(exists $allowed_species{$name}, "$node is allowed");
                }
            };
        }
    }

    # Nothing to test but it's alright. Not all divisions have files to cross-check
    plan skip_all => 'No files to test' unless $has_files_to_test;
}

my $compara_root = Bio::EnsEMBL::Compara::Utils::Test::get_repository_root();
my $config_dir = File::Spec->catfile($compara_root, 'conf');

opendir(my $dirh, $config_dir);
foreach my $division (File::Spec->no_upwards(readdir $dirh)) {
    my $division_dir = File::Spec->catfile($config_dir, $division);
    if (-d $division_dir) {
        subtest $division => sub {
            test_division($division, $division_dir);
        };
    }
}
close($dirh);

done_testing();
