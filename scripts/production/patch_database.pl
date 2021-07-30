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

patch_database.pl

=head1 DESCRIPTION

This script is a wrapper around ensembl's schema_patcher.pl to run it
taking connection details from a production_reg_conf file.

=head1 SYNOPSIS

    perl patch_database.pl $COMPARA_REG compara_prev

=head1 ARGUMENTS

=head2 DATABASE SETUP

=over

=item B<[--url mysql://user[:passwd]@host[:port]/dbname]>

URL of the database to patch.

=item B<[--reg_conf registry_configuration_file]>

The Bio::EnsEMBL::Registry configuration file. Must be given to refer to
the database by registry name (alias) instead of a URL.

=item B<[--reg_type reg_type]>

The "type" or "group" under which the database is to be found in the Registry.
Defaults to "compara".

=item B<[--reg_alias|--reg_name name]>

The name or "species" under which the database is to be found in the Registry.

=back

=head2 SCHEMA PATCHER SETUP

=over

=item B<[--schema_patcher /path/to/schema_patcher.pl]>

The path to schema_patcher.pl. If not given a default will be
formed using the ENSEMBL_ROOT_DIR environment variable.

=back

=cut

use strict;
use warnings;

use Getopt::Long qw(:config pass_through);

use Bio::EnsEMBL::Registry;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::Registry;

my ($url, $reg_conf, $reg_type, $reg_alias);
my ($schema_patcher);

# Arguments parsing
GetOptions(
    'url=s'                         => \$url,
    'reg_conf|regfile|reg_file=s'   => \$reg_conf,
    'reg_type=s'                    => \$reg_type,
    'reg_alias|regname|reg_name=s'  => \$reg_alias,
    'schema_patcher=s'              => \$schema_patcher,
) or die "Error in command line arguments\n";

unless ($url or ($reg_conf and $reg_alias)) {
    print "\nERROR: Neither --url nor --reg_conf and --reg_alias are defined. Some of those are needed to refer to the database being patched\n\n";
    exit 1;
}

if ($url and $reg_alias) {
    print "\nERROR: Both --url and --reg_alias are defined. Don't know which one to use\n\n";
    exit 1;
}

if ($reg_conf) {
    Bio::EnsEMBL::Registry->load_all($reg_conf);
}
my $dba = $url
    ? Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -URL => $url )
    : Bio::EnsEMBL::Registry->get_DBAdaptor( $reg_alias, $reg_type || 'compara' );

unless ($schema_patcher) {
    die "Need to give the --schema_patcher option or set the ENSEMBL_ROOT_DIR environment variable to use the default" unless $ENV{ENSEMBL_ROOT_DIR};
    $schema_patcher = $ENV{ENSEMBL_ROOT_DIR} . '/ensembl/misc-scripts/schema_patcher.pl';
}
die "ERROR: '$schema_patcher' is not a valid executable" unless -x $schema_patcher;


if ($dba->dbc->user eq 'ensro') {
    warn "Switching to the ensadmin user\n";
}

my @params = (
    '--host'     => $dba->dbc->host,
    '--port'     => $dba->dbc->port,
    '--user'     => Bio::EnsEMBL::Compara::Utils::Registry::get_rw_user($dba->dbc->host),
    '--pass'     => Bio::EnsEMBL::Compara::Utils::Registry::get_rw_pass($dba->dbc->host),
    '--database' => $dba->dbc->dbname,
);

print "Executing: ", join(" ", $schema_patcher, @params, @ARGV), "\n\n";

exec($schema_patcher, @params, @ARGV);
