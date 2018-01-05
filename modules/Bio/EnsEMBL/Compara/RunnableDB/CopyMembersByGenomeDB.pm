=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a $rows = copy of the License at

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

Bio::EnsEMBL::Compara::RunnableDB::CopyMembersByGenomeDB

=head1 DESCRIPTION

This module imports all the members (and their sequences and hmm-hits) for a given genome_db_id.

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::CopyMembersByGenomeDB;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::CopyData qw(:table_copy);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift;

    my $reuse_dba = $self->get_cached_compara_dba('reuse_db');
    die $self->param('reuse_db').' cannot be found' unless $reuse_dba;
    $self->param('reuse_dba', $reuse_dba);

    $self->param_required('genome_db_id');
}

sub run {
    my $self = shift;

    $self->_copy_data_wrapper('dnafrag', 'SELECT * FROM dnafrag');
    $self->_copy_data_wrapper('gene_member', 'SELECT * FROM gene_member');
    $self->_copy_data_wrapper('sequence', 'SELECT sequence.* FROM seq_member JOIN sequence USING (sequence_id)');
    $self->_copy_data_wrapper('seq_member', 'SELECT * FROM seq_member');
    $self->_copy_data_wrapper('other_member_sequence', 'SELECT other_member_sequence.* FROM seq_member JOIN other_member_sequence USING (seq_member_id)');
    $self->_copy_data_wrapper('exon_boundaries', 'SELECT exon_boundaries.* FROM seq_member JOIN exon_boundaries USING (seq_member_id)');
    $self->_copy_data_wrapper('hmm_annot', 'SELECT hmm_annot.* FROM seq_member JOIN hmm_annot USING (seq_member_id)');
    $self->_copy_data_wrapper('seq_member_projection_stable_id', 'SELECT seq_member_projection_stable_id.* FROM seq_member JOIN seq_member_projection_stable_id ON seq_member_id = target_seq_member_id');
}

sub _copy_data_wrapper {
    my ($self, $table, $input_query, $genome_db_id_prefix) = @_;

    my $genome_db_id    = $self->param('genome_db_id');
    my $from_dbc        = $self->param('reuse_dba')->dbc;
    my $to_dbc          = $self->compara_dba->dbc;

    # We add the genome_db_id filter
    if ($input_query =~ /\bwhere\b/i) {
        $input_query .= ' AND '
    } else {
        $input_query .= ' WHERE '
    }
    $input_query .= ($genome_db_id_prefix // '') . 'genome_db_id = '.$genome_db_id;

    # The extra arguments tell copy_data *not* to disable and enable keys
    # since there is too little data to copy to make it worth
    my $rows = copy_data($from_dbc, $to_dbc, $table, $input_query, undef, 'skip_disable_keys', $self->debug);
    $self->warning("Copied over $rows rows of the $table table for genome_db_id=$genome_db_id");
}

1;
