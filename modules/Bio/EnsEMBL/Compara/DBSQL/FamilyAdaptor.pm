# 
# BioPerl module for Bio::EnsEMBL::Compara::DBSQL::FamilyAdaptor
# 
# Initially cared for by Philip Lijnzaad <lijnzaad@ebi.ac.uk> and Elia Stupka <elia@tll.org.sg>
# Now cared by Abel Ureta-Vidal <abel@ebi.ac.uk>
#
# Copyright EnsEMBL
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

FamilyAdaptor - DESCRIPTION of Object

  This object represents a family coming from a database of protein families.

=head1 SYNOPSIS

  use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

  my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-user   => 'myusername',
						       -dbname => 'myfamily_db',
						       -host   => 'myhost');

  my $fa = $db->get_FamilyAdaptor;
  my $fam = $fa->fetch_by_stable_id('ENSF000013034');

  my $ma = $db->get_MemberAdaptor;
  my $member = $ma->fetch_by_source_stable_id('SWISSPROT', 'YSV4_CAEEL')};
  my @fam = @{$fa->fetch_by_Member($member)};

  @fam = @{$fa->fetch_by_description_with_wildcards('interleukin',1)};
  @fam = @{$fa->fetch_all};

=head1 DESCRIPTION

This module is an entry point into a database of protein families,
clustering SWISSPROT/TREMBL and ensembl protein sets using the TRIBE MCL algorithm.
The clustering neatly follows the SWISSPROT DE-lines, which are 
taken as the description of the whole family.

The objects can be read from and write to a family database.

For more info, see ensembl-doc/family.txt

=head1 CONTACT

 Able Ureta-Vidal <abel@ebi.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::FamilyAdaptor;

use strict;
use Bio::EnsEMBL::Compara::Family;
use Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor;

our @ISA = qw(Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor);

=head2 fetch_by_Member

 Arg [1]    : Bio::EnsEMBL::Compara::Member $member
 Example    : $families = $FamilyAdaptor->fetch_by_Member($member);
 Description: find the families to which the given member belongs to
 Returntype : an array reference of Bio::EnsEMBL::Compara::Family objects
              (could be empty or contain more than one Family in the case of ENSEMBLGENE only)
 Exceptions : when missing arguments
 Caller     : general

=cut

sub fetch_by_Member {
  my ($self, $member) = @_;

  unless ($member->isa('Bio::EnsEMBL::Compara::Member')) {
    $self->throw("The argument must be a Bio::EnsEMBL::Compara::Member object, not $member");
  }

  my $join = [[['family_member', 'fm'], 'f.family_id = fm.family_id']];
  my $constraint = "fm.member_id = ". $member->dbID;

  return $self->generic_fetch($constraint, $join);
}

sub fetch_by_Member_source_stable_id {
  my ($self, $source_name, $member_stable_id) = @_;

  unless (defined $source_name && defined $member_stable_id) {
    $self->throw("The source_name and member_stable_id arguments must be defined");
  }

  my $join = [[['family_member', 'fm'], 'f.family_id = fm.family_id'],
              [['member', 'm'], 'fm.member_id = m.member_id'],
              [['source', 'ms'], 'm.source_id = ms.source_id']];
  my $constraint = "m.stable_id = '$member_stable_id' AND ms.source_name = '$source_name'";

  return $self->generic_fetch($constraint, $join);
}

# maybe a useful method in case more than one kind of family data is stored in the db.

sub fetch_by_Member_Family_source {
  my ($self, $member, $source_name) = @_;

  unless ($member->isa('Bio::EnsEMBL::Compara::Member')) {
    $self->throw("The argument must be a Bio::EnsEMBL::Compara::Member object, not $member");
  }

  $self->throw("source_name arg is required\n")
    unless ($source_name);

  my $join = [[['family_member', 'fm'], 'f.family_id = fm.family_id']];
  my $constraint = "s.source_name = '$source_name'";
  $constraint .= " AND fm.member_id = " . $member->dbID;

  return $self->generic_fetch($constraint, $join);
}

=head2 fetch_by_description_with_wildcards

 Arg [1]    : string $description
 Arg [2]    : int $wildcard (optional)
              if set to 1, wildcards are added and the search is a slower LIKE search
 Example    : $fams = $FamilyAdaptor->fetch_by_description_with_wildcards('REDUCTASE',1);
 Description: simplistic substring searching on the description to get the families
              matching the description. (The search is currently case-insensitive;
              this may change if SPTR changes to case-preservation)
 Returntype : an array reference of Bio::EnsEMBL::Compara::Family objects
 Exceptions : none
 Caller     : general

=cut

sub fetch_by_description_with_wildcards{ 
    my ($self,$desc,$wildcard) = @_; 

    my $constraint;

    if ($wildcard) {
      $constraint = "f.description LIKE '"."%"."\U$desc"."%"."'";
    }
    else {
      $constraint = "f.description = '$desc'";
    }

    return $self->generic_fetch($constraint);
}


#
# INTERNAL METHODS
#
###################

#internal method used in multiple calls above to build family objects from table data  

sub _tables {
  my $self = shift;

  return (['family', 'f'], ['source', 's']);
}

sub _columns {
  my $self = shift;

  return qw (f.family_id
             f.stable_id
             f.description
             f.description_score
             s.source_id
             s.source_name);
}

sub _objs_from_sth {
  my ($self, $sth) = @_;
  
  my ($family_id, $stable_id, $description, $description_score, $source_id, $source_name);

  $sth->bind_columns(\$family_id, \$stable_id, \$description, \$description_score,
                     \$source_id, \$source_name);

  my @families = ();
  
  while ($sth->fetch()) {
    push @families, Bio::EnsEMBL::Compara::Family->new_fast
      ({'_dbID' => $family_id,
       '_stable_id' => $stable_id,
       '_description' => $description,
       '_description_score' => $description_score,
       '_source_id' => $source_id,
       '_source_name' => $source_name,
       '_adaptor' => $self});
  }
  
  return \@families;  
}

sub _default_where_clause {
  my $self = shift;

  return 'f.source_id = s.source_id';
}

#
# STORE METHODS
#
################

=head2 store

 Arg [1]    : Bio::EnsEMBL::ExternalData:Family::Family $fam
 Example    : $FamilyAdaptor->store($fam)
 Description: Stores a family object into a family  database
 Returntype : int 
              been the database family identifier, if family stored correctly
 Exceptions : when isa if Arg [1] is not Bio::EnsEMBL::Compara::Family
 Caller     : general

=cut

sub store {
  my ($self,$fam) = @_;

  $fam->isa('Bio::EnsEMBL::Compara::Family') ||
    $self->throw("You have to store a Bio::EnsEMBL::Compara::Family object, not a $fam");

  my $sql = "SELECT family_id from family where stable_id = ?";
  my $sth = $self->prepare($sql);
  $sth->execute($fam->stable_id);
  my $rowhash = $sth->fetchrow_hashref;

  $fam->source_id($self->store_source($fam->source_name));

  if ($rowhash->{family_id}) {
    $fam->dbID($rowhash->{family_id});
  } else {
  
    $sql = "INSERT INTO family (stable_id, source_id, description, description_score) VALUES (?,?,?,?)";
    $sth = $self->prepare($sql);
    $sth->execute($fam->stable_id,$fam->source_id,$fam->description,$fam->description_score);
    $fam->dbID($sth->{'mysql_insertid'});
  }

  foreach my $member_attribue (@{$fam->get_all_Member}) {   
    $self->store_relation($member_attribue, $fam);
  }

  return $fam->dbID;
}

1;
