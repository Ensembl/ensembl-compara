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


=head1 MAIN

=cut

use strict;
use warnings;

use Cwd;
use File::Basename;
use Test::More;

use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Utils::IO qw/work_with_file/;

# Initialize a MultiTestDB object
my $multitestdb = bless {}, 'Bio::EnsEMBL::Test::MultiTestDB';
$multitestdb->curr_dir( File::Basename::dirname(Cwd::realpath($0)) );
$multitestdb->_rebless;
$multitestdb->species('compara');

my $db_name = $multitestdb->create_db_name('schema');
my $statements = read_sqls();


foreach my $server_mode (qw(TRADITIONAL ANSI)) {
    subtest "$server_mode mode", sub {

        # Create the database and set the SQL mode
        drop_database_if_exists($multitestdb, $db_name);
        my $db = $multitestdb->create_and_use_db($multitestdb->dbi_connection(), $db_name);
        $db->do("SET SESSION sql_mode = '$server_mode'");

        # Test every statement
        foreach my $s (@$statements) {
            eval {
                $db->do($s->[1]);
                pass($s->[0]);
            };
            if (my $err_msg = $@) {
                fail($s->[0]);
                diag($err_msg);
            }
        }
    };
}
# No need to drop the database because it will be destroyed when
# $multitestdb goes out of scope

done_testing();


=head1 HELPER FUNCTIONS

=head2 drop_database_if_exists

  Arg[1]      : Bio::EnsEMBL::Test::MultiTestDB $multitestdb. Object refering to the database server
  Arg[2]      : String $db_name. The database name
  Description : Drop the database if it exists and close the existing
                connection objects.
  Returntype  : None

=cut

sub drop_database_if_exists {
    my ($multitestdb, $db_name) = @_;
    if ($multitestdb->_db_exists($multitestdb->dbi_connection, $db_name)) {
        $multitestdb->_drop_database($multitestdb->dbi_connection, $db_name);
        $multitestdb->disconnect_dbi_connection;
    }
}


=head2 read_sqls

  Description : Read the content of the schema definition files and return
                them as a list of SQL statements with titles
  Returntype  : List of string pairs

=cut

sub read_sqls {

    # Same code as in MultiTestDB::load_sql but without the few lines we
    # don't need
    my $all_sql = '';
    foreach my $file_name (qw(table.sql pipeline-tables.sql)) {
        my $sql_file = $ENV{ENSEMBL_CVS_ROOT_DIR} . '/ensembl-compara/sql/' . $file_name;
        note("Reading SQL from '$sql_file'");
        work_with_file($sql_file, 'r', sub {
                my ($fh) = @_;
                my $is_comment = 0;
                while(my $line = <$fh>) {
                    if ($is_comment) {
                        $is_comment = 0 if $line =~ m/\*\//;
                    } elsif ($line =~ m/\/\*/) {
                        $is_comment = 1 unless $line =~ m/\*\//;
                    } elsif ($line !~ /^#/ && $line !~ /^--( |$)/ && $line =~ /\S/) {
                        #ignore comments and white-space lines
                        $all_sql .= $line;
                    }
                }
                return;
            });
    }

    # We *want* to test foreign keys
    $all_sql =~ s/ENGINE=MyISAM/ENGINE=InnoDB/g;
    $all_sql =~ s/;$//;
    my @statements;
    foreach my $sql (split( /;/, $all_sql )) {
        $sql =~ s/^\n*//s;
        # $title will usually be something like "CREATE TABLE dnafrag"
        my $title = $sql;
        $title =~ s/\s+\(.*//s;
        push @statements, [$title, $sql];
    }

    return \@statements;
}

