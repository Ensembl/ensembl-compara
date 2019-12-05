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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::UpdateHomologies

=head1 DESCRIPTION

Update the homology table with data from flatfiles. Files should be given as
an arrayref in the `attrib_files` parameter. File headers match fields in the
homology table (`homology_id` is required).

=cut

package Bio::EnsEMBL::Compara::RunnableDB::UpdateHomologies;

use warnings;
use strict;

use Data::Dumper;

use Bio::EnsEMBL::Registry;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::FlatFile qw(map_row_to_header);

use base ('Bio::EnsEMBL::Compara::RunnableDB::SqlCmd');

sub param_defaults {
    my ($self) = @_;
    return {
        %{$self->SUPER::param_defaults},
        'dry_run' => 0,
    }
}

sub fetch_input {
    my $self = shift;

    # fetch all homology attributes from file list
    my %hom_attribs;
    my @attrib_files = @{$self->param('attrib_files')};
    foreach my $f ( @attrib_files ) {
        open( my $fh, '<', $f ) or die "Cannot open $f for reading";
        my $header = <$fh>;
        my @header_cols = split( /\s+/, $header );
        while ( my $line = <$fh> ) {
            my $row = map_row_to_header($line, \@header_cols);
            my $homology_id = $row->{homology_id};
            die "No homology_id found in $f - please check file header line\n" unless $homology_id;
            delete $row->{homology_id};
            foreach my $attrib_name ( keys %$row ) {
                $hom_attribs{$homology_id}->{$attrib_name} = $row->{$attrib_name};
            }
        }
        close $fh;
    }

    # generate UPDATE SQL commands for homology table
    my @sql_cmds;
    foreach my $h_id ( keys %hom_attribs ) {
        my $sql = 'UPDATE homology SET ';
        $sql .= join(',', map { $_ . '=' . $hom_attribs{$h_id}->{$_} } keys %{$hom_attribs{$h_id}});
        $sql .= " WHERE homology_id = $h_id";
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
