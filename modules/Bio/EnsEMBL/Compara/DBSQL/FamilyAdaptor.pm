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

 Arg [1]    : string $dbname
 Arg [2]    : string $member_stable_id
 Example    : $fams = $FamilyAdaptor->fetch_of_dbname_id('SPTR', 'P01235');
 Description: find the family to which the given database and  member_stable_id belong
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

  my $join = [['family_member', 'fm'], 'f.family_id = fm.family_id'];
  my $constraint = "fm.member_id = ". $member->dbID;

  return $self->generic_fetch($constraint, $join);
}

# maybe a useful method in case more than one kind of family data is stored in the db.
sub fetch_by_Member_source {
  my ($self, $member, $source_name) = @_;

  unless ($member->isa('Bio::EnsEMBL::Compara::Member')) {
    $self->throw("The argument must be a Bio::EnsEMBL::Compara::Member object, not $member");
  }

  $self->throw("source_name arg is required\n")
    unless ($source_name);

  my $join = [['family_member', 'fm'], 'f.family_id = fm.family_id'];
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

=head2 fetch_Taxon_by_dbname_dbID

 Arg [1]    : string $dbname
              Either "ENSEMBLGENE", "ENSEMBLPEP" or "SPTR" 
 Arg [2]    : int dbID
              a family_id
 Example    : $FamilyAdaptor->fetch_Taxon_by_dbname('ENSEMBLGENE',1)
 Description: get all the taxons that belong to a particular database and family_id
 Returntype : an array reference of Bio::EnsEMBL::Compara::Taxon objects
              (which may be empty)
 Exceptions : when missing argument
 Caller     : general

=cut

sub fetch_Taxon_by_dbname_dbID {
  my ($self,$dbname,$dbID) = @_;
  
  $self->throw("Should give defined databasename and family_id as arguments\n") unless (defined $dbname && defined $dbID);

  my $q = "SELECT distinct(taxon_id) as taxon_id
           FROM family f, family_members fm, external_db edb
           WHERE f.family_id = fm.family_id
           AND fm.external_db_id = edb.external_db_id 
           AND f.family_id = $dbID
           AND edb.name = '$dbname'"; 
  $q = $self->prepare($q);
  $q->execute;

  my @taxons = ();

  while (defined (my $rowhash = $q->fetchrow_hashref)) {
    my $TaxonAdaptor = $self->db->get_TaxonAdaptor;
    my $taxon = $TaxonAdaptor->fetch_by_taxon_id($rowhash->{taxon_id});
    push @taxons, $taxon;
  }
    
  return \@taxons;

}



=head2 fetch_alignment

  Arg [1]    : Bio::EnsEMBL::External::Family::Family $family
  Example    : $family_adaptor->fetch_alignment($family);
  Description: Retrieves the alignment strings for all the members of a 
               family
  Returntype : none
  Exceptions : none
  Caller     : FamilyMember::align_string

=cut

sub fetch_alignment {
  my($self, $family) = @_;

  my $members = $family->get_all_Member;
  return unless(@$members);

  my $sth = $self->prepare("SELECT family_member_id, alignment 
                            FROM family_members
                            WHERE family_id = ?");
  $sth->execute($family->dbID);

  #move results of query into hash keyed on family member id
  my %align_hash = map {$_->[0] => $_->[1]} (@{$sth->fetchall_arrayref});
  $sth->finish;

  #set the slign strings for each of the members
  foreach my $member (@$members) {
    $member->alignment_string($align_hash{$member->dbID()});
  }

  return;
}


##################
# internal methods

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

###############
# store methods

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

#process ensembl taxon information for FamilyConf.pm
sub _setup_ens_taxon {
    my ($self,@taxon_str) = @_;

    my %hash;
    foreach my $str(@taxon_str){

      $str=~s/=;/=undef;/g;
      my %taxon = map{split '=',$_}split';',$str;
      my $prefix = $taxon{'PREFIX'}; 
      delete $taxon{'PREFIX'};
      $hash{$prefix} = \%taxon;
    }
    return %hash;
}

1;
