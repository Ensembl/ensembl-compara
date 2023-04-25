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

=head1 NAME

get_core_genebuild_id.pl

=head1 DESCRIPTION

Retrieves the Genebuild ID from the core database of the given species.

=head1 EXAMPLE

    perl $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/pipeline/get_core_genebuild_id.pl \
        --reg_conf $ENSEMBL_ROOT_DIR/ensembl-compara/conf/references/production_reg_conf.pl \
        --species gallus_gallus

=head1 OPTIONS

=over

=item B<[--help]>

Prints help message and exits.

=item B<[--reg_conf file_path]>

Registry file path.

=item B<[--species genome_name]>

Production name of the genome whose Genebuild ID is to be retrieved.

=back

=cut


use strict;
use warnings;

use Getopt::Long;
use JSON qw(encode_json);
use Pod::Usage;

use Bio::EnsEMBL::Registry;


my ($help, $reg_conf, $species);
GetOptions(
    'help'       => \$help,
    'reg_conf=s' => \$reg_conf,
    'species=s'  => \$species,
) or pod2usage(-verbose => 2);

# Handle "print usage" scenarios
pod2usage(-exitvalue => 0, -verbose => 1) if $help;
pod2usage(-verbose => 1) if !$reg_conf or !$species;


my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_all($reg_conf, 0, 0, 0, 'throw_if_missing');

my $meta_container = $registry->get_adaptor($species, 'Core', 'MetaContainer');

my $genebuild_id = $meta_container->single_value_by_key('genebuild.id');

if (defined $genebuild_id) {
    $genebuild_id += 0  # hack so that genebuild_id is output as an integer
} else {
    $genebuild_id = JSON::null;
}

my $result = {
    'genebuild_id' => $genebuild_id,
};

print STDOUT encode_json($result) . "\n";
