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


package Bio::EnsEMBL::Compara::DBSQL::GeneAlignAdaptor;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::AlignedMemberSet;

use Bio::EnsEMBL::Utils::Scalar qw(:assert);

use Bio::EnsEMBL::Compara::Utils::Scalar qw(:assert);

use DBI qw(:sql_types);

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor');

=head2 fetch_all_by_SeqMember

 Arg [1]    : Bio::EnsEMBL::Compara::SeqMember $member
 Example    : $alignments = $GeneAlignAdaptor->fetch_all_by_SeqMember($member);
 Description: find the alignments to which the given member belongs to
 Returntype : an array reference of Bio::EnsEMBL::Compara::GeneAlign objects
 Exceptions : when missing arguments
 Caller     : general

=cut

sub fetch_all_by_SeqMember {
  my ($self, $member) = @_;

  assert_ref($member, 'Bio::EnsEMBL::Compara::SeqMember', 'member');

  my $join = [[['gene_align_member', 'gam'], 'ga.gene_align_id = gam.gene_align_id']];
  my $constraint = 'gam.seq_member_id = ?';

  $self->bind_param_generic_fetch($member->dbID, SQL_INTEGER);
  return $self->generic_fetch($constraint, $join);
}



#
# INTERNAL METHODS
#
###################

#internal method used in multiple calls above to build gene_align objects from table data  

sub _tables {
  return (['gene_align', 'ga']);
}

sub _columns {
  return qw (ga.gene_align_id
             ga.seq_type
             ga.aln_method
             ga.aln_length);
}

sub _objs_from_sth {
    my ($self, $sth) = @_;

    return $self->generic_objs_from_sth($sth, 'Bio::EnsEMBL::Compara::AlignedMemberSet', [
            'dbID',
            '_seq_type',
            '_aln_method',
            '_aln_length',
        ] );
}

#
# Store an AlignedMemberSet
##############################

=head2 store

 Arg [1]    : Bio::EnsEMBL::Compara::AlignedMemberSet $aln
 Arg [2]    : Boolean $force_new_alignment: whether to force a new gene_align entry to be created
 Example    : $AlignedMemberAdaptor->store($fam)
 Description: Stores an AlignedMemberSet object into a Compara database
 Returntype : none
 Exceptions : when isa if Arg [1] is not Bio::EnsEMBL::Compara::AlignedMemberSet
 Caller     : general

=cut

sub store {
    my ($self, $aln, $force_new_alignment) = @_;
    assert_ref($aln, 'Bio::EnsEMBL::Compara::AlignedMemberSet', 'aln');
  
    # dbID for GeneTree is too dodgy, so we need to use gene_align_id
    my $id = $aln->isa('Bio::EnsEMBL::Compara::GeneTree') ? $aln->gene_align_id() : $aln->dbID();

    if ($id and not $force_new_alignment) {
        my $sth = $self->prepare('UPDATE gene_align SET seq_type = ?, aln_length = ?, aln_method = ? WHERE gene_align_id = ?');
        $sth->execute($aln->seq_type, $aln->aln_length, $aln->aln_method, $id);

        # We need to remove the gene_align_member entries that are not in the aligment any more
        my $all_ids = $self->dbc->db_handle->selectall_arrayref('SELECT seq_member_id FROM gene_align_member WHERE gene_align_id = ?', undef, $id);
        my %hash_ids_in_db = map {$_->[0] => 1} @$all_ids;
        foreach my $member (@{$aln->get_all_Members}) {
            delete $hash_ids_in_db{$member->seq_member_id};
        }
        $sth = $self->prepare('DELETE FROM gene_align_member WHERE gene_align_id = ? AND seq_member_id = ?');
        foreach my $seq_member_id (keys %hash_ids_in_db) {
            $sth->execute($id, $seq_member_id);
        }

    } else {
        my $sth = $self->prepare('INSERT INTO gene_align (seq_type, aln_length, aln_method) VALUES (?,?,?)');
        $sth->execute($aln->seq_type, $aln->aln_length, $aln->aln_method);
        $id = $self->dbc->db_handle->last_insert_id(undef, undef, 'gene_align', 'gene_align_id');

        if ($aln->isa('Bio::EnsEMBL::Compara::GeneTree')) {
            $aln->gene_align_id($id);
        } else {
            $aln->dbID($id);
        }
    }
 
    my $sth = $self->prepare('REPLACE INTO gene_align_member (gene_align_id, seq_member_id, cigar_line) VALUES (?,?,?)');

    foreach my $member (@{$aln->get_all_Members}) {
        $sth->execute($id, $member->seq_member_id, $member->cigar_line) if $member->cigar_line;
    }

    $sth->finish;

    # let's store the link between gene_tree_root and gene_align
    if ($aln->isa('Bio::EnsEMBL::Compara::GeneTree') and defined $aln->root_id) {
        $sth = $self->prepare('UPDATE gene_tree_root SET gene_align_id = ? WHERE root_id = ?');
        $sth->execute($aln->gene_align_id,  $aln->root_id);
        $sth->finish;
    }

}


=head2 delete

 Arg [1]    : Bio::EnsEMBL::Compara::AlignedMemberSet $aln
 Example    : $AlignedMemberAdaptor->delete($aln)
 Description: Deletes an AlignedMemberSet object from a Compara database
 Returntype : none
 Exceptions : none
 Caller     : general

=cut

sub delete {
    my ($self, $aln) = @_;

    assert_ref_or_dbID($aln, 'Bio::EnsEMBL::Compara::AlignedMemberSet', 'aln');
    my $dbID = ref($aln) ? $aln->dbID : $aln;
    $self->dbc->do('DELETE FROM gene_align_member WHERE gene_align_id = ?', undef, $dbID);
    $self->dbc->do('DELETE FROM gene_align        WHERE gene_align_id = ?', undef, $dbID);
}

1;
