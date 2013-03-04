
package Bio::EnsEMBL::Compara::DBSQL::GeneAlignAdaptor;

use strict;
use Bio::EnsEMBL::Compara::AlignedMemberSet;
use Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor;

use Bio::EnsEMBL::Utils::Scalar qw(:assert);

use DBI qw(:sql_types);

our @ISA = qw(Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor);


=head2 fetch_all_by_SeqMember

 Arg [1]    : Bio::EnsEMBL::Compara::SeqMember $member
 Example    : $alignments = $GeneAlignAdaptor->fetch_all_by_SeqMember($member);
 Description: find the alignments to which the given member belongs to
 Returntype : an array reference of Bio::EnsEMBL::Compara::GeneAlign objects
              (could be empty or contain more than one GeneAlign in the case of ENSEMBLGENE only)
 Exceptions : when missing arguments
 Caller     : general

=cut

sub fetch_all_by_SeqMember {
  my ($self, $member) = @_;

  assert_ref($member, 'Bio::EnsEMBL::Compara::SeqMember');

  my $join = [[['gene_align_member', 'gam'], 'ga.gene_align_id = gam.gene_align_id']];
  my $constraint = 'gam.member_id = ?';

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
  
  my ($gene_align_id, $seq_type, $aln_method, $aln_length);

  $sth->bind_columns(\$gene_align_id, \$seq_type, \$aln_method, \$aln_length);

  my @alignments = ();
  
  while ($sth->fetch()) {
    push @alignments, Bio::EnsEMBL::Compara::AlignedMemberSet->new_fast({
            '_adaptor'          => $self,       # field name NOT in sync with Bio::EnsEMBL::Storable
            '_dbID'             => $gene_align_id,
            '_aln_method'       => $aln_method,
            '_aln_length'       => $aln_length,
            '_seq_type'         => $seq_type,
       });
  }
  
  return \@alignments;  
}

#
# Store an AlignedMemberSet
##############################

=head2 store

 Arg [1]    : Bio::EnsEMBL::Compara::AlignedMemberSet $aln
 Example    : $AlignedMemberAdaptor->store($fam)
 Description: Stores an AlignedMemberSet object into a Compara database
 Returntype : none
 Exceptions : when isa if Arg [1] is not Bio::EnsEMBL::Compara::AlignedMemberSet
 Caller     : general

=cut

sub store {
    my ($self, $aln) = @_;
    assert_ref($aln, 'Bio::EnsEMBL::Compara::AlignedMemberSet');
  
    # dbID for GeneTree is too dodgy
    my $id = $aln->isa('Bio::EnsEMBL::Compara::GeneTree') ? $aln->gene_align_id() : $aln->dbID();

    if ($id) {
        my $sth = $self->prepare('UPDATE gene_align SET seq_type = ?, aln_length = ?, aln_method = ? WHERE gene_align_id = ?');
        $sth->execute($aln->seq_type, $aln->aln_length, $aln->aln_method, $id);
    } else {
        my $sth = $self->prepare('INSERT INTO gene_align (seq_type, aln_length, aln_method) VALUES (?,?,?)');
        $sth->execute($aln->seq_type, $aln->aln_length, $aln->aln_method);
        $id = $sth->{'mysql_insertid'};

        if ($aln->isa('Bio::EnsEMBL::Compara::GeneTree')) {
            $aln->gene_align_id($id);
        } else {
            $aln->dbID($id);
        }
    }
 
    my $sth = $self->prepare('REPLACE INTO gene_align_member (gene_align_id, member_id, cigar_line) VALUES (?,?,?)');

    foreach my $member (@{$aln->get_all_Members}) {
        $sth->execute($id, $member->member_id, $member->cigar_line) if $member->cigar_line;
    }

    $sth->finish;

    # let's store the link between gene_tree_root and gene_align
    if ($aln->isa('Bio::EnsEMBL::Compara::GeneTree') and defined $aln->root_id) {
        $sth = $self->prepare('UPDATE gene_tree_root SET gene_align_id = ? WHERE root_id = ?');
        $sth->execute($aln->gene_align_id,  $aln->root_id);
        $sth->finish;
    }

}



1;
