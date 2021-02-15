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

=head1 NAME

HMMAnnotAdaptor

=head1 AUTHOR

ChuangKee Ong

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded by a _.

=cut

package Bio::EnsEMBL::Compara::DBSQL::HMMAnnotAdaptor;

use strict;
use warnings;

use DBI qw(:sql_types);

use Bio::EnsEMBL::Compara::Utils::CopyData qw(:insert);

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor');


sub fetch_all_hmm_annot {
    my ($self) = @_;

    my $sql = "SELECT seq_member_id, model_id, evalue FROM hmm_annot WHERE model_id IS NOT NULL";
    my $sth = $self->prepare($sql);

return $sth;
}


my $sql_all = 'SELECT seq_member_id FROM seq_member LEFT JOIN hmm_annot USING (seq_member_id) LEFT JOIN seq_member_projection ON seq_member_id = target_seq_member_id WHERE hmm_annot.seq_member_id IS NULL AND target_seq_member_id IS NULL';

sub fetch_all_seqs_missing_annot {
    my ($self, $no_null) = @_;

    return $self->dbc->db_handle->selectcol_arrayref($sql_all . ($no_null ? ' AND model_id IS NOT NULL' : ''));
}


sub fetch_all_seqs_missing_annot_by_range {
    my ($self, $start_member_id, $end_member_id, $no_null) = @_;

    my $sql = $sql_all.' AND seq_member.seq_member_id BETWEEN ? AND ?' . ($no_null ? ' AND model_id IS NOT NULL' : '');
    return $self->dbc->db_handle->selectcol_arrayref($sql, undef, $start_member_id, $end_member_id);
}

sub fetch_all_seqs_in_trees_by_range {
    my ($self, $start_member_id, $end_member_id, $clusterset_id) = @_;

    my $sql = 'SELECT seq_member_id FROM seq_member LEFT JOIN gene_tree_node as gtn USING (seq_member_id) JOIN gene_tree_root USING (root_id) WHERE gtn.seq_member_id IS NOT NULL AND clusterset_id = ? AND seq_member_id BETWEEN ? AND ?';
    return $self->dbc->db_handle->selectcol_arrayref($sql, undef, $clusterset_id, $start_member_id, $end_member_id);
}

sub fetch_all_seqs_under_the_diversity_levels {
    my ($self) = @_;
    return $self->dbc->db_handle->selectcol_arrayref($sql_all);
}


=head2 store_rows

  Arg[1]      : Array-ref of rows to be inserted in the hmm_annot table (each row is itself
                an array-ref)
  Example     : $hmm_annot_adaptor->store_rows(\@bulk_data);
  Description : Store (efficiently) many rows in the hmm_annot table. Each row must have all
                the columns defined (3 at the moment: "seq_member_id", "model_id", "evalue").
                The method uses INSERT IGNORE in order to top up the existing data (assuming
                the data that are there are correct).
  Returntype  : Number of rows inserted
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub store_rows {
    my $self = shift;
    my $all_rows = shift;
    return bulk_insert($self->dbc, 'hmm_annot', $all_rows, ['seq_member_id', 'model_id', 'evalue'], 'INSERT IGNORE');
}

1;
