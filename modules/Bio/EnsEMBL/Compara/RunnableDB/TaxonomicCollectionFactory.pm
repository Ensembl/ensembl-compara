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

Bio::EnsEMBL::Compara::RunnableDB::TaxonomicCollectionFactory

=head1 DESCRIPTION

Gather collection directory by appropriate taxonomic selection

=head1 SYNOPSIS

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::TaxonomicCollectionFactory /
        --compara_db "mysql://ensro@mysql-ens-compara-prod-1:4485/ensembl_compara_master" /
        --rr_ref_db  "mysql://ensro@mysql-ens-sta-5:4684/ensembl_compara_references" /
        --shared_file_dir /hps/nobackup/flicek/ensembl/compara/shared/symlink_references
        --species_list Balaenoptera musculus

=over

=item rr_ref_db

Mandatory. Rapid release Compara reference database. Can be an alias or an URL.

=item shared_file_dir

Mandatory. Requires precomputed OrthoFinder results file or file of comparator fasta files.

=item species_list

Mandatory. Query species name list.

=item compara_db

Mandatory. Compara database URL.

=back

=cut

package Bio::EnsEMBL::Compara::RunnableDB::TaxonomicCollectionFactory;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::GenomeDB;

use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub write_output {
    my $self = shift;

    my $ref_master  = $self->param_required('rr_ref_db');
    my $species     = $self->param_required('species_list');
    my $shared_dir  = $self->param_required('shared_file_dir');
    my $gdb_adaptor = $self->compara_dba->get_GenomeDBAdaptor;

    foreach my $species_name (@$species) {
        my $genome_db      = $gdb_adaptor->fetch_by_name_assembly($species_name);
        my $genome_db_id   = $genome_db->dbID;
        my $genome_fasta   = $genome_db->_get_members_dump_path($self->param_required('members_dumps_dir'));
        my $collection_dir = $shared_dir . '/' . match_query_to_reference_taxonomy($genome_db, $ref_master);
        $self->param('fasta_file' => $genome_fasta);
        $self->param('collection_dir' => $collection_dir);
        $self->dataflow_output_id( {'species_name' => 'fasta_file' => $self->param('fasta_file'), 'collection_dir' => $self->param('collection_dir')}, 1 );
    }

}

1;
