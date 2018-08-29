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


use strict;
use warnings;

=head1 NAME

load_mirbase_database.pl

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 DESCRIPTION

This script downloads databasd dumps available at the mirbase's FTP server
and loads them in a new database. 

=head1 SYNOPSIS

  perl update_genome.pl --help

  perl update_genome.pl
       [--mirbase_version 123]
       [--mysql_url mysql://...]
       [--drop_existing_db]

=head1 EXAMPLES

  perl load_mirbase_database.pl -mysql_url $(mysql-ens-compara-prod-1-ensadmin details url) -drop_existing_db -mirbase_version 22

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

Prints help message and exits.

=back

=head2 GENERAL CONFIGURATION

=over

=item B<[--mirbase_version 123]>

The version of miRBase to download

=back

=head2 B<TARGET DATABASE>

=over

=item B<[--mysql_url mysql://...]>

The target MySQL server. If the URL doesn't contain a database name, the database
will be named mirbase_${mirbase_version}.

=item B<[--drop_existing_db]>

The script will refuse to write to a database that exists unless this flag is set.

=back

=cut

use Cwd;
use File::Spec::Functions;
use File::Temp qw{tempdir};
use Getopt::Long;

use Bio::EnsEMBL::Hive::DBSQL::DBConnection;
use Bio::EnsEMBL::Compara::Utils::RunCommand;

my $help;
my $mysql_url;
my $drop_existing_db;
my $mirbase_version = 19;

GetOptions(
    'help'              => \$help,
    'mysql_url=s'       => \$mysql_url,
    'drop_existing_db'  => \$drop_existing_db,
    'mirbase_version=i' => \$mirbase_version,
  );

$| = 0;

# Print Help and exit if help is requested
if ($help or !$mysql_url) {
    use Pod::Usage;
    pod2usage({-exitvalue => 0, -verbose => 2});
}

my $dir = tempdir CLEANUP => 1;
my $orig_dir = Cwd::getcwd;
chdir $dir;

print "Preparing empty database ... ";
my $dbc = new Bio::EnsEMBL::Hive::DBSQL::DBConnection( -url => $mysql_url );
my $dbname = $dbc->dbname || "mirbase_${mirbase_version}";
$dbc->db_handle->do("DROP DATABASE IF EXISTS $dbname") if $drop_existing_db;
$dbc->db_handle->do("CREATE DATABASE $dbname");
$dbc->dbname($dbname);
$dbc->do("USE $dbname");
print "$dbname OK\n";

print "Downloading database dumps ... ";
my $mirbase_url = 'ftp://mirbase.org/pub/mirbase/';
my @command_download = ('lftp', -e => "mirror $mirbase_version/database_files", $mirbase_url); 
Bio::EnsEMBL::Compara::Utils::RunCommand->new_and_exec(\@command_download, {'die_on_failure' => 1});
print "OK\n";

print "Loading schema ... ";
Bio::EnsEMBL::Compara::Utils::RunCommand->new_and_exec( join(' ', @{$dbc->to_cmd()})." < database_files/tables.sql" , {'die_on_failure' => 1});
print "OK\n";

my $sth = $dbc->db_handle->table_info(undef, $dbname, q{%}, 'TABLE');
while(my $array = $sth->fetchrow_arrayref()) {
    my $table = $array->[2];
    my $txt_file = catfile('database_files', $table.'.txt');
    if(! -f "$txt_file.gz" || ! -r "$txt_file.gz") {
        next;
    }
    print "Loading table $table ... ";
    Bio::EnsEMBL::Compara::Utils::RunCommand->new_and_exec( ['gunzip', "$txt_file.gz"], {'die_on_failure' => 1});
    my $sql_load = sprintf(q{LOAD DATA LOCAL INFILE '%s' INTO TABLE `%s` FIELDS ESCAPED BY '\\\\'}, $txt_file, $table);
    $dbc->do($sql_load);
    print "OK\n";
}
$sth->finish;

chdir $orig_dir;

