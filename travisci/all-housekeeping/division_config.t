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
    'multiple_alignment' => ['ref_genome'],
    'nc_trees'           => ['prefer_for_genomes'],
    'protein_trees'      => ['prefer_for_genomes'],
);


sub test_division {
    my ($division, $division_dir, $allowed_species_info) = @_;

    # Track if we have anything to test for this division
    my $has_files_to_test;

    # Fetch allowed-species info if allowed_species.json exists for this division
    my %allowed_species;
    my $allowed_species_file;
    my @all_species_files;
    my %all_species;
    if (exists $allowed_species_info->{$division}) {
        $allowed_species_file = $allowed_species_info->{$division}{'allowed_species_file'};
        %allowed_species = %{$allowed_species_info->{$division}{'allowed_species'}};
        push(@all_species_files, $allowed_species_file);
        %all_species = %allowed_species;
    }

    # Validate production names using regexes based on the MetaKeyFormat datacheck.
    # The regex used in non-Microbes divisions additionally requires that there are at most two interstitial underscores.
    # See https://github.com/Ensembl/ensembl-datacheck/blob/6b3d185/lib/Bio/EnsEMBL/DataCheck/Checks/MetaKeyFormat.pm#L59
    my $prod_name_re = $division =~ /^(fungi|protists)$/
                     ? qr/^_?[a-z0-9]+_[a-z0-9_]+$/
                     : qr/^_?[a-z0-9]+_[a-z0-9]+(?:_[a-z0-9]+)?$/
                     ;

    foreach my $name (keys %allowed_species) {
        like($name, $prod_name_re, "Production name '$name' has conventional format");
    }

    # Load the MLSS XML file if it exists
    my $mlss_file = File::Spec->catfile($division_dir, 'mlss_conf.xml');
    if (-e $mlss_file) {
        my $xml_document = $xml_parser->parse_file($mlss_file);
        my $root_node    = $xml_document->documentElement();
        my @nodes_to_test;
        while (my ($node_name, $attr_names) = each %mlss_xml_genome_paths) {
            foreach my $genome_node (@{$root_node->findnodes("//$node_name")}) {
                foreach my $attr_name (@$attr_names) {
                    next unless $genome_node->hasAttribute($attr_name);
                    my $attr_value = $genome_node->getAttribute($attr_name);
                    my @names = split(/ /, $attr_value);
                    push @nodes_to_test, [\@names, qq/<$node_name $attr_name="$attr_value">/];
                }
            }
        }

        if (%allowed_species and scalar(@nodes_to_test) > 0) {
            # All species listed in mlss_conf.xml exist in allowed_species.json
            $has_files_to_test = 1;
            subtest "$mlss_file vs $allowed_species_file" => sub {
                foreach my $test_case (@nodes_to_test) {
                    my ($names, $node) = @$test_case;
                    foreach my $name (@$names) {
                        ok(exists $allowed_species{$name}, "$name in MLSS conf node '$node' is allowed");
                    }
                }
            };
        }
    }

    # Load additional_species.json if it exists
    my $additional_species_file = File::Spec->catfile($division_dir, 'additional_species.json');
    if (-e $additional_species_file) {
        my $additional_species = decode_json(slurp($additional_species_file));
        my @divisions_to_test = grep { exists $allowed_species_info->{$_} } keys %$additional_species;
        if (scalar(@divisions_to_test) > 0) {
            # Each species in additional_species.json must be in relevant division allowed-species list
            $has_files_to_test = 1;
            push(@all_species_files, $additional_species_file);
            foreach my $other_div (@divisions_to_test) {
                my $other_div_allowed_species_file = $allowed_species_info->{$other_div}{'allowed_species_file'};
                subtest "$additional_species_file vs $other_div_allowed_species_file" => sub {
                    my %other_div_allowed_species = %{$allowed_species_info->{$other_div}{'allowed_species'}};
                    foreach my $name (@{$additional_species->{$other_div}}) {
                        ok(exists $other_div_allowed_species{$name}, "$name is allowed");
                        $all_species{$name} = 1;
                    }
                };
            }
        }
    }

    # Load the species topology if there is one
    my %species_in_topology;
    my %genome_weights;
    my $species_topology_file = File::Spec->catfile($division_dir, 'species_tree.topology.nw');
    if (%allowed_species && -e $species_topology_file) {
        my $content = slurp($species_topology_file);
        my $topology = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($content);
        %species_in_topology = map {$_->name => 1} grep {$_->name} @{$topology->get_all_leaves};
        # All species in allowed_species.json and additional_species.json must be in the species topology
        $has_files_to_test = 1;
        my $all_species_file_str = join(':', @all_species_files);
        subtest "$all_species_file_str vs $species_topology_file" => sub {
            foreach my $name (keys %all_species) {
                ok(exists $species_in_topology{$name}, "'$name' is in the species topology");
            }
        };

        # Check for polyploid subgenomes. These may be used later to
        # calculate the effective genome count of polyploid genomes.
        my $all_species_subpattern = join('|', keys %all_species);
        my $subgenome_name_re = qr/^(?<principal>${all_species_subpattern})_(?<component>[^_]+)$/;
        foreach my $name (keys %species_in_topology) {
            if (!exists $all_species{$name} && $name =~ $subgenome_name_re) {
                if ($+{'component'} ne 'U') {
                    $genome_weights{$+{'principal'}} += 1;
                }
            }
        }
    }

    # Load biomart_species.json if it exists
    my $biomart_species_file = File::Spec->catfile($division_dir, 'biomart_species.json');
    if (-e $biomart_species_file and %allowed_species) {
        my $metaconfig_file = File::Spec->catfile($division_dir, 'metaconfig.json');
        my $metaconfig = decode_json(slurp($metaconfig_file));
        my $biomart_species_cap = $metaconfig->{'biomart'}{'species_cap'};
        # All species listed in biomart_species.json exist in allowed_species.json
        $has_files_to_test = 1;
        my $biomart_species = decode_json(slurp($biomart_species_file));

        my $effective_genome_count = 0;
        foreach my $name (@{$biomart_species}) {
            my $genome_weight = exists $genome_weights{$name} ? $genome_weights{$name} : 1;
            $effective_genome_count += $genome_weight;
        }

        subtest "$biomart_species_file species cap" => sub {
            cmp_ok($effective_genome_count, '<=', $biomart_species_cap, "biomart species count within limit");
        };

        subtest "$biomart_species_file vs $allowed_species_file" => sub {
            foreach my $name (@{$biomart_species}) {
                ok(exists $allowed_species{$name}, "$name is allowed");
            }
        };
    }

    # Nothing to test but it's alright. Not all divisions have files to cross-check
    plan skip_all => 'No files to test' unless $has_files_to_test;
}

my $compara_root = Bio::EnsEMBL::Compara::Utils::Test::get_repository_root();
my $config_dir = File::Spec->catfile($compara_root, 'conf');

my %div_to_div_dir;
my $allowed_species_info;
opendir(my $dirh, $config_dir);
foreach my $division (File::Spec->no_upwards(readdir $dirh)) {
    my $division_dir = File::Spec->catfile($config_dir, $division);
    if (-d $division_dir) {
        $div_to_div_dir{$division} = $division_dir;
        my $allowed_species_file = File::Spec->catfile($division_dir, 'allowed_species.json');
        if (-e $allowed_species_file) {
            my $names = decode_json(slurp($allowed_species_file));
            my %allowed_species = map {$_ => 1} @$names;
            $allowed_species_info->{$division} = {
                'allowed_species_file' => $allowed_species_file,
                'allowed_species' => \%allowed_species
            };
        }
    }
}
close($dirh);

while (my ($division, $division_dir) = each %div_to_div_dir) {
    subtest $division => sub {
        test_division($division, $division_dir, $allowed_species_info);
    };
}

done_testing();
