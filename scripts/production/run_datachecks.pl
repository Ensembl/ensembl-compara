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

run_datachecks.pl

=head1 DESCRIPTION

This script is a wrapper around ensembl-datacheck's eponym script that
accepts our production_reg_conf-based configuration and automatically sets
the connection details of the database being tested and the previous one.

=head1 SYNOPSIS

    perl run_datachecks.pl $COMPARA_REG compara_curr --group compara

    perl run_datachecks.pl \
        --reg_conf registry_configuration_file --reg_alias compara_curr \
        --name CompareMSANames

=head1 ARGUMENTS

The script reads these arguments and passes the other ones straight to run_datachecks.pl

=head2 DATABASE SETUP

=over

=item B<[--url mysql://user[:passwd]@host[:port]/dbname]>

URL of the database to test.

=item B<[--reg_conf registry_configuration_file]>

The Bio::EnsEMBL::Registry configuration file. Must be given to refer to
one of the databases by registry name (alias) instead of URLs.

=item B<[--reg_type reg_type]>

The "type" or "group" under which the database is to be found in the Registry.
Defaults to "compara".

=item B<[--reg_alias|--reg_name name]>

The name or "species" under which the database is to be found in the Registry.

=item B<[--prev_url mysql://user[:passwd]@host[:port]/dbname]>

URL of the previous database.

=item B<[--prev_alias|--prev_reg_name name]>

The name or "species" under which the previous database is to be found in the Registry.
Defaults to "compara_prev".

=back

=head2 DATACHECK SETUP

=over

=item B<[--dc-runner /path/to/run_datachecks.pl]>

The path to the run_datachecks.pl of ensembl-datacheck. If not given a
default will be formed using the ENSEMBL_ROOT_DIR environment variable.

=back

=cut

use strict;
use warnings;

use Getopt::Long qw(:config pass_through);

use Bio::EnsEMBL::Registry;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::Registry;

my ($url, $reg_conf, $reg_type, $reg_alias);
my ($prev_url, $prev_alias);
my ($dc_runner);

# Arguments parsing
GetOptions(
    'url=s'                         => \$url,
    'reg_conf|regfile|reg_file=s'   => \$reg_conf,
    'reg_type=s'                    => \$reg_type,
    'reg_alias|regname|reg_name=s'  => \$reg_alias,
    'prev_url=s'                    => \$prev_url,
    'prev_alias|prev_reg_name=s'    => \$prev_alias,
    'dc-runner=s'                   => \$dc_runner,
);

if (($reg_alias or $prev_alias) xor $reg_conf) {
    print "\nERROR: The registry configuration file (--reg_conf) is required to use aliases (--reg_alias or --prev_alias) and cannot be used with URLs (--url or --prev_url).\n\n";
    exit 1;
}

if ($url and $reg_alias) {
    print "\nERROR: Both --url and --reg_alias are defined. Don't know which one to use\n\n";
    exit 1;
} elsif (!$url and !$reg_alias) {
    print "\nERROR: Neither --url nor --reg_alias are defined. Don't know what database to use\n\n";
    exit 1;
}

if ($prev_url and $prev_alias) {
    print "\nERROR: Both --prev_url and --prev_alias are defined. Don't know which one to use\n\n";
    exit 1;
}

unless ($dc_runner) {
    die "Need to give the --dc-runner option or set the ENSEMBL_ROOT_DIR environment variable to use the default" unless $ENV{ENSEMBL_ROOT_DIR};
    $dc_runner = $ENV{ENSEMBL_ROOT_DIR} . '/ensembl-datacheck/scripts/run_datachecks.pl';
}
die "ERROR: '$dc_runner' is not a valid executable" unless -x $dc_runner;

if ($reg_conf) {
    Bio::EnsEMBL::Registry->load_all($reg_conf);
}
my $dba = $reg_alias
    ? Bio::EnsEMBL::Registry->get_DBAdaptor( $reg_alias, $reg_type || 'compara' )
    : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -URL => $url );

# Common parameters
my @params = (
    '--host'   => $dba->dbc->host,
    '--port'   => $dba->dbc->port,
    '--user'   => 'ensro',             # Fallback to ensro to ensure we don't write to it by accident
    '--dbname' => $dba->dbc->dbname,
    '--dbtype' => 'compara',
    '--history_file' => '/nfs/panda/ensembl/production/datachecks/history/compara.json',
);

if ($reg_conf) {
    push @params, (
        '--registry_file' => $reg_conf,
    );
}

if ($prev_url) {
    push @params, (
        '--old_server_uri' => $prev_url,
    );
} else {
    $prev_alias ||= 'compara_prev';
    my $prev_dba = Bio::EnsEMBL::Registry->get_DBAdaptor( $prev_alias, $reg_type || 'compara' );
    die "ERROR: Cannot find the alias '$prev_alias' in the Registry" unless $prev_dba;
    push @params, (
        '--old_server_uri' => $prev_dba->url,
    );
}

print "Executing: ", join(" ", $dc_runner, @params, @ARGV), "\n\n";

exec($dc_runner, @params, @ARGV);
