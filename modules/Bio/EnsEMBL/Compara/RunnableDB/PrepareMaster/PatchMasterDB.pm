=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::PatchMasterDB

=head1 SYNOPSIS



=cut

package Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::PatchMasterDB;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my ($self) = @_;
    return {
        %{$self->SUPER::param_defaults},
        'no_delete_tables'   => ['method_link_species_set_attr', 'species_set_tag'],
    }
}

sub fetch_input {
    my $self = shift;

    # first, read schema and replace CREATE TABLE calls
    my $schema_file = $self->param_required('schema_file');
    my $tmp_dir     = $self->worker_temp_directory;
    my $new_schema_file = "$tmp_dir/table.sql";
    open(SF , '<', $schema_file) or die "Cannot open $schema_file for reading";
    open(NSF, '>', $new_schema_file ) or die "Cannot open $new_schema_file for writing";
    while ( my $line = <SF> ) {
        if ( $line =~ /CREATE TABLE/ ) {
            $line =~ s/CREATE TABLE/CREATE TABLE IF NOT EXISTS/ unless ( $line =~ /CREATE TABLE IF NOT EXISTS/ );
        }
        print NSF $line;
    }
    close SF;
    close NSF;

    $self->param('new_schema_file', $new_schema_file);
}

sub run {
    my $self = shift;
    my $master_dba = $self->get_cached_compara_dba('master_db');

    my $dbc = $master_dba->dbc;
	my $connection_cmd = "mysql -h " . $dbc->host . ' -P ' . $dbc->port . ' -u ' . $dbc->user . ' -p' . $dbc->pass . ' ' . $dbc->dbname;

    # first, create all missing tables from the schema
    my $schema_run = $self->run_command("$connection_cmd < " . $self->param('new_schema_file'), {die_on_failure => 1});

    # next, apply all patches in order
    my $patch_names = $self->param_required('patch_names');
    my @patch_files = glob $patch_names;
    @patch_files = sort @patch_files;
    foreach my $patch ( @patch_files ) {
        my $patch_run = $self->run_command("$connection_cmd < $patch");
    }

    # finally, remove all empty tables (unless on exclusion list)
    my $empty_tables = $self->_get_empty_tables($master_dba);
    my $delete_table_sql = "DROP TABLE " . join(', ', @$empty_tables);
    print "$delete_table_sql\n";
    my $delete_sth = $master_dba->dbc->prepare($delete_table_sql);
    $delete_sth->execute;
}

sub _get_empty_tables {
    my ($self, $dba) = @_;

    my $empty_tables_sql = "SELECT table_name FROM INFORMATION_SCHEMA.TABLES
    WHERE table_type = 'BASE TABLE' AND table_rows = 0
    AND table_schema NOT IN('information_schema', 'sys', 'performance_schema', 'mysql')
    AND table_schema = '".$dba->dbc->dbname."'";
    $empty_tables_sql .= " AND table_name NOT IN ('" . join("', '", @{$self->param('no_delete_tables')}) . "')" if $self->param('no_delete_tables');
    print "$empty_tables_sql\n";
    my $sth = $dba->dbc->prepare($empty_tables_sql);
    $sth->execute();
    my @empty_tables = map {$_->[0]} @{$sth->fetchall_arrayref};
    print Dumper \@empty_tables;

    return \@empty_tables;
}

1;
