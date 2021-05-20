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

run_healthchecks.pl

=head1 DESCRIPTION

This script is a wrapper around ensj-healthcheck's run-configurable-testrunner.sh
which accepts production_reg_conf-based configuration and automatically sets
the correct host/port parameters for the division being tested.

=head1 SYNOPSIS

  perl run_healthchecks.pl $COMPARA_REG compara_curr -g ComparaAll

  perl run_healthchecks.pl \
    --reg_conf registry_configuration_file --reg_alias compara_curr \
    -t org.ensembl.healthcheck.testcase.compara.MLSSTagGERPMSA --repair

=head1 ARGUMENTS

The script reads these arguments and passes the other ones straight to run-configurable-testrunner.sh

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

=item B<[--compara_master|--master_db name_or_url]>

A reference to the master database to compare against. Can be either a
Registry alias (assumed to be in the "compara" group/type) or a URL.
Defaults to 'compara_master', i.e. a Registry lookup.

=back

=head2 HEALTHCHECK SETUP

=over

=item B<[--ensj-testrunner /path/to/run-configurable-testrunner.sh]>

The path to run-configurable-testrunner.sh. If not given a default will be
formed using the ENSEMBL_ROOT_DIR environment variable.

=item B<[--ensj-json-config /path/to/ensj-healthcheck.json]>

The path to ensj-healthcheck.json. If not given a default will be formed
using the ENSEMBL_ROOT_DIR environment variable.

=item B<[--repair]>

Use this flag if you want to use the "repair" mode of the healtcheck.

=back

=cut

use strict;
use warnings;

use File::Basename qw(dirname);
use Getopt::Long qw(:config pass_through);
use JSON qw(decode_json);

use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::IO qw(:slurp);

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::Registry;

my ($url, $reg_conf, $reg_type, $reg_alias, $master_db);
my ($repair, $ensj_testrunner, $ensj_json_config);

# Default values
$master_db = 'compara_master';

# Arguments parsing
GetOptions(
    'url=s'                         => \$url,
    'reg_conf|regfile|reg_file=s'   => \$reg_conf,
    'reg_type=s'                    => \$reg_type,
    'reg_alias|regname|reg_name=s'  => \$reg_alias,
    'master_db|compara_master=s'    => \$master_db,
    'ensj-testrunner=s'             => \$ensj_testrunner,
    'ensj-json-config=s'            => \$ensj_json_config,
    'repair'                        => \$repair,
);

if ($reg_alias xor $reg_conf) {
    print "\nERROR: The registry configuration file (--reg_conf) is required to use an alias (--reg_alias) and cannot be used with a URL (--url).\n\n";
    exit 1;
}

if ($url and $reg_alias) {
    print "\nERROR: Both --url and --reg_alias are defined. Don't know which one to use\n\n";
    exit 1;
} elsif (!$url and !$reg_alias) {
    print "\nERROR: Neither --url nor --reg_alias are defined. Don't know what database to use\n\n";
    exit 1;
}

if ($reg_conf) {
    Bio::EnsEMBL::Registry->load_all($reg_conf);
}
my $dba = $reg_alias
    ? Bio::EnsEMBL::Registry->get_DBAdaptor( $reg_alias, $reg_type || 'compara' )
    : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -URL => $url );

# Use get_division() method for compara DBAdaptors, COMPARA_DIV environment variable in any other case
my $division = ($dba->group eq 'compara') ? $dba->get_division : $ENV{COMPARA_DIV};

unless ($ensj_testrunner) {
    die "Need to give the --ensj-testrunner option or set the ENSEMBL_ROOT_DIR environment variable to use the default" unless $ENV{ENSEMBL_ROOT_DIR};
    $ensj_testrunner = $ENV{ENSEMBL_ROOT_DIR} . '/ensj-healthcheck/run-configurable-testrunner.sh';
}
die "'$ensj_testrunner' is not a valid executable" unless -x $ensj_testrunner;

unless ($ensj_json_config) {
    die "Need to give the --ensj-config option or set the ENSEMBL_ROOT_DIR environment variable to use the default" unless $ENV{ENSEMBL_ROOT_DIR};
    $ensj_json_config = $ENV{ENSEMBL_ROOT_DIR} . "/ensembl-compara/conf/$division/ensj-healthcheck.json";
}
die "'$ensj_json_config' is not a valid file" unless -e $ensj_json_config;
my $ensj_config = decode_json(slurp($ensj_json_config));


# Common parameters
my @params = (
    '--host'    => $dba->dbc->host,
    '--port'    => $dba->dbc->port,
    '--driver'  => 'org.gjt.mm.mysql.Driver',
    '--release' => $dba->get_MetaContainer->get_schema_version,
    '--test_databases'  => $dba->dbc->dbname,
);

# RO or RW user depending on the --repair option
if ($repair) {
    push @params, (
        '--user'     =>  Bio::EnsEMBL::Compara::Utils::Registry::get_rw_user($dba->dbc->host),
        '--password' =>  Bio::EnsEMBL::Compara::Utils::Registry::get_rw_pass($dba->dbc->host),
        '--repair'   => 1,
    );
} else {
    push @params, (
        '--user'    =>  'ensro',
    );
}

# Add the master database if one is available (otherwise defaults to ensj-healthcheck name matching)
if ($master_db) {
    my $master_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($master_db);
    die "Cannot find a database with the alias '$master_db' in the Registry" unless $master_dba;
    push @params, (
        '--compara_master.database', $master_dba->dbc->dbname,
    );
}

# Division-specific configuration
foreach my $key (qw(host1 host2 host3 secondary.host)) {

    # Extract the prefix and the suffix to form the other arguments
    my ($key_prefix, $key_suffix) = split('host', $key);

    # Configure the host if it is set
    if (my $host = $ensj_config->{$key}) {
        my $port = Bio::EnsEMBL::Compara::Utils::Registry::get_port($host);
        push @params, (
            "--${key_prefix}host${key_suffix}"    => $host,
            "--${key_prefix}port${key_suffix}"    => $port,
            "--${key_prefix}user${key_suffix}"    => 'ensro',
            "--${key_prefix}driver${key_suffix}"  => 'org.gjt.mm.mysql.Driver',
        );
    } else {
        # Trick to tell the HC to ignore the default value that may be set in database.defaults.properties
        # We rely on the fact that the HC doesn't die if the host name is not valid
        push @params, (
            "--${key_prefix}host${key_suffix}"    => '""',
        );
    }
}

print "Executing: ", join(" ", $ensj_testrunner, @params, @ARGV), "\n\n";

# Need to change directory because database.default.properties is read from the current directory
chdir dirname($ensj_testrunner);
exec($ensj_testrunner, @params, @ARGV);
