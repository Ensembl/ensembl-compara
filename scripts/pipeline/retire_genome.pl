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

=head1 NAME

retire_genome.pl

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 DESCRIPTION

This script's main purpose is to retire a genome:
 - It retires all the mlss_ids and species_sets

=head1 SYNOPSIS

  perl retire_genome.pl --help
    [--reg_conf registry_configuration_file]
    --compara compara_db_name_or_alias
    --genome_db_ids_to_retire 1234
    --file_of_genome_db_ids_to_retire path/to/file]

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

Prints help message and exits.

=back

=head2 GENERAL CONFIGURATION

=over

=item B<[--reg_conf registry_configuration_file]>

The Bio::EnsEMBL::Registry configuration file. If none given,
the one set in ENSEMBL_REGISTRY will be used if defined, if not
~/.ensembl_init will be used.

=back

=head2 DATABASES

=over

=item B<--compara compara_db_name_or_alias>

The compara database to update. You can use either the original name or any of the
aliases given in the registry_configuration_file

=item B<genome_db_ids_to_retire genome_db_ids_name>

The genome_db_id of that need to be retired.

=back

=head2 OPTIONS

=over

=item B<[--file_of_genome_db_ids_to_retire path/to/file]>

File that contains a list of genome_db_ids to be retired.
In this mode, --genome_db_ids_to_retire is ignored.

=back

=head1 INTERNAL METHODS

=cut

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Utils::Exception qw(throw warning verbose);
use Bio::EnsEMBL::Utils::IO qw/:slurp/;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;
use Bio::EnsEMBL::Compara::Utils::MasterDatabase;

use Getopt::Long;

my $help;
my $reg_conf;
my $compara;
my $gdb_id_to_retire = "";
my $file;
my $release;
my $collection;

GetOptions( "help"                                 => \$help,
            "reg_conf=s"                           => \$reg_conf,
            "compara=s"                            => \$compara,
            "gdb_id_to_retire=s"                   => \$gdb_id_to_retire,
            'file_of_gdb_ids_to_retire=s'          => \$file,);

$| = 0;

# Print Help and exit if help is requested
if ($help or (!$gdb_id_to_retire and !$file) or !$compara) {
    use Pod::Usage;
    pod2usage({-exitvalue => 0, -verbose => 2});
}

Bio::EnsEMBL::Registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing");

my $compara_dba;
if ($compara =~ /mysql:\/\//) {
    $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$compara);
} else {
    $compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($compara, "compara");
}
throw ("Cannot connect to database [$compara]") if (!$compara_dba);
my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();


# create the list of gdb_ids_to_retire
my @species_list;
if ($gdb_id_to_retire) {
    die "--gdb_id_to_retire and --file_of_gdb_ids_to_retire cannot be given at the same time.\n" if $file;
    push @species_list, $gdb_id_to_retire;
} else {
    my $gdb_ids = slurp_to_array($file, "chomp");
    foreach my $gdbid (@$gdb_ids) {
        #left and right trim for unwanted spaces
        $gdbid =~ s/^\s+|\s+$//g;
        push @species_list, $gdbid;
    }
}

foreach my $this_gdb_id (@species_list) {
    my $gdba = $compara_dba->get_GenomeDBAdaptor;
    my $gdb  = $gdba->fetch_by_dbID($this_gdb_id);
    $gdba->retire_object($gdb);
}

exit(0);
