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

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::StoreLowCovSpeciesSet

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::StoreLowCovSpeciesSet;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::SpeciesSet;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub run {
    my $self = shift;

    my $genescaffold_sql = q/
        SELECT DISTINCT
            genome_db_id
        FROM
            genome_db
        JOIN
            dnafrag USING (genome_db_id)
        WHERE
            coord_system_name = 'genescaffold'
    /;

    my $compara_helper = $self->compara_dba->dbc->sql_helper;
    my $low_cov_gdb_ids = $compara_helper->execute_simple( -SQL => $genescaffold_sql );

    my $genome_dba = $self->compara_dba->get_GenomeDBAdaptor;
    my @low_cov_gdbs = map { $genome_dba->fetch_by_dbID($_) } @{$low_cov_gdb_ids};
    my $species_set = Bio::EnsEMBL::Compara::SpeciesSet->new(
        -NAME => 'low-coverage-assembly',
        -GENOME_DBS => \@low_cov_gdbs,
    );
    $self->param('species_set', $species_set);
}

sub write_output {
    my $self = shift @_;

    $self->compara_dba->get_SpeciesSetAdaptor->store( $self->param('species_set') );
}

1;
