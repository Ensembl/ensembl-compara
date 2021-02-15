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

Bio::EnsEMBL::Compara::RunnableDB::Flatfiles::UpdateTableFromFile

=head1 DESCRIPTION

Update a table with data from flatfiles. Files should be given as an arrayref
in the `attrib_files` parameter. File headers match fields in the table's
column names (`primary_key` is required and should be present in all files).

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Flatfiles::UpdateTableFromFile;

use warnings;
use strict;

use Data::Dumper;
use Bio::EnsEMBL::Compara::Utils::FlatFile qw(map_row_to_header);

use base ('Bio::EnsEMBL::Compara::RunnableDB::SqlCmd');

sub param_defaults {
    my ($self) = @_;
    return {
        %{$self->SUPER::param_defaults},
        'dry_run'     => 0,
    }
}

sub fetch_input {
    my $self = shift;

    my $table       = $self->param_required('table');
    my $primary_key = $self->param_required('primary_key');

    # fetch all attributes from file list
    my %attribs;
    my @attrib_files = @{$self->param('attrib_files')};
    foreach my $f ( @attrib_files ) {
        open( my $fh, '<', $f ) or die "Cannot open $f for reading";
        my $header = <$fh>;
        my @header_cols = split( /\s+/, $header );
        die "No $primary_key found in $f - please check file header line\n" unless grep {$_ eq $primary_key} @header_cols;
        while ( my $line = <$fh> ) {
            my $row = map_row_to_header($line, \@header_cols);
            my $primary_id = $row->{$primary_key};
            die "$primary_key is empty in file $f" unless $primary_id;
            delete $row->{$primary_key};
            foreach my $attrib_name ( keys %$row ) {
                $attribs{$primary_id}->{$attrib_name} = $row->{$attrib_name};
            }
        }
        close $fh;
    }

    # generate UPDATE SQL commands
    my @sql_cmds;
    foreach my $id ( keys %attribs ) {
        my $sql = "UPDATE $table SET ";
        $sql .= join(',', map { $_ . '=' . $attribs{$id}->{$_} } keys %{$attribs{$id}});
        $sql .= " WHERE $primary_key = $id";
        push @sql_cmds, $sql;
    }

    print Dumper \@sql_cmds if $self->debug;

    $self->param('db_conn', $self->compara_dba);
    $self->param('sql', \@sql_cmds);

    if ( $self->param('dry_run') ){
        $self->input_job->autoflow(0);
        $self->complete_early("Dry-run mode : exiting...");
    }
}

1;
