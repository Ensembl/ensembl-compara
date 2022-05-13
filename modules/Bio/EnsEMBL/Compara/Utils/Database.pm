=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::Utils::Database

=head1 DESCRIPTION

Common utility methods for compara databases

=cut

package Bio::EnsEMBL::Compara::Utils::Database;

use strict;
use warnings;
use base qw(Exporter);
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use List::Util;

our %EXPORT_TAGS;
our @EXPORT_OK;

@EXPORT_OK = qw(
    table_exists
    db_exists
);
%EXPORT_TAGS = (
  all     => [@EXPORT_OK]
);

=head2 table_exists

    Arg[1]      :  Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dbc (mandatory)
    Arg[2]      :  $table_name (mandatory)
    Description :  Check to see if table exists in specific database
    Returns     :  True if table exists, False otherwise
    Exceptions  :  None.

=cut

sub table_exists {
    my ($dbc, $table_name) = @_;

    my $db_name = $dbc->dbname();
    my $sth = $dbc->db_handle->table_info( undef, $db_name, $table_name, 'TABLE' );

    $sth->execute;
    my @info = $sth->fetchrow_array;

    return scalar( @info );
}

=head2 db_exists

    Arg[1]      :  $host (mandatory)
    Arg[2]      :  $dbname (mandatory)
    Description :  Check to see if database exists
    Returns     :  True if database exists, False otherwise
    Exceptions  :  None.

=cut

sub db_exists {
    my ($host, $dbname) = @_;

    my $port    = Bio::EnsEMBL::Compara::Utils::Registry::get_port($host);
    my $rw_user = Bio::EnsEMBL::Compara::Utils::Registry::get_rw_user($host);
    my $rw_pwd  = Bio::EnsEMBL::Compara::Utils::Registry::get_rw_pass($host);

    my $dsn = "DBI:mysql:database=;host=$host" . ";port=$port";
    my $dbh = DBI->connect( $dsn, $rw_user, $rw_pwd ) || die "Could not connect to MySQL server";
    my $sql = qq/
        SELECT
            SCHEMA_NAME
        FROM
            INFORMATION_SCHEMA.SCHEMATA
        WHERE
            SCHEMA_NAME = "$dbname"
    /;
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    my @info = $sth->fetchrow_array;

    return scalar( @info );
}


1;
