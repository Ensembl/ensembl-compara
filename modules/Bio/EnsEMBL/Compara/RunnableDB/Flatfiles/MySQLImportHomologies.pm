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

=cut

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Flatfiles::MySQLImportHomologies

=head1 DESCRIPTION

This runnable takes a homology dump file (and optionally, attribute files)
and formats them to mysqlimport the data directly to the homology and
homology_member tables.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Flatfiles::MySQLImportHomologies;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use Bio::EnsEMBL::Compara::Utils::FlatFile qw(map_row_to_header);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift;

    # handle any attrib files that may have been passed
    $self->param('attribs', {});
    my $attrib_files = $self->param('attrib_files');
    return unless ( $attrib_files );

    # fetch all attributes from file list
    my %attribs;
    my $primary_key = 'homology_id';
    foreach my $f ( @$attrib_files ) {
        open( my $fh, '<', $f ) or die "Cannot open $f for reading";
        my $header = <$fh>;
        my @header_cols = split( /\s+/, $header );
        die "No $primary_key found in $f - please check file header line\n" unless grep {$_ eq $primary_key} @header_cols;
        while ( my $line = <$fh> ) {
            my $row = map_row_to_header($line, \@header_cols);
            my $primary_id = $row->{$primary_key};
            delete $row->{$primary_key};
            foreach my $attrib_name ( keys %$row ) {
                $attribs{$primary_id}->{$attrib_name} = $row->{$attrib_name};
            }
        }
        close $fh;
    }

    $self->param('attribs', \%attribs);
}

sub write_output {
    my $self = shift;

    my $filename = $self->param_required('homology_flatfile');
    my $attribs  = $self->param('attribs');

    # open homology file
    open(my $hom_fh, '<', $filename) or die "Cannot open $filename for reading";
    my $header_line = <$hom_fh>;
    my @header_cols = split(/\s+/, $header_line);

    # open output files - one per table in tmp space
    my $homology_csv = $self->worker_temp_directory . '/homology.txt';
    open(my $h_csv, '>', $homology_csv) or die "Cannot open $homology_csv for writing";
    my $homology_member_csv = $self->worker_temp_directory . '/homology_member.txt';
    open(my $hm_csv, '>', $homology_member_csv) or die "Cannot open $homology_member_csv for writing";

    # iterate over homology input and format it for later mysqlimport
    my $h_count = 0;
    my $homology_id_start = $self->param_required('homology_id_start');
    while ( my $line = <$hom_fh> ) {
        my $row = map_row_to_header($line, \@header_cols);

        # add the attribs
        foreach my $attrib_name ( 'goc_score', 'wga_coverage', 'is_high_confidence' ) {
            my $this_attrib = $attribs->{$row->{homology_id}}->{$attrib_name};
            $row->{$attrib_name} = defined $this_attrib ? $this_attrib : '\N';
        }

        my $this_homology_id = $homology_id_start + $h_count;
        my ( $homology_row, $homology_member_rows ) = $self->split_row_for_homology_tables($row, $this_homology_id);
        print $h_csv $homology_row;
        print $hm_csv $homology_member_rows;
        $h_count++;
    }
    close $h_csv;
    close $hm_csv;
    print "Files written to: $homology_csv & $homology_member_csv\n" if $self->debug;

    # mysqlimport the data
    my $this_dbc = $self->compara_dba->dbc;
    my $user = $this_dbc->username;
    my $pass = $this_dbc->password;
    my $host = $this_dbc->host;
    my $port = $this_dbc->port;
    my $dbname = $this_dbc->dbname;

    # Disconnect from the database before starting the import
    $this_dbc->disconnect_if_idle();

    my $import_cmd = join(' ', 
        "mysqlimport --host=$host --port=$port --user=$user --password=$pass",
        "--local --lock-tables=0 --fields-terminated-by=','",
        $self->param('replace') ? '--replace' : '--ignore',
        $dbname
    );
    $self->run_command("$import_cmd $homology_csv", { die_on_failure => 1 });
    $self->run_command("$import_cmd $homology_member_csv", { die_on_failure => 1 });

    # Make sure all the homologies have been copied correctly
    my $mlss_id = $self->param_required('mlss_id');
    my $h_rows = $self->compara_dba->dbc->sql_helper->execute_single_result(
        -SQL => "SELECT COUNT(*) FROM homology WHERE method_link_species_set_id = $mlss_id"
    );
    die "The number of lines in the homology flat file doesn't match the number of rows written in the homology table" if $h_count != $h_rows;
}

sub split_row_for_homology_tables {
    my ( $self, $row, $homology_id ) = @_;

    my $homology_row = join(",",
        $homology_id,
        $row->{mlss_id},
        $row->{homology_type},
        $row->{is_tree_compliant},
        '\N','\N','\N','\N','\N',
        $row->{species_tree_node_id},
        $row->{gene_tree_node_id},
        $row->{gene_tree_root_id},
        $row->{goc_score},
        $row->{wga_coverage},
        $row->{is_high_confidence},
    ) . "\n";

    my $homology_member_rows;
    foreach my $prefix ( '', 'homology_' ) {
        my $this_hm_row = join(",",
            $homology_id,
            $row->{"${prefix}gene_member_id"},
            $row->{"${prefix}seq_member_id"},
            $row->{"${prefix}cigar_line"},
            $row->{"${prefix}perc_cov"},
            $row->{"${prefix}perc_id"},
            $row->{"${prefix}perc_pos"},
        );
        $homology_member_rows .= "$this_hm_row\n";
    }

    return ( $homology_row, $homology_member_rows );
}

1;
