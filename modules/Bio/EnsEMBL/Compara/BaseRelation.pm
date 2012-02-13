=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=cut

=head1 NAME

BaseRelation - A superclass for pairwise or multiple relationships, base of
Bio::EnsEMBL::Compara::Family, Bio::EnsEMBL::Compara::Homology and
Bio::EnsEMBL::Compara::Domain.

=head1 DESCRIPTION

A superclass for pairwise and multiple relationships

Currently the AlignedMember objects are used in the GeneTree structure
to represent the leaves of the trees. Each leaf contains an aligned
sequence, which is represented as an AlignedMember object.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::BaseRelation

=head1 METHODS

=cut

package Bio::EnsEMBL::Compara::BaseRelation;

use strict;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;

=head2 new

  Arg [-DBID]  : 
       int - internal ID for this object
  Arg [-ADAPTOR]:
        Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor - the object adaptor
  Arg [-STABLE_ID] :
        string - the stable identifier of this object
  Arg [-VERSION] :
        int - the version of the stable identifier of this object
  Arg [-METHOD_LINK_SPECIES_SET_ID] :
        int - the internal ID for the MethodLinkSpeciesSet object
  Arg [-METHOD_LINK_TYPE] :
        string - the method_link_type
  Arg [-DESCRIPTION]:
        string - the description for the object
  Example    : $family = Bio::EnsEMBL::Compara::BaseRelation->new(...);
  Description: Creates a new BaseRelation object
  Returntype : Bio::EnsEMBL::Compara::BaseRelation
  Exceptions : none
  Caller     : subclass->new
  Status     : Stable

=cut

sub new {
  my ($class, @args) = @_;

  my $self = bless {}, $class;

  if (scalar @args) {
    #do this explicitly.
    my ($dbid, $stable_id, $version, $method_link_species_set_id, $method_link_type, $description, $adaptor)
        = rearrange([qw(DBID STABLE_ID VERSION METHOD_LINK_SPECIES_SET_ID METHOD_LINK_TYPE DESCRIPTION ADAPTOR)], @args);
    
    $dbid && $self->dbID($dbid);
    $stable_id && $self->stable_id($stable_id);
    $version && $self->version($version);
    $description && $self->description($description);
    $method_link_species_set_id && $self->method_link_species_set_id($method_link_species_set_id);
    $method_link_type && $self->method_link_type($method_link_type);
    $adaptor && $self->adaptor($adaptor);
  }
  
  return $self;
}

=head2 new_fast

  Arg [1]    : hash reference $hashref
  Example    : none
  Description: This is an ultra fast constructor which requires knowledge of
               the objects internals to be used.
  Returntype : 
  Exceptions : none
  Caller     : 
  Status     : Stable

=cut

sub new_fast {
  my ($class, $hashref) = @_;

  return bless $hashref, $class;
}

=head2 dbID

  Arg [1]    : int $dbID (optional)
  Example    : 
  Description: Getter/setter for the internal ID of this relation
  Returntype : int
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub dbID {
  my $self = shift;
  $self->{'_dbID'} = shift if(@_);
  return $self->{'_dbID'};
}

=head2 stable_id

  Arg [1]    : string $stable_id (optional)
  Example    : 
  Description: Getter/setter for the stable ID of this relation
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub stable_id {
  my $self = shift;
  $self->{'_stable_id'} = shift if(@_);
  return $self->{'_stable_id'};
}

=head2 version

  Arg [1]    : string $version (optional)
  Example    : 
  Description: Getter/setter for the version number of the stable ID
  Returntype : int
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub version {
  my $self = shift;
  $self->{'_version'} = shift if(@_);
  return $self->{'_version'};
}

=head2 description

  Arg [1]    : string $description (optional)
  Example    : 
  Description: Getter/setter for the description corresponding to this relation
  Returntype : string
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub description {
  my $self = shift;
  $self->{'_description'} = shift if(@_);
  return $self->{'_description'};
}

=head2 method_link_species_set

  Arg [1]    : MethodLinkSpeciesSet object (optional)
  Example    : 
  Description: getter/setter method for the MethodLinkSpeciesSet for this relation.
               Can lazy-load the method_link_species_set from the method_link_species_set_id
               if that one is set and the adaptor is set.
  Returntype : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
  Exceptions : throws if setting to an unsuitable object 
  Caller     : general
  Status     : Stable

=cut

sub method_link_species_set {
  my $self = shift;

  if(@_) {
    my $mlss = shift;
    unless ($mlss->isa('Bio::EnsEMBL::Compara::MethodLinkSpeciesSet')) {
      throw("Need to add a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet, not a $mlss\n");
    }
    $self->{'_method_link_species_set'} = $mlss;
    $self->{'_method_link_species_set_id'} = $mlss->dbID;
  }

  #lazy load from method_link_species_set_id
  if ( ! defined $self->{'_method_link_species_set'} && defined $self->method_link_species_set_id) {
    my $mlssa = $self->adaptor->db->get_MethodLinkSpeciesSetAdaptor;
    my $mlss = $mlssa->fetch_by_dbID($self->method_link_species_set_id);
    $self->{'_method_link_species_set'} = $mlss;
  }

  return $self->{'_method_link_species_set'};
}

=head2 method_link_species_set_id

  Arg [1]    : integer (optional)
  Example    : 
  Description: getter/setter method for the internal ID of the MethodLinkSpeciesSet
               for this relation.
  Returntype : integer
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub method_link_species_set_id {
  my $self = shift;

  $self->{'_method_link_species_set_id'} = shift if (@_);
  return $self->{'_method_link_species_set_id'};
}

=head2 method_link_type

  Arg [1]    : string $method_link_type (optional)
  Example    : 
  Description: getter/setter method for the method_link_type for this relation.
               Can obtain the data from the method_link_species_set object.
  Returntype : string
  Exceptions : Throws when getting if both this value and the method_link_species_set
               are unset.
  Caller     : general
  Status     : Stable

=cut

sub method_link_type {
  my $self = shift;

  $self->{'_method_link_type'} = shift if (@_);
  unless (defined $self->{'_method_link_type'}) {
    my $mlss = $self->method_link_species_set;
    throw("method_link_type needs a valid method_link_species_set") unless($mlss);
    $self->{'_method_link_type'} = $mlss->method_link_type;
  }

  return $self->{'_method_link_type'};
}

=head2 method_link_id

  Arg [1]    : integer (optional)
  Example    : 
  Description: getter/setter method for the method_link_id for this relation.
               Can obtain the data from the method_link_species_set object.
  Returntype : integer
  Exceptions : Throws when getting if both this value and the method_link_species_set
               are unset.
  Caller     : general
  Status     : Stable

=cut

sub method_link_id {
  my $self = shift;

  $self->{'_method_link_id'} = shift if (@_);
  unless (defined $self->{'_method_link_id'}) {
    my $mlss = $self->method_link_species_set;
    throw("method_link_type needs a valid method_link_species_set") unless($mlss);
    $self->{'_method_link_id'} = $mlss->method_link_id;
  }

  return $self->{'_method_link_id'};
}

=head2 adaptor

  Arg [1]    : string $adaptor (optional)
               corresponding to a perl module
  Example    : 
  Description: getter/setter method for the adaptor for this relation. Usually
               this will be an object from a subclass of
               Bio::EnsEMBL::Compara::BaseRelationAdaptor
  Returntype : Bio::EnsEMBL::Compara::BaseRelationAdaptor object
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub adaptor {
  my $self = shift;
  $self->{'_adaptor'} = shift if(@_);
  return $self->{'_adaptor'};
}


=head2 add_Member_Attribute

  Arg [1]    : arrayref of (Member, Attribute) objects
  Example    : 
  Description: Add a new pair of Member, Attribute objects to this relation
  Returntype : none
  Exceptions : Throws if input objects don't check
  Caller     : general
  Status     : Stable

=cut

sub add_Member_Attribute {
  my ($self, $member_attribute) = @_;

  my ($member, $attribute) = @{$member_attribute};

  throw("member argument not defined\n") unless($member);
  throw("attribute argument not defined\n") unless($attribute);
  
  unless ($member->isa('Bio::EnsEMBL::Compara::Member')) {
    throw("Need to add a Bio::EnsEMBL::Compara::Member, not a $member\n");
  }
  unless ($attribute->isa('Bio::EnsEMBL::Compara::Attribute')) {
    throw("Need to add a Bio::EnsEMBL::Compara::Attribute, not a $attribute\n");
  }
  
  my $source_name = $member->source_name();
  my $taxon_id = $member->taxon_id();
  my $genome_db_id = $member->genome_db_id();

  if (defined $self->{'_this_one_first'} && $self->{'_this_one_first'} eq $member->stable_id) {
    unshift @{$self->{'_member_array'}}, $member_attribute ;
    unshift @{$self->{'_members_by_source'}{$source_name}}, $member_attribute;
    unshift @{$self->{'_members_by_source_taxon'}{"${source_name}_${taxon_id}"}}, $member_attribute;
    if(defined $genome_db_id) {
	    unshift @{$self->{_members_by_source_genome_db}{"${source_name}_${genome_db_id}"}}, $member_attribute;
	    unshift @{$self->{_members_by_genome_db}{$genome_db_id}}, $member_attribute;
    }
  } else {
    push @{$self->{'_member_array'}}, $member_attribute ;
    push @{$self->{'_members_by_source'}{$source_name}}, $member_attribute;
    push @{$self->{'_members_by_source_taxon'}{"${source_name}_${taxon_id}"}}, $member_attribute;
    if(defined $genome_db_id) {
	    push @{$self->{_members_by_source_genome_db}{"${source_name}_${genome_db_id}"}}, $member_attribute;
	    push @{$self->{_members_by_genome_db}{$genome_db_id}}, $member_attribute;
    }
  }
}


=head2 get_all_Member_Attribute

  Arg [1]    : None
  Example    : 
  Description: 
  Returntype : array reference of [Bio::EnsEMBL::Compara::Member, Bio::EnsEMBL::Compara::Attribute]
  Exceptions : 
  Caller     : 

=cut

sub get_all_Member_Attribute {
  my ($self) = @_;
  
  unless (defined $self->{'_member_array'}) {

    my $MemberAdaptor = $self->adaptor->db->get_MemberAdaptor();
    my $members = $MemberAdaptor->fetch_all_by_relation($self);

    $self->{'_member_array'} = [];
    $self->{'_members_by_source'} = {};
    $self->{'_members_by_source_taxon'} = {};
    $self->{'_members_by_source_genome_db'} = {};
    $self->{'_members_by_genome_db'} = {};
    foreach my $member_attribute (@{$members}) {
      $self->add_Member_Attribute($member_attribute);
    }
  }
  return $self->{'_member_array'}; #should return also attributes
}


=head2 get_all_Members

  Arg [1]    : None
  Example    : 
  Description: 
  Returntype : array reference of Bio::EnsEMBL::Compara::Member
  Exceptions : 
  Caller     : public

=cut

sub get_all_Members {
  my ($self) = @_;

  my $members = [];
  foreach my $member_attribute (@{$self->get_all_Member_Attribute}) {
    my ($member, $attribute) = @$member_attribute;
    push (@$members, $member);
  }

  return $members;
}


=head2 get_Member_Attribute_by_source

  Arg [1]    : string $source_name
               e.g. "ENSEMBLPEP"
  Example    : 
  Description: 
  Returntype : array reference of Bio::EnsEMBL::Compara::Member and attribute
  Exceptions : 
  Caller     : public

=cut

sub get_Member_Attribute_by_source {
  my ($self, $source_name) = @_;
  throw("Should give defined source_name as arguments\n") unless (defined $source_name);
  my ($attribute_scope, $key) = ('_members_by_source', $source_name);
	return $self->_get_Member_Attribute($attribute_scope, $key);
}

=head2 get_Member_Attribute_by_source_taxon

  Arg [1]    : string $source_name
  Arg [2]    : int $taxon_id
  Example    : $domain->get_Member_by_source_taxon('ENSEMBLPEP',9606)
  Description: 
  Returntype : array reference of Bio::EnsEMBL::Compara::Member
  Exceptions : 
  Caller     : public

=cut

sub get_Member_Attribute_by_source_taxon {
  my ($self, $source_name, $taxon_id) = @_;
  throw("Should give defined source_name and taxon_id as arguments\n") unless (defined $source_name && defined $taxon_id);
  my ($attribute_scope, $key) = ('_members_by_source_taxon', "${source_name}_${taxon_id}");
  return $self->_get_Member_Attribute($attribute_scope, $key);
}

=head2 get_Member_Attribute_by_GenomeDB

  Arg [1]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Example    : $domain->get_Member_Attribute_by_GenomeDB($genome_db)
  Description: Returns all [Member_Attribute] entries linked to this GenomeDB. 
               This will only return EnsEMBL based entries since UniProtKB 
               entries are not linked to a GenomeDB.
  Returntype : array reference of Bio::EnsEMBL::Compara::Member
  Exceptions : If input is undefined & genome db is not of expected type
  Caller     : public

=cut

sub get_Member_Attribute_by_GenomeDB {
	my ($self, $genome_db) = @_;
	throw("Should give defined genome_db as an argument\n") unless defined $genome_db;
	throw("Param was not a GenomeDB. Was [${genome_db}]") unless $genome_db->isa('Bio::EnsEMBL::Compara::GenomeDB');
	my ($attribute_scope, $key) = ('_members_by_genome_db', $genome_db->dbID());
  return $self->_get_Member_Attribute($attribute_scope, $key);
}

=head2 get_Member_Attribute_by_source_GenomeDB

  Arg [1]    : string $source_name
  Arg [2]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Example    : $domain->get_Member_by_source_taxon('ENSEMBLPEP', $genome_db)
  Description: Returns all [Member_Attribute] entries linked to this GenomeDB
               and the given source_name. This will only return EnsEMBL based 
               entries since UniProtKB entries are not linked to a GenomeDB.
  Returntype : array reference of Bio::EnsEMBL::Compara::Member
  Exceptions : If input is undefined & genome db is not of expected type
  Caller     : public

=cut

sub get_Member_Attribute_by_source_GenomeDB {
	my ($self, $source_name, $genome_db) = @_;
	throw("Should give defined source_name & genome_db as arguments\n") unless defined $source_name && $genome_db;
	throw("Param was not a GenomeDB. Was [${genome_db}]") unless $genome_db->isa('Bio::EnsEMBL::Compara::GenomeDB');
	my ($attribute_scope, $key) = ('_members_by_source_genome_db', "${source_name}_".$genome_db->dbID());
  return $self->_get_Member_Attribute($attribute_scope, $key);
}

=head2 _get_Member_Attribute

  Arg [1]    : string $attribute_scope
  Arg [2]    : string $key
  Example    : $domain->_get_Member_Attribute('_members_by_source', 'ENSEMBLPEP')
  Description: Used as the generic reference point for all 
               get_Memeber_Attribute_by* methods. The method searches the given
               scope & if the values cannot be found will initalize that value
               to an empty array reference.
  Returntype : array reference of Bio::EnsEMBL::Compara::Member
  Exceptions : None.
  Caller     : internal

=cut

sub _get_Member_Attribute {
	my ($self, $attribute_scope, $key) = @_;
	$self->get_all_Member_Attribute();
	$self->{$attribute_scope}->{$key} = [] unless defined $self->{$attribute_scope}->{$key};
  return $self->{$attribute_scope}->{$key};
}

=head2 Member_count_by_source

  Arg [1]    : string $source_name
               e.g. "ENSEMBLPEP"
  Example    : $domain->Member_count_by_source('ENSEMBLPEP');
  Description: 
  Returntype : int
  Exceptions : 
  Caller     : public

=cut

sub Member_count_by_source {
  my ($self, $source_name) = @_; 
  
  throw("Should give a defined source_name as argument\n") unless (defined $source_name);
  
  return scalar @{$self->get_Member_Attribute_by_source($source_name)};
}

=head2 Member_count_by_source_taxon

  Arg [1]    : string $source_name
  Arg [2]    : int $taxon_id
  Example    : Member_count_by_source_taxon('ENSEMBLPEP',9606);
  Description: 
  Returntype : int
  Exceptions : 
  Caller     : public

=cut

sub Member_count_by_source_taxon {
  my ($self, $source_name, $taxon_id) = @_; 
  
  throw("Should give defined source_name and taxon_id as arguments\n") unless (defined $source_name && defined $taxon_id);

  return scalar @{$self->get_Member_Attribute_by_source_taxon($source_name,$taxon_id)};
}

=head2 Member_count_by_GenomeDB

  Arg [1]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Example    : Member_count_by_GenomeDB($genome_db);
  Description: Convenience wrapper for member counts by a GenomeDB
  Returntype : int
  Exceptions : Thrown by subrountines this call. See get_Member_Attribute 
               equivalent
  Caller     : public

=cut

sub Member_count_by_GenomeDB {
	my ($self, $genome_db) = @_;
	return scalar @{$self->get_Member_Attribute_by_GenomeDB($genome_db)};
}

=head2 Member_count_by_source_GenomeDB

  Arg [1]    : string $source_name
  Arg [2]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Example    : Member_count_by_source_GenomeDB('ENSEMBLPEP', $genome_db);
  Description: Convenience wrapper for member counts by a GenomeDB
  Returntype : int
  Exceptions : Thrown by subrountines this call. See get_Member_Attribute 
               equivalent
  Caller     : public

=cut


sub Member_count_by_source_GenomeDB {
	my ($self, $source_name, $genome_db) = @_;
	return scalar @{$self->get_Member_Attribute_by_source_GenomeDB($source_name, $genome_db)};
}


1;
