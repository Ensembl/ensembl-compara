# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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

use Bio::EnsEMBL::Utils::IO qw (slurp);
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

sub is_valid_newick {
    my $filename = shift;

    my $content = slurp($filename);
    my $tree;
    lives_ok(
        sub { $tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($content) },
        "$filename is a valid Newick/NHX file"
    );
    if ($tree && $filename =~ /\bconf\/(.*)\/species_tree\.(topology|branch_len)\.nw$/) {
        # The tree can have more species than needed, but all names used in
        # the following two files must be found in the species tree, except
        # for the citest division
        if ($1 ne 'citest') {
            my %names_in_tree = map {$_->name => 1} grep {$_->name} @{$tree->get_all_leaves};
            do_species_match(dirname($filename), \%names_in_tree);
        }
    }
}

sub do_species_match {
    my $dirname = shift;
    my $names_in_tree = shift;

    my $allowed_species_filename = File::Spec->catfile($dirname, 'allowed_species.json');
    if (-e $allowed_species_filename) {
        subtest $allowed_species_filename => sub {
            my $species_in_file = decode_json(slurp($allowed_species_filename));
            foreach my $name (@$species_in_file) {
                ok(exists $names_in_tree->{$name}, "$name is in the species tree");
            }
        };
    }

    my $xml_file = File::Spec->catfile($dirname, 'mlss_conf.xml');
    if (-e $xml_file) {
        subtest $xml_file => sub {
            my $xml_document = $xml_parser->parse_file($xml_file);
            my $root_node    = $xml_document->documentElement();
            while (my ($node_name, $attr_names) = each %mlss_xml_genome_paths) {
                foreach my $genome_node (@{$root_node->findnodes("//$node_name")}) {
                    foreach my $attr_name (@$attr_names) {
                        my $name = $genome_node->getAttribute($attr_name);
                        ok(exists $names_in_tree->{$name}, "<$node_name $attr_name='$name'> is in the species tree");
                    }
                }
            }
        };
    }
}

my @all_files = Bio::EnsEMBL::Compara::Utils::Test::find_all_files();

foreach my $f (@all_files) {
    if ($f =~ /\.(nh|nhx|nw|nwk)$/) {
        is_valid_newick($f);
    }
}

done_testing();

