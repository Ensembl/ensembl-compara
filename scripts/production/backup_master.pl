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

=head1 NAME

backup_master.pl

=head1 DESCRIPTION

This script is a wrapper around sudo and mysqldump to dump the master database,
taking its location from a production_reg_conf file.

=head1 SYNOPSIS

  perl backup_master.pl $COMPARA_REG compara_curr -group compara

  perl backup_master.pl \
    --reg_conf registry_configuration_file --reg_alias compara_curr

=head1 ARGUMENTS

The script reads these arguments and passes the other ones straight to run-configurable-testrunner.sh

=head2 DATABASE SETUP

=over

=item B<[--url mysql://user[:passwd]@host[:port]/dbname]>

URL of the database to test.

=item B<[--reg_conf registry_configuration_file]>

The Bio::EnsEMBL::Registry configuration file. If none given and no URL is
given, the one set in ENSEMBL_REGISTRY will be used if defined, if not
~/.ensembl_init will be used.

=item B<[--reg_type reg_type]>

The "type" or "group" under which the database is to be found in the Registry.

=item B<[--reg_alias|--reg_name name]>

The name or "species" under which the database is to be found in the Registry.
Defaults to "compara_master".

=back

=head2 DUMP SETUP

=over

=item B<[--dump_path /path/to_dumps]>

Where to store the dumps. Defaults to the shared warehouse directory.

=item B<[--label str]>

Label to add to the file name

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
my ($dump_path, $label);

# Arguments parsing
GetOptions(
    'url=s'                         => \$url,
    'reg_conf|regfile|reg_file=s'   => \$reg_conf,
    'reg_type=s'                    => \$reg_type,
    'reg_alias|regname|reg_name=s'  => \$reg_alias,
    'dump_path=s'                   => \$dump_path,
    'label=s'                       => \$label,
) or die "Error in command line arguments\n";

if (@ARGV) {
    die "ERROR: There are invalid arguments on the command-line: ". join(" ", @ARGV). "\n";
}

unless ($url or ($reg_conf and $reg_alias)) {
    print "\nNeither --url nor --reg_conf and --reg_alias are defined. Some of those are needed to refer to the database being tested\n\n";
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

$dump_path ||= '/nfs/production/panda/ensembl/warehouse/compara/master_db_dumps';

my $date = strftime '%Y%m%d', localtime;
my $dump_name = "ensembl_compara_master_${division}.${date}" . ($label ? ".$label" : ''). ".sql";

my $cmd = join(' ', 'mysqldump', @params, $dba->dbc->dbname, '>', "$dump_path/$dump_name");
print "Executing: $cmd\n\n";
exec('sudo', -u => 'compara_ensembl', '/bin/bash', -c => $cmd);
