#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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

import_compara_release_databases.pl

=head1 DESCRIPTION

This script runs CopyDBoverServer.pl with the correct parameters to
copy the Compara release databases to the current host.

It can work without any arguments if your environment is set properly,
i.e. ENSEMBL_CVS_ROOT_DIR and ENSADMIN_PSW are defined, otherwise the
options are listed below.

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

Prints help message and exits.

=back

=head2 GENERAL CONFIGURATION

=over

=item B<[--reg_conf registry_configuration_file]>

The Bio::EnsEMBL::Registry configuration file. Defaults to
$ENV{ENSEMBL_CVS_ROOT_DIR}/ensembl-compara/scripts/pipeline/production_reg_conf.pl

=item B<[--copydboverserver path/to/CopyDBoverServer.pl]>

Path to the CopyDBoverServer.pl script. Defaults to
${ENSEMBL_CVS_ROOT_DIR}/ensembl/misc-scripts/CopyDBoverServer.pl

=item B<[--ensadmin_psw this_is_a_secret_password]>

Password for the ensadmin MySQL user. Defaults to $ENV{ENSADMIN_PSW}

=back

=head2 INTERFACE

The script will generate a configuration file for CopyDBoverServer.pl with this structure

=over

=item Example configuration file

 #from_host      from_port   from_dbname                 to_host         to_port     to_dbname
 #
 compara5        3306        mm14_ensembl_compara_79      ens-staging2     3306        ensembl_compara_79
 compara5        3306        mm14_ensembl_ancestral_79    ens-staging2     3306        ensembl_ancestral_79

=back

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use Sys::Hostname;
use File::Temp qw(tempfile);

use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Registry;


## Command-line options
my ($reg_conf, $copydboverserver, $ensadmin_psw, $help, $compara_db_name, $ancestral_db_name);

GetOptions(
        'reg_conf=s'            => \$reg_conf,
        'c|copydboverserver=s'  => \$copydboverserver,
        'p|ensadmin_psw=s'      => \$ensadmin_psw,
        'a|ancestral_db_name=s' => \$ancestral_db_name,
        'd|compara_db_name=s'   => \$compara_db_name,

        'h|help'                => \$help,
);

if ($help) {
    pod2usage({-exitvalue => 0, -verbose => 2});
}

if (not $copydboverserver) {
    if (not $ENV{ENSEMBL_CVS_ROOT_DIR}) {
        die "--copydboverserver is not given, and cannot find \$ENSEMBL_CVS_ROOT_DIR in the environment\n";
    }
    $copydboverserver = $ENV{ENSEMBL_CVS_ROOT_DIR}.'/ensembl/misc-scripts/CopyDBoverServer.pl';
}
die "'$copydboverserver' does not exist\n" unless $copydboverserver;

if (not $ensadmin_psw) {
    if (not $ENV{ENSADMIN_PSW}) {
        die "--ensadmin_psw is not given, and cannot find \$ENSADMIN_PSW in the environment\n";
    }
    $ensadmin_psw = $ENV{ENSADMIN_PSW};
}

if (not $reg_conf) {
    if (not $ENV{ENSEMBL_CVS_ROOT_DIR}) {
        die "--reg_conf is not given, and cannot find \$ENSEMBL_CVS_ROOT_DIR in the environment\n";
    }
    $reg_conf = $ENV{ENSEMBL_CVS_ROOT_DIR}.'/ensembl-compara/scripts/pipeline/production_reg_conf.pl';
}

$compara_db_name ||= 'compara_curr';
$ancestral_db_name ||= 'ancestral_curr';

## use the Registry to list the databases
Bio::EnsEMBL::Registry->load_all($reg_conf, undef, undef, undef, "throw_if_missing");

sub find_dbc_for_reg_alias {
    my ($reg_name, $reg_type) = @_;
    my $compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($reg_name, $reg_type);
    die "'$reg_name' not found in the registry file\n" unless $compara_dba;
    return $compara_dba->dbc;
}

## Connections to the release databases
my $compara_curr_dbc = find_dbc_for_reg_alias($compara_db_name, 'compara');
my $compara_anc_dbc = find_dbc_for_reg_alias($ancestral_db_name, 'core');

## Write the configufation file for CopyDBoverServer.pl
my ($fh, $filename) = tempfile();
my $db_version = software_version();
my @data = (
    [$compara_curr_dbc->host, $compara_curr_dbc->port, $compara_curr_dbc->dbname, hostname(), 3306, "ensembl_compara_${db_version}"],
    [$compara_anc_dbc->host, $compara_anc_dbc->port, $compara_anc_dbc->dbname, hostname(), 3306, "ensembl_ancestral_${db_version}"],
);
print $fh join("\n", map {join("\t", @$_)} @data), "\n";
close($fh);

# This is the location of myisamchk, which may not be in the user's PATH
$ENV{PATH} = $ENV{PATH}.':/software/ensembl/central/bin/';

## Run CopyDBoverServer.pl and remove the configuration file
print STDERR ">> $copydboverserver -pass $ensadmin_psw -noflush $filename\n";
system $copydboverserver, '-pass', $ensadmin_psw, '-noflush', $filename;
unlink $filename;

