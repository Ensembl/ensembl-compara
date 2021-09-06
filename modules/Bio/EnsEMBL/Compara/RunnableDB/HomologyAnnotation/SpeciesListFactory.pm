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

Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::SpeciesListFactory

=head1 DESCRIPTION

Simple species_list factory to dataflow from the species_list parameter:
the genome_name and genome_db_ids.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::SpeciesListFactory;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub write_output {
    my $self = shift;

    my $species_list = $self->param_required('species_list');
    my $genome_dba   = $self->compara_dba->get_GenomeDBAdaptor;

    foreach my $genome_name ( @$species_list ) {
        # We want to get the GenomeDB of the query species, not the reference
        my @genome_dbs = sort { $a->dbID <=> $b->dbID } @{ $genome_dba->fetch_all_by_name($genome_name) };
        my $genome_db = $genome_dbs[0];
        $self->dataflow_output_id( { 'genome_name' => $genome_name, 'genome_db_id' => $genome_db->dbID }, 1 );
    }
}

1;
