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
  my $member = $ma->fetch_by_source_stable_id('Uniprot/SWISSPROT', 'YSV4_CAEEL')};
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

  DEPRECATED: use fetch_all_by_Member instead

=cut

sub fetch_by_Member {
  my ($self, @args) = @_;
  return $self->fetch_all_by_Member(@args);
}


=head2 fetch_all_by_Member

 Arg [1]    : Bio::EnsEMBL::Compara::Member $member
 Example    : $families = $FamilyAdaptor->fetch_by_Member($member);
 Description: find the families to which the given member belongs to
 Returntype : an array reference of Bio::EnsEMBL::Compara::Family objects
              (could be empty or contain more than one Family in the case of ENSEMBLGENE only)
 Exceptions : when missing arguments
 Caller     : general

=cut

sub fetch_all_by_Member {
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
              [['member', 'm'], 'fm.member_id = m.member_id']];

  my $constraint = "m.stable_id = '$member_stable_id' AND m.source_name = '$source_name'";

  return $self->generic_fetch($constraint, $join);
}

# maybe a useful method in case more than one kind of family data is stored in the db.


sub fetch_all_by_Member_method_link_type {
  my ($self, $member, $method_link_type) = @_;

  unless ($member->isa('Bio::EnsEMBL::Compara::Member')) {
    $self->throw("The argument must be a Bio::EnsEMBL::Compara::Member object, not $member");
  }

  $self->throw("method_link_type arg is required\n")
    unless ($method_link_type);
  
  my $mlssa = $self->db->get_MethodLinkSpeciesSetAdaptor;
  my $mlss_arrayref = $mlssa->fetch_all_by_method_link_type_GenomeDB($method_link_type,$member->genome_db);
  
  unless (scalar @{$mlss_arrayref}) {
    warning("There is no $method_link_type data stored in the database for " . $member->genome_db->name . "\n");
    return [];
  }
  
  my $join = [[['family_member', 'fm'], 'f.family_id = fm.family_id']];
  
  my $constraint =  " f.method_link_species_set_id in (". join (",", (map {$_->dbID} @{$mlss_arrayref})) . ")";

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

  return (['family', 'f']);
}

sub _columns {
  my $self = shift;

  return qw (f.family_id
             f.stable_id
             f.version
             f.method_link_species_set_id
             f.description
             f.description_score);
}

sub _objs_from_sth {
  my ($self, $sth) = @_;
  
  my ($family_id, $stable_id, $version, $method_link_species_set_id, $description, $description_score);

  $sth->bind_columns(\$family_id, \$stable_id, \$version, \$method_link_species_set_id, \$description, \$description_score);

  my @families = ();
  
  while ($sth->fetch()) {
    push @families, Bio::EnsEMBL::Compara::Family->new_fast
      ({'_dbID'                      => $family_id,
       '_stable_id'                  => $stable_id,
       '_version'                    => $version,
       '_description'                => $description,
       '_description_score'          => $description_score,
       '_method_link_species_set_id' => $method_link_species_set_id,
       '_adaptor'                    => $self});
  }
  
  return \@families;  
}

sub _default_where_clause {
  my $self = shift;
  return '';
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
    $fam->dbID($sth->{'mysql_insertid'});
  }

  foreach my $member_attribue (@{$fam->get_all_Member_Attribute}) {   
    $self->store_relation($member_attribue, $fam);
  }

  return $fam->dbID;
}

sub fetch_by_Member_Family_source {
  my ($self, $member, $source_name) = @_;
  deprecate("fetch_by_Member_Family_source method is deprecated. Calling 
fetch_all_by_Member_method_link_type instead");
  return $self->fetch_all_by_Member_method_link_type($member, $source_name);
}


sub store_family_member {
  my ($self, $member_attribute) = @_;

  my ($member, $attribute) = @{$member_attribute};
  unless (defined $member->dbID) {
    $self->db->get_MemberAdaptor->store($member);
  }
  $attribute->member_id($member->dbID);
  #$attribute->family_id($relation->dbID);
  my $sql = "INSERT IGNORE INTO family_member (family_id, member_id, cigar_line) VALUES (?,?,?)";
  my $sth = $self->prepare($sql);
  $sth->execute($attribute->family_id, $attribute->member_id, $attribute->cigar_line);
  $sth->finish;
}


  

1;
