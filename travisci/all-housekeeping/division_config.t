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
    my ($division, $division_dir, $allowed_species_info) = @_;

    # Track if we have anything to test for this division
    my $has_files_to_test;

    # Fetch allowed-species info if allowed_species.json exists for this division
    my %allowed_species;
    my $allowed_species_file;
    if (exists $allowed_species_info->{$division}) {
        $allowed_species_file = $allowed_species_info->{$division}{'allowed_species_file'};
        %allowed_species = %{$allowed_species_info->{$division}{'allowed_species'}};
    }

    # Validate production names using regexes based on the MetaKeyFormat datacheck.
    # The regex used in non-Microbes divisions additionally requires that there are at most two interstitial underscores.
    # See https://github.com/Ensembl/ensembl-datacheck/blob/6b3d185/lib/Bio/EnsEMBL/DataCheck/Checks/MetaKeyFormat.pm#L59
    my $prod_name_re = $division =~ /^(fungi|protists)$/
                     ? qr/^_?[a-z0-9]+_[a-z0-9_]+$/
                     : qr/^_?[a-z0-9]+_[a-z0-9]+(?:_[a-z0-9]+)?$/
                     ;

    foreach my $name (keys %allowed_species) {
        like($name, $prod_name_re, "Production name has conventional format");
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

        if (%allowed_species and scalar(@names_to_test) > 0) {
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

    # Load additional_species.json if it exists
    my $additional_species_file = File::Spec->catfile($division_dir, 'additional_species.json');
    if (-e $additional_species_file) {
        my $additional_species = decode_json(slurp($additional_species_file));
        my @divisions_to_test = grep { exists $allowed_species_info->{$_} } keys %$additional_species;
        if (scalar(@divisions_to_test) > 0) {
            # 4. Each species in additional_species.json must be in relevant division allowed-species list
            $has_files_to_test = 1;
            foreach my $other_div (@divisions_to_test) {
                my $other_div_allowed_species_file = $allowed_species_info->{$other_div}{'allowed_species_file'};
                subtest "$additional_species_file vs $other_div_allowed_species_file" => sub {
                    my %other_div_allowed_species = %{$allowed_species_info->{$other_div}{'allowed_species'}};
                    foreach my $name (@{$additional_species->{$other_div}}) {
                        ok(exists $other_div_allowed_species{$name}, "$name is allowed");
                    }
                };
            }
        }
    }

    # Load biomart_species.json if it exists
    my $biomart_species_file = File::Spec->catfile($division_dir, 'biomart_species.json');
    if (-e $biomart_species_file and %allowed_species) {
        my $metaconfig_file = File::Spec->catfile($division_dir, 'metaconfig.json');
        my $metaconfig = decode_json(slurp($metaconfig_file));
        my $biomart_species_cap = $metaconfig->{'biomart'}{'species_cap'};
        # 5. All species listed in biomart_species.json exist in allowed_species.json
        $has_files_to_test = 1;
        my $biomart_species = decode_json(slurp($biomart_species_file));
        subtest "$biomart_species_file species cap" => sub {
            cmp_ok(scalar(@{$biomart_species}), '<=', $biomart_species_cap, "species count within limit");
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
