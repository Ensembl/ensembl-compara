#!/usr/bin/env perl
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

=head1 NAME

remove_reference_genome.pl

=head1 DESCRIPTION

This script's purpose is to remove reference genomes from a database.
This includes removal of all associated data (dnafrags, members, etc)

=head1 SYNOPSIS

  perl remove_reference_genome.pl --help

  perl remove_reference_genome.pl
    [--reg_conf <registry_configuration_file>]
    --compara <compara_url_or_alias>
    --genome_db_id <id1>
    [--genome_db_id <id2> ... --genome_db_id <idN>]

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

Prints help message and exits.

=back

=head2 GENERAL CONFIGURATION

=over

=item B<[--reg_conf registry_configuration_file]>

The optional Bio::EnsEMBL::Registry configuration file. If none given,
the one set in ENSEMBL_REGISTRY will be used if defined, if not
~/.ensembl_init will be used.

=back

=head2 DATABASES

=over

=item B<--compara compara_db_name_or_alias>

The compara database to update. You can use either a URL or any of the
aliases given in the registry_configuration_file

=item B<--genome_db_id ID>

The genome_db_id of the reference to remove. Can give multiples, e.g.
--genome_db_id 1 --genome_db_id 2 ... --genome_db_id N

=back

=cut

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Utils::Exception qw(throw warning verbose);
use Bio::EnsEMBL::Utils::IO qw/:slurp/;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;
use Bio::EnsEMBL::Compara::Utils::ReferenceDatabase;

use Getopt::Long;

my $help;
my ($reg_conf, $compara, @genome_db_ids);

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "compara=s" => \$compara,
    "genome_db_id=i@" => \@genome_db_ids,
);

$| = 0;

# Print Help and exit if help is requested
if ($help or !scalar(@genome_db_ids) or !$compara) {
    use Pod::Usage;
    pod2usage({-exitvalue => 0, -verbose => 2});
}

##
## Configure the Bio::EnsEMBL::Registry
## Uses $reg_conf if supplied. Uses ENV{ENSMEBL_REGISTRY} instead if defined. Uses
## ~/.ensembl_init if all the previous fail.
##
Bio::EnsEMBL::Registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing") if $reg_conf;

my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($compara);
throw ("Cannot connect to database [$compara]") if (!$compara_dba);
my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();

foreach my $gdb_id ( @genome_db_ids ) {
    my $this_gdb = $genome_db_adaptor->fetch_by_dbID($gdb_id);
    die "Cannot find genome_db_id $gdb_id in database" unless $this_gdb;
    Bio::EnsEMBL::Compara::Utils::ReferenceDatabase::remove_reference_genome($compara_dba, $this_gdb);
}

exit(0);
