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

Bio::EnsEMBL::Compara::DBSQL::AlignedMemberAdaptor

=head1 DESCRIPTION

Adaptor to fetch AlignedMember objects, grouped within a multiple
alignment.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::DBSQL::AlignedMemberAdaptor
  `- Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::DBSQL::AlignedMemberAdaptor;

use strict; 
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Scalar qw(:assert);

use Bio::EnsEMBL::Compara::AlignedMember;
use Bio::EnsEMBL::Compara::DBSQL::SeqMemberAdaptor;
use DBI qw(:sql_types);

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor');

#
# FETCH methods
###########################

=head2 fetch_all_by_AlignedMemberSet

  Arg[1]     : AlignedMemberSet $set: Currently, Family, Homology and GeneTree
                are supported
  Example    : $family_members = $am_adaptor->fetch_all_by_AlignedMemberSet($family);
  Description: Fetches from the database all the aligned members (members with
                an alignment string)
  Returntype : arrayref of Bio::EnsEMBL::Compara::AlignedMember
  Exceptions : none
  Caller     : general

=cut

sub fetch_all_by_AlignedMemberSet {
    my ($self, $set) = @_;
    assert_ref($set, 'Bio::EnsEMBL::Compara::AlignedMemberSet', 'set');

    if (UNIVERSAL::isa($set, 'Bio::EnsEMBL::Compara::Homology')) {
        return $self->fetch_all_by_Homology($set);
    } elsif (UNIVERSAL::isa($set, 'Bio::EnsEMBL::Compara::Family')) {
        return $self->fetch_all_by_Family($set);
    } elsif (UNIVERSAL::isa($set, 'Bio::EnsEMBL::Compara::GeneTree')) {
        return $self->fetch_all_by_GeneTree($set);
    } else {
        return $self->fetch_all_by_gene_align_id($set->dbID);
    }
}

=head2 fetch_all_by_Homology

  Arg[1..n]  : Homology $homology
  Example    : $hom_members = $am_adaptor->fetch_all_by_Homology($homology);
  Description: Fetches from the database the two aligned members related to
                this Homology object. Note: the method actually accepts any number of Homology
  Returntype : arrayref of Bio::EnsEMBL::Compara::AlignedMember
  Exceptions : none
  Caller     : general

=cut

sub fetch_all_by_Homology {
    my $self = shift;
    assert_ref($_, 'Bio::EnsEMBL::Compara::Homology', 'homology') for @_;
    throw("At least 1 argument is expected in AlignedMemberAdaptor::fetch_all_by_Homology()") unless scalar(@_);

    my $extra_columns = ['hm.cigar_line', 'hm.perc_cov', 'hm.perc_id', 'hm.perc_pos', 'hm.homology_id'];
    my $join = [[['homology_member', 'hm'], 'm.seq_member_id = hm.seq_member_id', $extra_columns]];
    return $self->generic_fetch_concatenate([map {$_->dbID} @_], 'hm.homology_id', SQL_INTEGER, $join);
}

=head2 fetch_all_by_Family

  Arg[1]     : Family $family
  Example    : $family_members = $am_adaptor->fetch_all_by_Family($family);
  Description: Fetches from the database all the aligned members of that family.
  Returntype : arrayref of Bio::EnsEMBL::Compara::AlignedMember
  Exceptions : none
  Caller     : general

=cut

sub fetch_all_by_Family {
    my ($self, $family) = @_;
    assert_ref($family, 'Bio::EnsEMBL::Compara::Family', 'family');

    my $extra_columns = ['fm.cigar_line'];
    my $join = [[['family_member', 'fm'], 'm.seq_member_id = fm.seq_member_id', $extra_columns]];
    my $constraint = 'fm.family_id = ?';
    my $final_clause = 'ORDER BY m.source_name';

    $self->bind_param_generic_fetch($family->dbID, SQL_INTEGER);
    return $self->generic_fetch($constraint, $join, $final_clause);
}

=head2 fetch_all_by_GeneTree

  Arg[1]     : GeneTree $tree
  Example    : $tree_members = $am_adaptor->fetch_all_by_GeneTree($tree);
  Description: Fetches from the database all the leaves of the tree, with respect
                to their multiple alignment
  Returntype : arrayref of Bio::EnsEMBL::Compara::AlignedMember
  Exceptions : none
  Caller     : general

=cut

sub fetch_all_by_GeneTree {
    my ($self, $tree) = @_;
    assert_ref($tree, 'Bio::EnsEMBL::Compara::GeneTree', 'tree');

    return $self->fetch_all_by_gene_align_id($tree->gene_align_id);
}


=head2 fetch_all_by_gene_align_id

  Arg[1]     : integer $id
  Example    : $aln_members = $am_adaptor->fetch_all_by_gene_align_id($id);
  Description: Fetches from the database all the members of an alignment,
                based on its dbID
  Returntype : arrayref of Bio::EnsEMBL::Compara::AlignedMember
  Exceptions : none
  Caller     : general

=cut

sub fetch_all_by_gene_align_id {
    my ($self, $id) = @_;

    my $extra_columns = ['gam.cigar_line'];
    my $join = [[['gene_align_member', 'gam'], 'm.seq_member_id = gam.seq_member_id', $extra_columns]];
    my $constraint = 'gam.gene_align_id = ?';

    $self->bind_param_generic_fetch($id, SQL_INTEGER);
    return $self->generic_fetch($constraint, $join);
}


#
# Redirections to MemberAdaptor
################################

sub _tables {
    return Bio::EnsEMBL::Compara::DBSQL::SeqMemberAdaptor::_tables();
}

sub _columns {
    return Bio::EnsEMBL::Compara::DBSQL::SeqMemberAdaptor::_columns();
}

sub _objs_from_sth {
    my ($self, $sth) = @_;

    my @members = ();

    while(my $rowhash = $sth->fetchrow_hashref) {
        my $member = Bio::EnsEMBL::Compara::AlignedMember->new;
        $member = Bio::EnsEMBL::Compara::DBSQL::SeqMemberAdaptor::init_instance_from_rowhash($self, $member, $rowhash);
        foreach my $attr (qw(cigar_line cigar_start cigar_end perc_cov perc_id perc_pos)) {
            $member->$attr($rowhash->{$attr}) if defined $rowhash->{$attr};
        }
        foreach my $attr (qw(homology_id)) {
            $member->{"_member_of_$attr"} = $rowhash->{$attr} if defined $rowhash->{$attr};
        }
        push @members, $member;
    }
    $sth->finish;
    return \@members
}


1;

