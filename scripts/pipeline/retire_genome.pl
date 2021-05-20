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
    --mode genome_db|mlss_id
    --gdb_id_to_change 1234
    --mlss_id_to_change 1234
    --file_of_ids_to_change path/to/file]

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

=back

=head2 OPTIONS

=over

=item B<[--file_of_ids_to_change path/to/file]>

File that contains a list of genome_db_ids to be retired.
In this mode, --genome_db_ids_to_retire is ignored.

=item B<[--mode delete or retire]>

This scripts run in two modes: retire or delete ids

=item B<[--id_type genome_db or mlss_id]>

This scripts deals with two types of ids: genome_db_id or mlss_ids

=item B<gdb_id_to_change genome_db_id>

The genome_db_id of that need to be retired.

=item B<mlss_id_to_change mlss_id>

The genome_db_id of that need to be retired.

=back

=head1 INTERNAL METHODS

=cut

#Delete a mlss_id:
#perl $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/pipeline/retire_genome.pl --reg_conf $ENSEMBL_ROOT_DIR/ensembl-compara/conf/${COMPARA_DIV}/production_reg_conf.pl --compara compara_curr --mlss_id_to_change 1234 --mode delete --id_type mlss_id

#Retire a mlss_id:
#perl $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/pipeline/retire_genome.pl --reg_conf $ENSEMBL_ROOT_DIR/ensembl-compara/conf/${COMPARA_DIV}/production_reg_conf.pl --compara compara_curr --mlss_id_to_change 1234 --mode retire --id_type mlss_id

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
my $mode;
my $id_type;
my $gdb_id_to_change = "";
my $mlss_id_to_change = "";
my $file;
my $release;
my $collection;

GetOptions( "help"                                 => \$help,
            "reg_conf=s"                           => \$reg_conf,
            "compara=s"                            => \$compara,
            "mode=s"                               => \$mode,
            "id_type=s"                            => \$id_type,
            "gdb_id_to_change=s"                   => \$gdb_id_to_change,
            "mlss_id_to_change=s"                  => \$mlss_id_to_change,
            'file_of_ids_to_change=s'              => \$file,);

$| = 0;

# Print Help and exit if help is requested
if ($help or ((!$gdb_id_to_change and !$file) and (!$mlss_id_to_change and !$file)) or !$compara or ($mode !~ m/(\bretire\b|\bdelete\b)/) or ($id_type !~ m/(\bmlss_id\b|\bgenome_db\b)/) ) {
    use Pod::Usage;
    pod2usage({-exitvalue => 0, -verbose => 2});
}

Bio::EnsEMBL::Registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing") if $reg_conf;

my $compara_dba;
if ($compara =~ /mysql:\/\//) {
    $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$compara);
} else {
    $compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($compara, "compara");
}
throw ("Cannot connect to database [$compara]") if (!$compara_dba);
my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();

if ($id_type eq "genome_db") {
    # create the list of gdb_ids_to_retire
    my @species_list;
    if ($gdb_id_to_change) {
        die "--gdb_id_to_change and --file_of_ids_to_change cannot be given at the same time.\n" if $file;
        push @species_list, $gdb_id_to_change;
    }
    else {
        my $gdb_ids = slurp_to_array( $file, "chomp" );
        foreach my $gdbid (@$gdb_ids) {
            #left and right trim for unwanted spaces
            $gdbid =~ s/^\s+|\s+$//g;
            push @species_list, $gdbid;
        }
    }

    foreach my $this_gdb_id (@species_list) {
        my $gdba = $compara_dba->get_GenomeDBAdaptor;
        my $gdb  = $gdba->fetch_by_dbID($this_gdb_id);
        if ($mode eq "retire"){
            $gdba->retire_object($gdb);
        }
        elsif ($mode eq "delete"){
            $gdba->delete_by_dbID($gdb);
        }
    }
}
elsif ($id_type = "mlss_id") {
    # create the list of mlss_ids_to_retire
    my @mlss_ids_list;
    if ($mlss_id_to_change) {
        die "--mlss_id_to_change and --file_of_ids_to_change cannot be given at the same time.\n" if $file;
        push @mlss_ids_list, $mlss_id_to_change;
    }
    else {
        my $mlss_ids = slurp_to_array( $file, "chomp" );
        foreach my $mlssid (@$mlss_ids) {
            #left and right trim for unwanted spaces
            $mlssid =~ s/^\s+|\s+$//g;
            push @mlss_ids_list, $mlssid;
        }
    }

    foreach my $this_mlss_id (@mlss_ids_list) {
        my $mlssa = $compara_dba->get_MethodLinkSpeciesSetAdaptor;
        my $mlss  = $mlssa->fetch_by_dbID($this_mlss_id);
        if ($mode eq "retire"){
            $mlssa->retire_object($mlss);
        }
        elsif ($mode eq "delete"){
            $mlssa->delete($this_mlss_id);
        }
    }
}

exit(0);
