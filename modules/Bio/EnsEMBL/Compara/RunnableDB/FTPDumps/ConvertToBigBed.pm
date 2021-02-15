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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Hive::RunnableDB::DumpMultiAlign::ConvertToBigBed

=head1 DESCRIPTION

This Runnable is a simple extension of eHive's SystemCmd to convert a bed file to bigBed.
The only addition is that we need to fetch the size of the chromosomes from the database

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::ConvertToBigBed;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::DBSQL::DBConnection;

use base ('Bio::EnsEMBL::Hive::RunnableDB::SystemCmd', 'Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults() },

        'cmd' => [ '#big_bed_exe#', '-as=#autosql_file#', '-type=#bed_type#', '#bed_file#', '#chrom_sizes#', '#bigbed_file#' ],
    }
}


sub fetch_input {
    my $self = shift;

    my $genome_db_id = $self->param_required('genome_db_id');

    my $filename = $self->worker_temp_directory . "/chrom_size.$genome_db_id.txt";
    open(my $fh, '>', $filename);

    my $sql = q{SELECT dnafrag.name, length FROM dnafrag WHERE genome_db_id = ? AND is_reference = 1};
    my $sth = $self->compara_dba->dbc->prepare( $sql, { 'mysql_use_result' => 1 } );
    $sth->execute($genome_db_id);
    while (my $aref = $sth->fetchrow_arrayref) {
        print $fh join("\t", @$aref), "\n";
    }

    close $fh;

    $self->param('chrom_sizes', $filename);
}


1;
