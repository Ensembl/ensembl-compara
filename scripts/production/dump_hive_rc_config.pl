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

dump_hive_rc_config.pl

=head1 DESCRIPTION

Dumps the current Compara Hive resource-class configuration to a JSON file.

=head1 EXAMPLE

    perl $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/production/dump_hive_rc_config.pl \
        --outfile compara_hive_rc_config.json

=head1 OPTIONS

=over

=item B<[--help]>

Prints help message and exits.

=item B<[--outfile file_path]>

Path of output JSON file.

=back

=cut


use strict;
use warnings;

use Getopt::Long;
use JSON;
use Pod::Usage;

use Bio::EnsEMBL::Compara::PipeConfig::ENV;
use Bio::EnsEMBL::Utils::Exception qw(throw);


my ( $help, $outfile, $genome_db_id, $mlss_id );
GetOptions(
    "help|?"    => \$help,
    "outfile=s" => \$outfile,
) or pod2usage(-verbose => 2);

pod2usage(-exitvalue => 0, -verbose => 1) if $help;
pod2usage(-verbose => 1) if !$outfile;


my $hive_rc_config;

$hive_rc_config->{'resource_classes_single_thread'} = Bio::EnsEMBL::Compara::PipeConfig::ENV::resource_classes_single_thread();
$hive_rc_config->{'resource_classes_multi_thread'} = Bio::EnsEMBL::Compara::PipeConfig::ENV::resource_classes_multi_thread();

open(my $fh, '>', $outfile) or throw("Could not open file [$outfile]");
print $fh JSON->new->pretty->encode($hive_rc_config) . "\n";
close($fh) or throw("Could not close file [$outfile]");
