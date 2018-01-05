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

=head1 NAME

FamilyAdaptor - This object represents a family coming from a database of protein families.

=head1 SYNOPSIS

  my $fa = Bio::EnsEMBL::Registry->get_adaptor('Multi', 'Compara', 'Family');
  my $ma = Bio::EnsEMBL::Registry->get_adaptor('Multi', 'Compara', 'SeqMember');

  my $fam = $fa->fetch_by_stable_id('ENSF000013034');
  my $member = $ma->fetch_by_stable_id('YSV4_CAEEL')};   # This is UniProt accession symbol
  my $fam = $fa->fetch_by_SeqMember($member);

  @fam = @{$fa->fetch_by_description_with_wildcards('interleukin',1)};

=head1 DESCRIPTION

This module is an entry point into a database of protein families,
clustering SWISSPROT/TREMBL and ensembl protein sets using the TRIBE MCL algorithm.
The clustering neatly follows the SWISSPROT DE-lines, which are 
taken as the description of the whole family.

The objects can be read from and write to a family database.

For more info, see ensembl-doc/family.txt

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::FamilyAdaptor;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Family;
use Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor;

use Bio::EnsEMBL::Utils::Scalar qw(:assert :check);
use Bio::EnsEMBL::Utils::Exception qw(throw warning deprecate);

use DBI qw(:sql_types);

our @ISA = qw(Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor);


=head2 fetch_all_by_GeneMember

 Arg [1]    : Bio::EnsEMBL::Compara::GeneMember $member
 Example    : $families = $FamilyAdaptor->fetch_all_by_GeneMember($member);
 Description: find the families to which the given member belongs to
 Returntype : an array reference of Bio::EnsEMBL::Compara::Family objects
 Exceptions : when missing arguments
 Caller     : general

=cut

sub fetch_all_by_GeneMember {
  my ($self, $gene_member) = @_;

  assert_ref($gene_member, 'Bio::EnsEMBL::Compara::GeneMember', 'gene_member');

  my $join = [[['family_member', 'fm'], 'f.family_id = fm.family_id'], [['seq_member', 'sm'], 'fm.seq_member_id = sm.seq_member_id'] ];
  my $constraint = 'sm.gene_member_id = ?';

  $self->bind_param_generic_fetch($gene_member->dbID, SQL_INTEGER);
  return $self->generic_fetch($constraint, $join, 'GROUP BY fm.family_id');
}


=head2 fetch_all_by_Gene

 Arg [1]    : Bio::EnsEMBL::Gene $gene
 Example    : $families = $FamilyAdaptor->fetch_all_by_Gene($gene);
 Description: find the families to which the given gene belongs to
 Returntype : an array reference of Bio::EnsEMBL::Compara::Family objects
 Exceptions : when missing arguments
 Caller     : general

=cut

sub fetch_all_by_Gene {
    my ($self, $gene) = @_;

    assert_ref($gene, 'Bio::EnsEMBL::Gene', 'gene');
    my $gene_member = $self->db->get_GeneMemberAdaptor->fetch_by_Gene($gene, 1);
    return $gene_member ? $self->fetch_all_by_GeneMember($gene_member) : [];
}


=head2 fetch_by_SeqMember

 Arg [1]    : Bio::EnsEMBL::Compara::SeqMember $member
 Example    : $family = $FamilyAdaptor->fetch_by_SeqMember($member);
 Description: find the family to which the given member belongs to
 Returntype : Bio::EnsEMBL::Compara::Family or undef
 Exceptions : when missing arguments
 Caller     : general

=cut

sub fetch_by_SeqMember {
  my ($self, $seq_member) = @_;

  assert_ref($seq_member, 'Bio::EnsEMBL::Compara::SeqMember', 'seq_member');

  my $join = [[['family_member', 'fm'], 'f.family_id = fm.family_id']];
  my $constraint = 'fm.seq_member_id = ?';

  $self->bind_param_generic_fetch($seq_member->dbID, SQL_INTEGER);
  return $self->generic_fetch_one($constraint, $join);
}


=head2 fetch_by_Translation

 Arg [1]    : Bio::EnsEMBL::Translation $translation
 Example    : $family = $FamilyAdaptor->fetch_by_Translation($translation);
 Description: find the family to which the given peptide belongs to
 Returntype : Bio::EnsEMBL::Compara::Family or undef
 Exceptions : when missing arguments
 Caller     : general

=cut

sub fetch_by_Translation {
    my ($self, $translation) = @_;

    assert_ref($translation, 'Bio::EnsEMBL::Translation', 'translation');
    my $seq_member = $self->db->get_SeqMemberAdaptor->fetch_by_Translation($translation, 1);
    return $seq_member ? $self->fetch_by_SeqMember($seq_member) : undef;
}


=head2 fetch_by_stable_id

  Arg [1]    : string $stable_id
               the unique database identifier for the Family to be obtained
  Example    : $family = $adaptor->fetch_by_stable_id('ENSFM00300000084926')
  Description: Returns the Family created from the database and defined by the
               the stable id $stable_id.
  Returntype : Bio::EnsEMBL::Compara::Family
  Exceptions : thrown if $stable_id is not defined
  Caller     : general

=cut

sub fetch_by_stable_id {
    my ($self, $stable_id) = @_;

    unless(defined $stable_id) {
        $self->throw("fetch_by_stable_id must have an stable_id");
    }

    my $constraint = 'f.stable_id = ?';

    $self->bind_param_generic_fetch($stable_id, SQL_VARCHAR);

    return $self->generic_fetch_one($constraint)
}


=head2 fetch_by_description_with_wildcards

 Arg [1]    : string $description
 Arg [2]    : int $wildcard (optional)
              if set to 1, wildcards are added and the search is a slower LIKE search
 Example    : $fams = $FamilyAdaptor->fetch_by_description_with_wildcards('REDUCTASE',1);
 Description: simplistic substring searching on the description to get the families
              matching the description. The search is currently case-insensitive.
 Returntype : an array reference of Bio::EnsEMBL::Compara::Family objects
 Exceptions : none
 Caller     : general

=cut

sub fetch_by_description_with_wildcards{ 
    my ($self,$desc,$wildcard) = @_; 

    my $constraint;

    if ($wildcard) {
      $constraint = 'f.description LIKE ?';
      $self->bind_param_generic_fetch(sprintf('%%%s%%',$desc), SQL_VARCHAR);
    }
    else {
      $constraint = 'f.description = ?';
      $self->bind_param_generic_fetch($desc, SQL_VARCHAR);
    }

    return $self->generic_fetch($constraint);
}


#
# INTERNAL METHODS
#
###################

#internal method used in multiple calls above to build family objects from table data  

sub _tables {
  return (['family', 'f']);
}

sub _columns {
  return qw (f.family_id
             f.stable_id
             f.version
             f.method_link_species_set_id
             f.description
             f.description_score);
}

sub _objs_from_sth {
    my ($self, $sth) = @_;
  
    return $self->generic_objs_from_sth($sth, 'Bio::EnsEMBL::Compara::Family', [
            'dbID',
            '_stable_id',
            '_version',
            '_method_link_species_set_id',
            '_description',
            '_description_score',
        ] );
}


#
# STORE METHODS
#
################

=head2 store

 Arg [1]    : Bio::EnsEMBL::Compara::Family $fam
 Example    : $FamilyAdaptor->store($fam)
 Description: Stores a family object into a family  database
 Returntype : int 
              been the database family identifier, if family stored correctly
 Exceptions : when isa if Arg [1] is not Bio::EnsEMBL::Compara::Family
 Caller     : general

=cut

sub store {
  my ($self,$fam) = @_;

  assert_ref($fam, 'Bio::EnsEMBL::Compara::Family', 'fam');

  $fam->adaptor($self);

  if ( !defined $fam->method_link_species_set_id && defined $fam->method_link_species_set) {
    $self->db->get_MethodLinkSpeciesSetAdaptor->store($fam->method_link_species_set);
  }

  if (! defined $fam->method_link_species_set) {
    throw("Family object has no set MethodLinkSpecies object. Can not store Family object\n");
  } else {
    $fam->method_link_species_set_id($fam->method_link_species_set->dbID);
  }

  my $sql = "SELECT family_id from family where stable_id = ?";
  my $sth = $self->prepare($sql);
  $sth->execute($fam->stable_id);
  my $rowhash = $sth->fetchrow_hashref;

  if ($rowhash->{family_id}) {
    $fam->dbID($rowhash->{family_id});
  } else {
  
    $sql = "INSERT INTO family (stable_id, version, method_link_species_set_id, description, description_score) VALUES (?,?,?,?,?)";
    $sth = $self->prepare($sql);
    $sth->execute($fam->stable_id, $fam->version, $fam->method_link_species_set_id, $fam->description, $fam->description_score);
    $fam->dbID( $self->dbc->db_handle->last_insert_id(undef, undef, 'family', 'family_id') );
  }

  $sql = "INSERT IGNORE INTO family_member (family_id, seq_member_id, cigar_line) VALUES (?,?,?)";
  $sth = $self->prepare($sql);
  foreach my $member (@{$fam->get_all_Members}) {   
    # Stores the member if not yet stored
    unless (defined $member->dbID) {
        $self->db->get_SeqMemberAdaptor->store($member);
    }
    $sth->execute($member->set->dbID, $member->dbID, $member->cigar_line);
  }

  return $fam->dbID;
}


sub update {
  my ($self, $fam, $content_only) = @_;

  assert_ref($fam, 'Bio::EnsEMBL::Compara::Family', 'fam');

  unless ($content_only) {
    my $sql = 'UPDATE family SET stable_id = ?, version = ?, method_link_species_set_id = ?, description = ?, description_score = ? WHERE family_id = ?';
    my $sth = $self->prepare($sql);
    $sth->execute($fam->stable_id, $fam->version, $fam->method_link_species_set_id, $fam->description, $fam->description_score, $fam->dbID);
  }

  my $sql = 'UPDATE family_member SET cigar_line = ? WHERE family_id = ? AND seq_member_id = ?';
  my $sth = $self->prepare($sql);
  foreach my $member (@{$fam->get_all_Members}) {   
    $sth->execute($member->cigar_line, $member->set->dbID, $member->dbID);
  }
}


1;
