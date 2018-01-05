=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::MercatorFileFactory 

=head1 DESCRIPTION
Create jobs for DumpMercatorFiles

Supported keys:
    'mlss_id' => <number>
     Pecan method link species set id. Obligatory

=cut

package Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::MercatorFileFactory;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub write_output {
    my ($self) = @_;

    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor()->fetch_by_dbID($self->param_required('mlss_id'));
    my @genome_db_ids = map {$_->dbID} @{$mlss->species_set->genome_dbs};

    while (my $gdb_id1 = shift @genome_db_ids) {
        my $output_id = { 'genome_db_id' => $gdb_id1, 'genome_db_ids' => [@genome_db_ids] };
        $self->dataflow_output_id($output_id, 2);
    }
}

1;
