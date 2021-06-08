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

backup_master.pl

=head1 DESCRIPTION

This script is a wrapper around sudo and mysqldump to dump the master database,
taking its location from a production_reg_conf file.

=head1 SYNOPSIS

    perl backup_master.pl --reg_conf $COMPARA_REG_PATH

    perl backup_master.pl $COMPARA_REG compara_master --label "pre100"

=head1 ARGUMENTS

=head2 DATABASE SETUP

=over

=item B<[--url mysql://user[:passwd]@host[:port]/dbname]>

URL of the database to dump.

=item B<[--reg_conf registry_configuration_file]>

The Bio::EnsEMBL::Registry configuration file. Must be given to refer to
the database by registry name (alias) instead of a URL.

=item B<[--reg_type reg_type]>

The "type" or "group" under which the database is to be found in the Registry.
Defaults to "compara".

=item B<[--reg_alias|--reg_name name]>

The name or "species" under which the database is to be found in the Registry.
Defaults to "compara_master".

=back

=head2 DUMP SETUP

=over

=item B<[--dump_path /path/to_dumps]>

Where to store the dumps. Defaults to the shared warehouse directory.

=item B<[--username username]>

Name of the user used to create the dumps.
Defaults to "compara_ensembl". Set this to an empty string to create the
backup as yourself.

=item B<[--label str]>

Label to append to the dump file name.

=back

=cut

use strict;
use warnings;

use Getopt::Long;
use POSIX qw(strftime);

use Bio::EnsEMBL::Registry;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::Registry;

my ($url, $reg_conf, $reg_type, $reg_alias);
my ($dump_path, $username, $label);

# Arguments parsing
GetOptions(
    'url=s'                         => \$url,
    'reg_conf|regfile|reg_file=s'   => \$reg_conf,
    'reg_type=s'                    => \$reg_type,
    'reg_alias|regname|reg_name=s'  => \$reg_alias,
    'dump_path=s'                   => \$dump_path,
    'username=s'                    => \$username,
    'label=s'                       => \$label,
) or die "Error in command line arguments\n";

if (@ARGV) {
    die "ERROR: There are invalid arguments on the command-line: ". join(" ", @ARGV). "\n";
}

unless ($url or $reg_conf) {
    print "\nERROR: Neither --url nor --reg_conf are defined. Some of those are needed to refer to the database being dumped\n\n";
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
    : Bio::EnsEMBL::Registry->get_DBAdaptor( $reg_alias || 'compara_master', $reg_type || 'compara' );

my $division = $dba->get_division;

my @params = (
    '--host'    => $dba->dbc->host,
    '--port'    => $dba->dbc->port,
    '--user'    => 'ensro',
);

$dump_path //= $ENV{'COMPARA_WAREHOUSE'} . '/master_db_dumps';
$username  //= 'compara_ensembl';
my $date = strftime '%Y%m%d', localtime;
my $dump_name = "ensembl_compara_master_${division}.${date}" . ($label ? ".$label" : ''). ".sql";

my $cmd = join(' ', 'mysqldump', @params, $dba->dbc->dbname, '>', "$dump_path/$dump_name");
if ($username) {
    print "Executing as $username: $cmd\n\n";
    exec('sudo', -u => $username, '/bin/bash', -c => $cmd);
} else {
    print "Executing: $cmd\n\n";
    exec('/bin/bash', -c => $cmd);
}
