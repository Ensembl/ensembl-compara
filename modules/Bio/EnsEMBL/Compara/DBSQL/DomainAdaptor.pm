# $Id$
# 
# BioPerl module for Bio::EnsEMBL::Compara::DBSQL::FamilyAdaptor
# 
# Initially cared for by Philip Lijnzaad <lijnzaad@ebi.ac.uk>
# Now cared by Elia Stupka <elia@fugu-sg.org> and Abel Ureta-Vidal <abel@ebi.ac.uk>
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

  my $famdb = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-user   => 'myusername',
								       -dbname => 'myfamily_db',
								       -host   => 'myhost');

  my $fam_adtor = $famdb->get_FamilyAdaptor;

  my $fam = $fam_adtor->fetch_by_stable_id('ENSF000013034');
  my @fam = @{$fam_adtor->fetch_by_dbname_id('SPTR', 'P000123')};
  @fam = @{$fam_adtor->fetch_by_description_with_wildcards('interleukin',1)};
  @fam = @{$fam_adtor->fetch_all()};

  ### You can add the FamilyAdaptor as an 'external adaptor' to the 'main'
  ### Ensembl database object, then use it as:

  $ensdb = new Bio::EnsEMBL::DBSQL::DBAdaptor->(-user....);

  $ensdb->add_db_adaptor('MyfamilyAdaptor', $fam_adtor);

  # then later on, elsewhere: 
  $fam_adtor = $ensdb->get_db_adaptor('MyfamilyAdaptor');

  # also available:
  $ensdb->get_all_db_adaptors;
  $ensdb->remove_db_adaptor('MyfamilyAdaptor');

=head1 DESCRIPTION

This module is an entry point into a database of protein families,
clustering SWISSPROT/TREMBL and ensembl protein sets using the TRIBE MCL algorithm.
The clustering neatly follows the SWISSPROT DE-lines, which are 
taken as the description of the whole family.

The objects can be read from and write to a family database.

For more info, see ensembl-doc/family.txt

=head1 CONTACT

 Philip Lijnzaad <Lijnzaad@ebi.ac.uk> [original perl modules]
 Anton Enright <enright@ebi.ac.uk> [TRIBE algorithm]
 Elia Stupka <elia@fugu-sg.org> [refactoring]
 Able Ureta-Vidal <abel@ebi.ac.uk> [multispecies migration]

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::DomainAdaptor;

use strict;
use Bio::EnsEMBL::Compara::Domain;
use Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor;

our @ISA = qw(Bio::EnsEMBL::Compara::BaseRelationAdaptor);


=head2 fetch_by_relation

 Arg [1]    : string $dbname
 Arg [2]    : string $member_stable_id
 Example    : $fams = $FamilyAdaptor->fetch_of_dbname_id('SPTR', 'P01235');
 Description: find the family to which the given database and  member_stable_id belong
 Returntype : an array reference of Bio::EnsEMBL::Compara::Family objects
              (could be empty or contain more than one Family in the case of ENSEMBLGENE only)
 Exceptions : when missing arguments
 Caller     : general

=cut

sub fetch_by_relation {
  my ($self, $relation) = @_;

  my $join;
  my $constraint;

  $self->throw() 
    unless (defined $relation && ref $relation);
  
  if ($relation->isa('Bio::EnsEMBL::Compara::Member')) {
    $join = [['domain_member', 'dm'], 'd.domain_id = dm.domain_id'];
    my $member_id = $relation->dbID;
    $constraint = "dm.member_id = $member_id";
  }
#  elsif ($relation->isa('Bio::EnsEMBL::Compara::Domain')) {
#    $join = [['domain_family', 'df'], 'f.family_id = df.family_id'];
#    my $domain_id = $relation->dbID;
#    $constraint = "df.domain_id = $domain_id";
#  }
#  elsif ($relation->isa('Bio::EnsEMBL::Compara::Homology')) {
#  }
  else {
    $self->throw();
  }

  return $self->generic_fetch($constraint, $join);
}

sub fetch_by_relation_source {
  my ($self, $relation, $source_name) = @_;

  my $join;
  my $constraint = "s.source_name = $source_name";

  $self->throw() 
    unless (defined $relation && ref $relation);
  
  $self->throw("source_name arg is required\n")
    unless ($source_name);

  if ($relation->isa('Bio::EnsEMBL::Compara::Member')) {
    $join = [['domain_member', 'dm'], 'd.domain_id = dm.domain_id'];
    my $member_id = $relation->dbID;
    $constraint .= " AND dm.member_id = $member_id";
  }
#  elsif ($relation->isa('Bio::EnsEMBL::Compara::Domain')) {
#    $join = [['domain_family', 'df'], 'f.family_id = df.family_id'];
#    my $domain_id = $relation->dbID;
#    $constraint = " AND df.domain_id = $domain_id";
#  }
#  elsif ($relation->isa('Bio::EnsEMBL::Compara::Homology')) {
#  }
  else {
    $self->throw();
  }

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
      $constraint = "d.description LIKE '"."%"."\U$desc"."%"."'";
    }
    else {
      $constraint = "d.description = '$desc'";
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

##################
# internal methods

#internal method used in multiple calls above to build family objects from table data  

sub _tables {
  my $self = shift;

  return {['domain', 'd'], ['source', 's']};
}

sub _columns {
  my $self = shift;

  return qw (d.domain_id,
             d.stable_id,
             d.description,
             s.source_id,
             s.source_name);
}

sub _objs_from_sth {
  my ($self, $sth) = @_;
  
  my ($domain_id, $stable_id, $description, $source_id, $source_name);

  $sth->bind_columns(\$domain_id, \$stable_id, \$description,
                     \$source_id, \$source_name);

  my @domains = ();
  
  while ($sth->fetch()) {
    push @domains, Bio::EnsEMBL::Compara::Domain->new_fast
      ('_dbID' => $domain_id,
       '_stable_id' => $stable_id,
       '_description' => $description,
       '_source_id' => $source_id,
       '_source_name' => $source_name,
       '_adaptor' => $self);
  }
  
  return \@domains;  
}

sub _default_where_clause {
  my $self = shift;

  return 'd.source_id = s.source_id';
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
  my ($self,$dom) = @_;

  $dom->isa('Bio::EnsEMBL::Compara::Domain') ||
    $self->throw("You have to store a Bio::EnsEMBL::Compara::Domain object, not a $dom");

  my $sql = "SELECT domain_id from domain where stable_id = ?";
  my $sth = $self->prepare($sql);
  $sth->execute($dom->stable_id);
  my $rowhash = $sth->fetchrow_hashref;
  if ($rowhash->{domain_id}) {
    return $rowhash->{domain_id};
  }
  
  $dom->source_id($self->store_source($dom->source_name));
  
  $sql = "INSERT INTO domain (stable_id, source_id, description) VALUES (?,?,?)";
  $sth = $self->prepare($sql);
  $sth->execute($dom->stable_id,$dom->source_id,$dom->description);
  $dom->dbID($sth->{'mysql_insertid'});

  foreach my $member (@{$dom->get_all_members}) {
    $self->store_relation($member, $dom);
  }

  return $dom->dbID;
}

1;
