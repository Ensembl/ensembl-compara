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

AlignedMemberSet - A superclass for pairwise or multiple relationships, base of
Bio::EnsEMBL::Compara::Family, Bio::EnsEMBL::Compara::Homology and
Bio::EnsEMBL::Compara::Domain.

=head1 DESCRIPTION

A superclass for pairwise and multiple relationships

Currently the AlignedMember objects are used in the GeneTree structure
to represent the leaves of the trees. Each leaf contains an aligned
sequence, which is represented as an AlignedMember object.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::AlignedMemberSet

=head1 METHODS

=cut

package Bio::EnsEMBL::Compara::AlignedMemberSet;

use strict;
use Scalar::Util qw(weaken);
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Compara::Attribute;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::AlignedMember;

####################################
#                                  #
#  Constructor, getters / setters  #
#                                  #
####################################


=head2 new

  Arg [-DBID]  : 
       int - internal ID for this object
  Arg [-ADAPTOR]:
        Bio::EnsEMBL::Compara::DBSQL::AlignedMemberSetAdaptor - the object adaptor
  Arg [-STABLE_ID] :
        string - the stable identifier of this object
  Arg [-VERSION] :
        int - the version of the stable identifier of this object
  Arg [-METHOD_LINK_SPECIES_SET_ID] :
        int - the internal ID for the MethodLinkSpeciesSet object
  Arg [-DESCRIPTION]:
        string - the description for the object
  Example    : $family = Bio::EnsEMBL::Compara::AlignedMemberSet->new(...);
  Description: Creates a new AlignedMemberSet object
  Returntype : Bio::EnsEMBL::Compara::AlignedMemberSet
  Exceptions : none
  Caller     : subclass->new
  Status     : Stable

=cut

sub new {
    my ($class, @args) = @_;

    my $self = bless {}, $class;

    if (scalar @args) {
        #do this explicitly.
        my ($dbid, $stable_id, $version, $method_link_species_set_id, $description, $adaptor)
            = rearrange([qw(DBID STABLE_ID VERSION METHOD_LINK_SPECIES_SET_ID DESCRIPTION ADAPTOR)], @args);

        $dbid && $self->dbID($dbid);
        $stable_id && $self->stable_id($stable_id);
        $version && $self->version($version);
        $description && $self->description($description);
        $method_link_species_set_id && $self->method_link_species_set_id($method_link_species_set_id);
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

    DEPRECATED. Use method_link_species_set()->method()->type() instead. This is not a setter any more.

=cut

sub method_link_type {  # DEPRECATED
    my $self = shift;
    deprecate('Use method_link_species_set()->method()->type() instead. This is not a setter any more.');
    return $self->method_link_species_set->method->type() if defined $self->{'_method_link_species_set_id'};
}


=head2 method_link_id

    DEPRECATED. Use method_link_species_set()->method()->dbID() instead. This is not a setter any more.

=cut

sub method_link_id {  # DEPRECATED
    my $self = shift;
    deprecate('Use method_link_species_set()->method()->dbID() instead. This is not a setter any more.');
    return $self->method_link_species_set->method->dbID if defined $self->{'_method_link_species_set_id'};
}

=head2 adaptor

  Arg [1]    : string $adaptor (optional)
               corresponding to a perl module
  Example    : 
  Description: getter/setter method for the adaptor for this relation. Usually
               this will be an object from a subclass of
               Bio::EnsEMBL::Compara::AlignedMemberSetAdaptor
  Returntype : Bio::EnsEMBL::Compara::AlignedMemberSetAdaptor object
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub adaptor {
    my $self = shift;
    $self->{'_adaptor'} = shift if(@_);
    return $self->{'_adaptor'};
}



###########################
#                         #
#  AlignedMember content  #
#                         #
###########################

=head2 add_AlignedMember

  Arg [1]    : AlignedMember
  Example    : 
  Description: Add a new AlignedMember to this set
  Returntype : none
  Exceptions : Throws if input objects don't check
  Caller     : general
  Status     : Stable

=cut

sub add_AlignedMember {
    my ($self, $member) = @_;

    throw("member argument not defined\n") unless($member);

    unless ($member->isa('Bio::EnsEMBL::Compara::AlignedMember')) {
        throw("Need to add a Bio::EnsEMBL::Compara::AlignedMember, not a $member\n");
    }

    my $source_name = $member->source_name();
    my $taxon_id = $member->taxon_id();
    my $genome_db_id = $member->genome_db_id();
    #print "adding $source_name: ", $member->dbID, "\n";

    if (defined $self->{'_this_one_first'} && $self->{'_this_one_first'} eq $member->stable_id) {
        unshift @{$self->{'_member_array'}}, $member ;
        unshift @{$self->{'_members_by_source'}{$source_name}}, $member;
        unshift @{$self->{'_members_by_source_taxon'}{"${source_name}_${taxon_id}"}}, $member;
        if(defined $genome_db_id) {
            unshift @{$self->{_members_by_source_genome_db}{"${source_name}_${genome_db_id}"}}, $member;
            unshift @{$self->{_members_by_genome_db}{$genome_db_id}}, $member;
        }
    } else {
        push @{$self->{'_member_array'}}, $member ;
        push @{$self->{'_members_by_source'}{$source_name}}, $member;
        push @{$self->{'_members_by_source_taxon'}{"${source_name}_${taxon_id}"}}, $member;
        if(defined $genome_db_id) {
            push @{$self->{_members_by_source_genome_db}{"${source_name}_${genome_db_id}"}}, $member;
            push @{$self->{_members_by_genome_db}{$genome_db_id}}, $member;
        }
    }

    $member->{'set'} = $self;
    weaken($member->{'set'});
}

sub add_Member_Attribute {  # DEPRECATED
    my ($self, $member_attribute) = @_;

    my $am = Bio::EnsEMBL::Compara::AlignedMember::_new_from_Member_Attribute(@{$member_attribute});
    $self->add_AlignedMember($am);
}

sub _tranform_array_to_Member_Attributes {
    my ($self, $array) = @_;
    my @all_ma;
    foreach my $am (@$array) {
        my $member = Bio::EnsEMBL::Compara::Member::copy($am);
        my $attribute = new Bio::EnsEMBL::Compara::Attribute;
        foreach my $key (qw(cigar_line perc_cov perc_id perc_pos member_id)) {
            $attribute->$key($am->$key);
        }
        push @all_ma, [$member, $attribute];
    }
    return \@all_ma;
}


=head2 get_all_AlignedMember

  Arg [1]    : None
  Example    : 
  Description: 
  Returntype : array reference of Bio::EnsEMBL::Compara::AlignedMember
  Exceptions : 
  Caller     : 

=cut

sub get_all_AlignedMember {
    my ($self) = @_;
  
    unless (defined $self->{'_member_array'}) {

        my $am_adaptor = $self->adaptor->db->get_AlignedMemberAdaptor();
        my $members = $am_adaptor->fetch_all_by_AlignedMemberSet($self);

        $self->{'_member_array'} = [];
        $self->{'_members_by_source'} = {};
        $self->{'_members_by_source_taxon'} = {};
        $self->{'_members_by_source_genome_db'} = {};
        $self->{'_members_by_genome_db'} = {};
        foreach my $member (@{$members}) {
            $self->add_AlignedMember($member);
        }
    }
    return $self->{'_member_array'};
}



=head2 get_all_GeneMember

  Arg [1]    : None
  Example    : 
  Description: 
  Returntype : array reference of Bio::EnsEMBL::Compara::Member
  Exceptions : 
  Caller     : public

=cut

sub get_all_GeneMember {
    my ($self) = @_;

    my $members = [];
    foreach my $aligned_member (@{$self->get_all_AlignedMember}) {
        push @$members, $aligned_member->gene_member if defined $aligned_member->gene_member;
    }

    return $members;
}
=head2 gene_list

  Example    : my $pair = $homology->gene_list
  Description: return the pair of members for the homology
  Returntype : array ref of (2) Bio::EnsEMBL::Compara::Member objects
  Caller     : general

=cut


sub gene_list {  # DEPRECATED
    my $self = shift;
    return $self->get_all_GeneMember
}



sub get_all_Members {  # DEPRECATED
    my $self = shift;
    return $self->get_all_AlignedMember;
}

sub get_all_Member_Attribute {  # DEPRECATED
    my $self = shift;
    return $self->_tranform_array_to_Member_Attributes($self->get_all_AlignedMember);
}


#################################
#                               #
#  AlignedMembers per category  #
#                               #
#################################

=head2 get_AlignedMember_by_source

  Arg [1]    : string $source_name
               e.g. "ENSEMBLPEP"
  Example    : 
  Description: 
  Returntype : array reference of Bio::EnsEMBL::Compara::AlignedMember
  Exceptions : 
  Caller     : public

=cut

sub get_AlignedMember_by_source {
    my ($self, $source_name) = @_;
    throw("Should give defined source_name as arguments\n") unless (defined $source_name);
    my ($scope, $key) = ('_members_by_source', $source_name);
    return $self->_get_AlignedMember($scope, $key);
}

=head2 get_AlignedMember_by_source_taxon

  Arg [1]    : string $source_name
  Arg [2]    : int $taxon_id
  Example    : $domain->get_AlignedMember_by_source_taxon('ENSEMBLPEP',9606)
  Description: 
  Returntype : array reference of Bio::EnsEMBL::Compara::Member
  Exceptions : 
  Caller     : public

=cut

sub get_AlignedMember_by_source_taxon {
    my ($self, $source_name, $taxon_id) = @_;
    throw("Should give defined source_name and taxon_id as arguments\n") unless (defined $source_name && defined $taxon_id);
    my ($scope, $key) = ('_members_by_source_taxon', "${source_name}_${taxon_id}");
    return $self->_get_AlignedMember($scope, $key);
}

=head2 get_AlignedMember_by_GenomeDB

  Arg [1]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Example    : $domain->get_AlignedMember_by_GenomeDB($genome_db)
  Description: Returns all [Member] entries linked to this GenomeDB. 
               This will only return EnsEMBL based entries since UniProtKB 
               entries are not linked to a GenomeDB.
  Returntype : array reference of Bio::EnsEMBL::Compara::Member
  Exceptions : If input is undefined & genome db is not of expected type
  Caller     : public

=cut

sub get_AlignedMember_by_GenomeDB {
    my ($self, $genome_db) = @_;
    throw("Should give defined genome_db as an argument\n") unless defined $genome_db;
    throw("Param was not a GenomeDB. Was [${genome_db}]") unless $genome_db->isa('Bio::EnsEMBL::Compara::GenomeDB');
    my ($scope, $key) = ('_members_by_genome_db', $genome_db->dbID());
    return $self->_get_AlignedMember($scope, $key);
}

=head2 get_AlignedMember_by_source_GenomeDB

  Arg [1]    : string $source_name
  Arg [2]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Example    : $domain->get_AlignedMember_by_source_taxon('ENSEMBLPEP', $genome_db)
  Description: Returns all [Member] entries linked to this GenomeDB
               and the given source_name. This will only return EnsEMBL based 
               entries since UniProtKB entries are not linked to a GenomeDB.
  Returntype : array reference of Bio::EnsEMBL::Compara::Member
  Exceptions : If input is undefined & genome db is not of expected type
  Caller     : public

=cut

sub get_AlignedMember_by_source_GenomeDB {
    my ($self, $source_name, $genome_db) = @_;
    throw("Should give defined source_name & genome_db as arguments\n") unless defined $source_name && $genome_db;
    throw("Param was not a GenomeDB. Was [${genome_db}]") unless $genome_db->isa('Bio::EnsEMBL::Compara::GenomeDB');
    my ($scope, $key) = ('_members_by_source_genome_db', "${source_name}_".$genome_db->dbID());
    return $self->_get_AlignedMember($scope, $key);
}

=head2 _get_AlignedMember

  Arg [1]    : string $scope
  Arg [2]    : string $key
  Example    : $domain->_get_AlignedMember('_members_by_source', 'ENSEMBLPEP')
  Description: Used as the generic reference point for all 
               get_Memeber_by* methods. The method searches the given
               scope & if the values cannot be found will initalize that value
               to an empty array reference.
  Returntype : array reference of Bio::EnsEMBL::Compara::Member
  Exceptions : None.
  Caller     : internal

=cut

sub _get_AlignedMember {
    my ($self, $scope, $key) = @_;
    $self->get_all_AlignedMember();
    $self->{$scope}->{$key} = [] unless defined $self->{$scope}->{$key};
    return $self->{$scope}->{$key};
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

sub get_Member_Attribute_by_source {  # DEPRECATED
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

sub get_Member_Attribute_by_source_taxon {  # DEPRECATED
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

sub get_Member_Attribute_by_GenomeDB {  # DEPRECATED
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

sub get_Member_Attribute_by_source_GenomeDB {  # DEPRECATED
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

sub _get_Member_Attribute {  # DEPRECATED
    my ($self, $attribute_scope, $key) = @_;
    $self->get_all_Member_Attribute();
    $self->{$attribute_scope}->{$key} = [] unless defined $self->{$attribute_scope}->{$key};
    return $self->_tranform_array_to_Member_Attributes($self->{$attribute_scope}->{$key});
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

    return scalar @{$self->get_AlignedMember_by_source($source_name)};
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

    return scalar @{$self->get_AlignedMember_by_source_taxon($source_name,$taxon_id)};
}

=head2 Member_count_by_GenomeDB

  Arg [1]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Example    : Member_count_by_GenomeDB($genome_db);
  Description: Convenience wrapper for member counts by a GenomeDB
  Returntype : int
  Exceptions : Thrown by subrountines this call. See get_AlignedMember
               equivalent
  Caller     : public

=cut

sub Member_count_by_GenomeDB {
    my ($self, $genome_db) = @_;
    return scalar @{$self->get_AlignedMember_by_GenomeDB($genome_db)};
}

=head2 Member_count_by_source_GenomeDB

  Arg [1]    : string $source_name
  Arg [2]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Example    : Member_count_by_source_GenomeDB('ENSEMBLPEP', $genome_db);
  Description: Convenience wrapper for member counts by a GenomeDB
  Returntype : int
  Exceptions : Thrown by subrountines this call. See get_AlignedMember
               equivalent
  Caller     : public

=cut


sub Member_count_by_source_GenomeDB {
    my ($self, $source_name, $genome_db) = @_;
    return scalar @{$self->get_AlignedMember_by_source_GenomeDB($source_name, $genome_db)};
}


=head2 get_all_taxa_by_member_source_name

  Arg [1]    : string $source_name
               e.g. "ENSEMBLPEP"
  Example    : 
  Description: Returns the distinct taxons found in this family across
               the specified source. If you do not specify a source then
               the code will return all taxons in this family.
  Returntype : array reference of distinct Bio::EnsEMBL::Compara::NCBITaxon 
               objects found in this family
  Exceptions : 
  Caller     : public

=cut

sub get_all_taxa_by_member_source_name {
    my ($self, $source_name) = @_;

    my $ncbi_ta = $self->adaptor->db->get_NCBITaxonAdaptor();
    my @taxa;
    $self->get_all_AlignedMember;
    foreach my $key (keys %{$self->{_members_by_source_taxon}}) {
        my @parts = split('_', $key);
        if ($parts[0] eq $source_name) {
            push @taxa, $ncbi_ta->fetch_node_by_taxon_id($parts[1]);
        }
    }
    return \@taxa;
}

=head2 get_all_GenomeDBs_by_member_source_name

  Arg [1]    : string $source_name
               e.g. "ENSEMBLPEP"
  Example    : 
  Description: Returns the distinct GenomeDBs found in this family. Please note
               that if you specify a source other than an EnsEMBL based one
               the chances of getting back GenomeDBs are very low.
  Returntype : array reference of distinct Bio::EnsEMBL::Compara::GenomeDB 
               objects found in this family
  Exceptions : 
  Caller     : public

=cut

sub get_all_GenomeDBs_by_member_source_name {
    my ($self, $source_name) = @_;

    my $gdb_a = $self->adaptor->db->get_GenomeDBAdaptor();
    my @gdbs;
    $self->get_all_AlignedMember;
    foreach my $key (keys $self->{_members_by_source_genome_db}) {
        my @parts = split('_', $key);
        if ($parts[0] eq $source_name) {
            push @gdbs, $gdb_a->fetch_by_dbID($parts[1]);
        }
    }
    return \@gdbs;
}

=head2 has_species_by_name

  Arg [1]    : string $species_name
  Example    : my $ret = $homology->has_species_by_name("Homo sapiens");
  Description: return TRUE or FALSE whether one of the members in the homology is from the given species
  Returntype : 1 or 0
  Exceptions :
  Caller     :

=cut


sub has_species_by_name {
  my $self = shift;
  my $species_name = shift;
  
  foreach my $member (@{$self->get_all_AlignedMember}) {
    return 1 if defined $member->genome_db and ($member->genome_db->name eq $species_name);
  }
  return 0;
}



######################
# Alignment sections #
######################


=head2 read_clustalw

  Arg [1]    : string $file 
               The name of the file containing the clustalw output  
  Example    : $family->read_clustalw('/tmp/clustalw.aln');
  Description: Parses the output from clustalw and sets the alignment strings
               of each of the memebers of this family
  Returntype : none
  Exceptions : thrown if file cannot be parsed
               warning if alignment file contains identifiers for sequences
               which are not members of this family
  Caller     : general

=cut

sub read_clustalw {
    my $self = shift;
    my $file = shift;

    my %align_hash;
    my $FH = IO::File->new();
    $FH->open($file) || throw("Could not open alignment file [$file]");

    <$FH>; #skip header
    while(<$FH>) {
        next if($_ =~ /^\s+/);  #skip lines that start with space

        my ($id, $align) = split;
        $align_hash{$id} ||= '';
        $align_hash{$id} .= $align;
    }

    $FH->close;

    #place all members in a hash on their member name
    my %member_hash;
    foreach my $member (@{$self->get_all_AlignedMember}) {
        $member_hash{$member->stable_id} = $member;
    }

    #assign cigar_line to each of the member attribute
    foreach my $id (keys %align_hash) {
        throw("No member for alignment portion: [$id]") unless exists $member_hash{$id};

        my $alignment_string = $align_hash{$id};
        $alignment_string =~ s/\-([A-Z])/\- $1/g;
        $alignment_string =~ s/([A-Z])\-/$1 \-/g;

        my @cigar_segments = split " ",$alignment_string;

        my $cigar_line = "";
        foreach my $segment (@cigar_segments) {
            my $seglength = length($segment);
            $seglength = "" if ($seglength == 1);
            if ($segment =~ /^\-+$/) {
                $cigar_line .= $seglength . "D";
            } else {
                $cigar_line .= $seglength . "M";
            }
        }

        $member_hash{$id}->cigar_line($cigar_line);
    }
}

sub load_cigars_from_fasta {
    my ($self, $file) = @_;

    my $alignio = Bio::AlignIO->new(-file => "$file", -format => "fasta");

    my $aln = $alignio->next_aln or die "Bio::AlignIO could not get next_aln() from file '$file'";

    #place all members in a hash on their member name
    my %member_hash;
    foreach my $member (@{$self->get_all_AlignedMember}) {
        $member_hash{$member->stable_id} = $member;
    }

    #assign cigar_line to each of the member attribute
    foreach my $seq ($aln->each_seq) {
        my $id = $seq->display_id;
        throw("No member for alignment portion: [$id]") unless exists $member_hash{$id};

        my $cigar_line = '';
        my $seq_string = $seq->seq();
        while($seq_string=~/(?:\b|^)(.)(.*?)(?:\b|$)/g) {
            $cigar_line .= ($2 ? length($2)+1 : '').(($1 eq '-') ? 'D' : 'M');
        }

        $member_hash{$id}->cigar_line($cigar_line);
    }
}



sub get_SimpleAlign {

    my ($self, @args) = @_;

    my $id_type = 'STABLE';
    my $unique_seqs = 0;
    my $cdna = 0;
    my $stop2x = 0;
    my $append_taxon_id = 0;
    my $append_sp_short_name = 0;
    my $append_genomedb_id = 0;
    my $exon_cased = 0;
    my $alignment = 'protein';
    my $changeSelenos = 0;
    if (scalar @args) {
        ($unique_seqs, $cdna, $id_type, $stop2x, $append_taxon_id, $append_sp_short_name, $append_genomedb_id, $exon_cased, $alignment, $changeSelenos) =
            rearrange([qw(UNIQ_SEQ CDNA ID_TYPE STOP2X APPEND_TAXON_ID APPEND_SP_SHORT_NAME APPEND_GENOMEDB_ID EXON_CASED ALIGNMENT CHANGE_SELENO)], @args);
    }

    my $sa = Bio::SimpleAlign->new();

    #Hack to try to work with both bioperl 0.7 and 1.2:
    #Check to see if the method is called 'addSeq' or 'add_seq'
    my $bio07 = ($sa->can('add_seq') ? 0 : 1);

    my $seq_id_hash = {};
    foreach my $member (@{$self->get_all_AlignedMember}) {

        # Print unique sequences only ?
        next if($unique_seqs and $seq_id_hash->{$member->sequence_id});
        $seq_id_hash->{$member->sequence_id} = 1;

        # The correct codon table
        if ($member->chr_name =~ /mt/i) {
            # codeml icodes
            # 0:universal code (default)
            my $class;
            eval {$class = member->taxon->classification;};
            unless ($@) {
                if ($class =~ /vertebrata/i) {
                    # 1:mamalian mt
                    $sa->{_special_codeml_icode} = 1;
                } else {
                    # 4:invertebrate mt
                    $sa->{_special_codeml_icode} = 4;
                }
            }
        }

        my $seqstr;
        my $alphabet;
        if ($cdna or (lc($alignment) eq 'cdna')) {
            $seqstr = $member->cdna_alignment_string($changeSelenos);
            $seqstr =~ s/\s+//g;
            $alphabet = 'dna';
        } else {
            $seqstr = $member->alignment_string($exon_cased);
            $alphabet = 'protein';
        }
        next if(!$seqstr);

        # Sequence name
        my $seqID = $member->stable_id;
        $seqID = $member->sequence_id if($id_type eq "SEQ");
        $seqID = $member->member_id if($id_type eq "MEMBER");
        $seqID .= "_" . $member->taxon_id if($append_taxon_id);
        $seqID .= "_" . $member->genome_db_id if ($append_genomedb_id);

        ## Append $seqID with Speciae short name, if required
        if ($append_sp_short_name) {
            my $species = $member->genome_db->short_name;
            $species =~ s/\s/_/g;
            $seqID .= "_" . $species . "_";
        }

        # Sequence length
        my $aln_end = $member->seq_length;
        $aln_end = $aln_end*3 if $alphabet eq 'dna';

        $seqstr =~ s/\*/X/g if ($stop2x);
        my $seq = Bio::LocatableSeq->new(
                -SEQ        => $seqstr,
                -ALPHABET   => $alphabet,
                -START      => 1,
                -END        => $aln_end,
                -ID         => $seqID,
                -STRAND     => 0
        );

        if($bio07) {
            $sa->addSeq($seq);
        } else {
            $sa->add_seq($seq);
        }
    }
    $sa = $sa->remove_gaps(undef, 1) if UNIVERSAL::can($sa, 'remove_gaps');
    return $sa;
}



# Takes a protein tree and creates a consensus cigar line from the
# constituent leaf nodes.
sub consensus_cigar_line {

   my $self = shift;
   my @cigars;

   # First get an 'expanded' cigar string for each leaf of the subtree
   my @all_members = @{$self->get_all_AlignedMember};
   my $num_members = scalar(@all_members);
   foreach my $leaf (@all_members) {
     next unless( UNIVERSAL::can( $leaf, 'cigar_line' ) );
     my $cigar = $leaf->cigar_line;
     my $newcigar = "";
#     $cigar =~ s/(\d*)([A-Z])/$2 x ($1||1)/ge; #Expand
      while ($cigar =~ /(\d*)([A-Z])/g) {
          $newcigar .= $2 x ($1 || 1);
      }
     $cigar = $newcigar;
     push @cigars, $cigar;
   }

   # Itterate through each character of the expanded cigars.
   # If there is a 'D' at a given location in any cigar,
   # set the consensus to 'D', otherwise assume an 'M'.
   # TODO: Fix assumption that cigar strings are always the same length,
   # and start at the same point.
   my $cigar_len = length( $cigars[0] );
   my $cons_cigar;
   for( my $i=0; $i<$cigar_len; $i++ ){
     my $char = 'M';
     my $num_deletions = 0;
     foreach my $cigar( @cigars ){
       if ( substr($cigar,$i,1) eq 'D'){
         $num_deletions++;
       }
     }
     if ($num_deletions * 3 > 2 * $num_members) {
       $char = "D";
     } elsif ($num_deletions * 3 > $num_members) {
       $char = "m";
     }
     $cons_cigar .= $char;
   }

   # Collapse the consensus cigar, e.g. 'DDDD' = 4D
#   $cons_cigar =~ s/(\w)(\1*)/($2?length($2)+1:"").$1/ge;
   my $collapsed_cigar = "";
   while ($cons_cigar =~ /(D+|M+|I+|m+)/g) {
     $collapsed_cigar .= (length($1) == 1 ? "" : length($1)) . substr($1,0,1)
 }
   $cons_cigar = $collapsed_cigar;
   # Return the consensus
   return $cons_cigar;
}


my %TWOD_CODONS = ("TTT" => "Phe",#Phe
                   "TTC" => "Phe",
                   
                   "TTA" => "Leu",#Leu
                   "TTG" => "Leu",
                   
                   "TAT" => "Tyr",#Tyr
                   "TAC" => "Tyr",
                   
                   "CAT" => "His",#His
                   "CAC" => "His",

                   "CAA" => "Gln",#Gln
                   "CAG" => "Gln",
                   
                   "AAT" => "Asn",#Asn
                   "AAC" => "Asn",
                   
                   "AAA" => "Lys",#Lys
                   "AAG" => "Lys",
                   
                   "GAT" => "Asp",#Asp
                   "GAC" => "Asp",

                   "GAA" => "Glu",#Glu
                   "GAG" => "Glu",
                   
                   "TGT" => "Cys",#Cys
                   "TGC" => "Cys",
                   
                   "AGT" => "Ser",#Ser
                   "AGC" => "Ser",
                   
                   "AGA" => "Arg",#Arg
                   "AGG" => "Arg",
                   
                   "ATT" => "Ile",#Ile
                   "ATC" => "Ile",
                   "ATA" => "Ile");

my %FOURD_CODONS = ("CTT" => "Leu",#Leu
                    "CTC" => "Leu",
                    "CTA" => "Leu",
                    "CTG" => "Leu",
                    
                    "GTT" => "Val",#Val 
                    "GTC" => "Val",
                    "GTA" => "Val",
                    "GTG" => "Val",
                    
                    "TCT" => "Ser",#Ser
                    "TCC" => "Ser",
                    "TCA" => "Ser",
                    "TCG" => "Ser",
                    
                    "CCT" => "Pro",#Pro
                    "CCC" => "Pro",
                    "CCA" => "Pro",
                    "CCG" => "Pro",
                    
                    "ACT" => "Thr",#Thr
                    "ACC" => "Thr",
                    "ACA" => "Thr",
                    "ACG" => "Thr",
                    
                    "GCT" => "Ala",#Ala
                    "GCC" => "Ala",
                    "GCA" => "Ala",
                    "GCG" => "Ala",
                    
                    "CGT" => "Arg",#Arg
                    "CGC" => "Arg",
                    "CGA" => "Arg",
                    "CGG" => "Arg",
                    
                    "GGT" => "Gly",#Gly
                    "GGC" => "Gly",
                    "GGA" => "Gly",
                    "GGG" => "Gly");
                    
my %CODONS =   ("ATG" => "Met",
                "TGG" => "Trp",
                "TAA" => "TER",
                "TAG" => "TER",
                "TGA" => "TER",
                "---" => "---",
                %TWOD_CODONS,
                %FOURD_CODONS,
                );


=head2 get_4D_SimpleAlign

  Example    : $4d_align = $homology->get_4D_SimpleAlign();
  Description: get 4 times degenerate positions pairwise simple alignment
  Returntype : Bio::SimpleAlign

=cut

sub get_4D_SimpleAlign {
    my $self = shift;

    my $sa = Bio::SimpleAlign->new();

    #Hack to try to work with both bioperl 0.7 and 1.2:
    #Check to see if the method is called 'addSeq' or 'add_seq'
    my $bio07 = 0;
    if(!$sa->can('add_seq')) {
        $bio07 = 1;
    }

    my $ma = $self->adaptor->db->get_MemberAdaptor;

    my %member_seqstr;
    foreach my $member (@{$self->get_all_AlignedMember}) {
        next if $member->source_name ne 'ENSEMBLPEP';
        my $seqstr = $member->cdna_alignment_string();
        next if(!$seqstr);
        #print STDERR $seqstr,"\n";
        my @tmp_tab = split /\s+/, $seqstr;
        #print STDERR "tnp_tab 0: ", $tmp_tab[0],"\n";
        $member_seqstr{$member->stable_id} = \@tmp_tab;
    }

    my $seqstr_length;
    foreach my $seqid (keys %member_seqstr) {
        unless (defined $seqstr_length) {
            #print STDERR $member_seqstr{$seqid}->[0],"\n";
            $seqstr_length = scalar @{$member_seqstr{$seqid}};
            next;
        }
        unless ($seqstr_length == scalar @{$member_seqstr{$seqid}}) {
            die "Length of dna alignment are not the same, $seqstr_length and " . scalar @{$member_seqstr{$seqid}} ." respectively for homology_id " . $self->dbID . "\n";
        }
    }

    my %FourD_member_seqstr;
    for (my $i=0; $i < $seqstr_length; $i++) {
        my $FourD_codon = 1;
        my $FourD_aminoacid;
        foreach my $seqid (keys %member_seqstr) {
            if (defined $FOURD_CODONS{$member_seqstr{$seqid}->[$i]}) {
                if (defined $FourD_aminoacid && $FourD_aminoacid eq $FOURD_CODONS{$member_seqstr{$seqid}->[$i]}) {
                    #print STDERR "YES ",$FOURD_CODONS{$member_seqstr{$seqid}->[$i]}," ",$member_seqstr{$seqid}->[$i],"\n";
                    next;
                } elsif (defined $FourD_aminoacid) {
                    #print STDERR "NO ",$FOURD_CODONS{$member_seqstr{$seqid}->[$i]}," ",$member_seqstr{$seqid}->[$i],"\n";
                    $FourD_codon = 0;
                    last;
                } else {
                    $FourD_aminoacid = $FOURD_CODONS{$member_seqstr{$seqid}->[$i]};
                    #print STDERR $FOURD_CODONS{$member_seqstr{$seqid}->[$i]}," ",$member_seqstr{$seqid}->[$i]," ";
                }
                next;
            } else {
                #print STDERR "NO ",$CODONS{$member_seqstr{$seqid}->[$i]}," ",$member_seqstr{$seqid}->[$i],"\n";
                $FourD_codon = 0;
                last;
            }
        }
        next unless ($FourD_codon);
        foreach my $seqid (keys %member_seqstr) {
            $FourD_member_seqstr{$seqid} .= substr($member_seqstr{$seqid}->[$i],2,1);
        }
    }

    foreach my $seqid (keys %FourD_member_seqstr) {

        my $seq = Bio::LocatableSeq->new(
                -SEQ    => $FourD_member_seqstr{$seqid},
                -START  => 1,
                -END    => length($FourD_member_seqstr{$seqid}),
                -ID     => $seqid,
                -STRAND => 0
        );

        if($bio07) {
            $sa->addSeq($seq);
        } else {
            $sa->add_seq($seq);
        }
    }

    return $sa;
}

my %matrix_hash;

{
  my $BLOSUM62 = "#  Matrix made by matblas from blosum62.iij
#  * column uses minimum score
#  BLOSUM Clustered Scoring Matrix in 1/2 Bit Units
#  Blocks Database = /data/blocks_5.0/blocks.dat
#  Cluster Percentage: >= 62
#  Entropy =   0.6979, Expected =  -0.5209
   A  R  N  D  C  Q  E  G  H  I  L  K  M  F  P  S  T  W  Y  V  B  Z  X  *
A  4 -1 -2 -2  0 -1 -1  0 -2 -1 -1 -1 -1 -2 -1  1  0 -3 -2  0 -2 -1  0 -4
R -1  5  0 -2 -3  1  0 -2  0 -3 -2  2 -1 -3 -2 -1 -1 -3 -2 -3 -1  0 -1 -4
N -2  0  6  1 -3  0  0  0  1 -3 -3  0 -2 -3 -2  1  0 -4 -2 -3  3  0 -1 -4
D -2 -2  1  6 -3  0  2 -1 -1 -3 -4 -1 -3 -3 -1  0 -1 -4 -3 -3  4  1 -1 -4
C  0 -3 -3 -3  9 -3 -4 -3 -3 -1 -1 -3 -1 -2 -3 -1 -1 -2 -2 -1 -3 -3 -2 -4
Q -1  1  0  0 -3  5  2 -2  0 -3 -2  1  0 -3 -1  0 -1 -2 -1 -2  0  3 -1 -4
E -1  0  0  2 -4  2  5 -2  0 -3 -3  1 -2 -3 -1  0 -1 -3 -2 -2  1  4 -1 -4
G  0 -2  0 -1 -3 -2 -2  6 -2 -4 -4 -2 -3 -3 -2  0 -2 -2 -3 -3 -1 -2 -1 -4
H -2  0  1 -1 -3  0  0 -2  8 -3 -3 -1 -2 -1 -2 -1 -2 -2  2 -3  0  0 -1 -4
I -1 -3 -3 -3 -1 -3 -3 -4 -3  4  2 -3  1  0 -3 -2 -1 -3 -1  3 -3 -3 -1 -4
L -1 -2 -3 -4 -1 -2 -3 -4 -3  2  4 -2  2  0 -3 -2 -1 -2 -1  1 -4 -3 -1 -4
K -1  2  0 -1 -3  1  1 -2 -1 -3 -2  5 -1 -3 -1  0 -1 -3 -2 -2  0  1 -1 -4
M -1 -1 -2 -3 -1  0 -2 -3 -2  1  2 -1  5  0 -2 -1 -1 -1 -1  1 -3 -1 -1 -4
F -2 -3 -3 -3 -2 -3 -3 -3 -1  0  0 -3  0  6 -4 -2 -2  1  3 -1 -3 -3 -1 -4
P -1 -2 -2 -1 -3 -1 -1 -2 -2 -3 -3 -1 -2 -4  7 -1 -1 -4 -3 -2 -2 -1 -2 -4
S  1 -1  1  0 -1  0  0  0 -1 -2 -2  0 -1 -2 -1  4  1 -3 -2 -2  0  0  0 -4
T  0 -1  0 -1 -1 -1 -1 -2 -2 -1 -1 -1 -1 -2 -1  1  5 -2 -2  0 -1 -1  0 -4
W -3 -3 -4 -4 -2 -2 -3 -2 -2 -3 -2 -3 -1  1 -4 -3 -2 11  2 -3 -4 -3 -2 -4
Y -2 -2 -2 -3 -2 -1 -2 -3  2 -1 -1 -2 -1  3 -3 -2 -2  2  7 -1 -3 -2 -1 -4
V  0 -3 -3 -3 -1 -2 -2 -3 -3  3  1 -2  1 -1 -2 -2  0 -3 -1  4 -3 -2 -1 -4
B -2 -1  3  4 -3  0  1 -1  0 -3 -4  0 -3 -3 -2  0 -1 -4 -3 -3  4  1 -1 -4
Z -1  0  0  1 -3  3  4 -2  0 -3 -3  1 -1 -3 -1  0 -1 -3 -2 -2  1  4 -1 -4
X  0 -1 -1 -1 -2 -1 -1 -1 -1 -1 -1 -1 -1 -1 -2  0  0 -2 -1 -1 -1 -1 -1 -4
* -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4 -4  1
";
  my $matrix_string;
  my @lines = split(/\n/,$BLOSUM62);
  foreach my $line (@lines) {
    next if ($line =~ /^\#/);
    if ($line =~ /^[A-Z\*\s]+$/) {
      $matrix_string .= sprintf "$line\n";
    } else {
      my @t = split(/\s+/,$line);
      shift @t;
      #       print scalar @t,"\n";
      $matrix_string .= sprintf(join(" ",@t)."\n");
    }
  }

#  my %matrix_hash;
  @lines = ();
  @lines = split /\n/, $matrix_string;
  my $lts = shift @lines;
  $lts =~ s/^\s+//;
  $lts =~ s/\s+$//;
  my @letters = split /\s+/, $lts;

  foreach my $letter (@letters) {
    my $line = shift @lines;
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    my @penalties = split /\s+/, $line;
    die "Size of letters array and penalties array are different\n"
      unless (scalar @letters == scalar @penalties);
    for (my $i=0; $i < scalar @letters; $i++) {
      $matrix_hash{uc $letter}{uc $letters[$i]} = $penalties[$i];
    }
  }
}


sub update_alignment_stats {
    my $self = shift;

    my $genes = $self->get_all_Members;
    my $ngenes = scalar(@$genes);

    if ($ngenes == 2) {
        # This code is >4 times faster with pairs of genes

        my $gene1 = $genes->[0];
        my $gene2 = $genes->[1];
        my $new_aln1_cigarline = "";
        my $new_aln2_cigarline = "";

        my $identical_matches = 0;
        my $positive_matches = 0;

        my ($aln1state, $aln2state);
        my ($aln1count, $aln2count);
        my ($aln1cov, $aln2cov) = (0,0);

        my @aln1 = split(//, $gene1->alignment_string);
        my @aln2 = split(//, $gene2->alignment_string);

        for (my $i=0; $i <= $#aln1; $i++) {
            next if ($aln1[$i] eq '-' && $aln2[$i] eq '-');
            my $cur_aln1state = ($aln1[$i] eq '-' ? 'D' : 'M');
            my $cur_aln2state = ($aln2[$i] eq '-' ? 'D' : 'M');
            $aln1cov++ if $cur_aln1state ne 'D';
            $aln2cov++ if $cur_aln2state ne 'D';
            if ($cur_aln1state eq 'M' && $cur_aln2state eq 'M') {
                if ($aln1[$i] eq $aln2[$i]) {
                    $identical_matches++;
                    $positive_matches++;
                } elsif ($matrix_hash{uc $aln1[$i]}{uc $aln2[$i]} > 0) {
                    $positive_matches++;
                }
            }
            unless (defined $aln1state) {
                $aln1count = 1;
                $aln2count = 1;
                $aln1state = $cur_aln1state;
                $aln2state = $cur_aln2state;
                next;
            }
            if ($cur_aln1state eq $aln1state) {
                $aln1count++;
            } else {
                if ($aln1count == 1) {
                    $new_aln1_cigarline .= $aln1state;
                } else {
                    $new_aln1_cigarline .= $aln1count.$aln1state;
                }
                $aln1count = 1;
                $aln1state = $cur_aln1state;
            }
            if ($cur_aln2state eq $aln2state) {
                $aln2count++;
            } else {
                if ($aln2count == 1) {
                    $new_aln2_cigarline .= $aln2state;
                } else {
                    $new_aln2_cigarline .= $aln2count.$aln2state;
                }
                $aln2count = 1;
                $aln2state = $cur_aln2state;
            }
        }
        if ($aln1count == 1) {
            $new_aln1_cigarline .= $aln1state;
        } else {
            $new_aln1_cigarline .= $aln1count.$aln1state;
        }
        if ($aln2count == 1) {
            $new_aln2_cigarline .= $aln2state;
        } else {
            $new_aln2_cigarline .= $aln2count.$aln2state;
        }
        my $seq_length1 = $gene1->seq_length;
        unless (0 == $seq_length1) {
            $gene1->cigar_line($new_aln1_cigarline);
            $gene1->perc_id( int((100.0 * $identical_matches / $seq_length1 + 0.5)) );
            $gene1->perc_pos( int((100.0 * $positive_matches  / $seq_length1 + 0.5)) );
            $gene1->perc_cov( int((100.0 * $aln1cov / $seq_length1 + 0.5)) );
        }
        my $seq_length2 = $gene2->seq_length;
        unless (0 == $seq_length2) {
            $gene2->cigar_line($new_aln2_cigarline);
            $gene2->perc_id( int((100.0 * $identical_matches / $seq_length2 + 0.5)) );
            $gene2->perc_pos( int((100.0 * $positive_matches  / $seq_length2 + 0.5)) );
            $gene2->perc_cov( int((100.0 * $aln2cov / $seq_length2 + 0.5)) );
        }
        return undef;
    }

    my $min_seq = shift;
    $min_seq = int($min_seq * $ngenes) if $min_seq <= 1;

    my @new_cigars   = ('') x $ngenes;
    my @nmatch_id    = (0) x $ngenes; 
    my @nmatch_pos   = (0) x $ngenes; 
    my @nmatch_cov   = (0) x $ngenes; 
    my @alncount     = (1) x $ngenes;
    my @alnstate     = (undef) x $ngenes;
    my @cur_alnstate = (undef) x $ngenes;

    my @aln = map {$_->alignment_string} @$genes;
    my $aln_length = length($aln[0]);

    for (my $i=0; $i < $aln_length; $i++) {

        my @char_i =  map {substr($_, $i, 1)} @aln;
        #print "pos $i: ", join('/', @char_i), "\n";

        my %seen;
        map {$seen{$_}++} @char_i;
        next if $seen{'-'} == $ngenes;
        delete $seen{'-'};
        
        my %pos_chars = ();
        my @chars = keys %seen;
        while (my $c1 = shift @chars) {
            foreach my $c2 (@chars) {
                if (($matrix_hash{uc $c1}{uc $c2} > 0) and ($seen{$c1}+$seen{$c2} >= $min_seq)) {
                    $pos_chars{$c1} = 1;
                    $pos_chars{$c2} = 1;
                }
            }
        }

        for (my $j=0; $j<$ngenes; $j++) {
            if ($char_i[$j] eq '-') {
                $cur_alnstate[$j] = 'D';
            } else {
                $nmatch_cov[$j]++;
                $cur_alnstate[$j] = 'M';
                if ($seen{$char_i[$j]} >= $min_seq) {
                    $nmatch_id[$j]++;
                    $nmatch_pos[$j]++;
                } elsif (exists $pos_chars{$char_i[$j]}) {
                    $nmatch_pos[$j]++;
                }
            }
        }

        if ($i == 0) {
            @alnstate = @cur_alnstate;
            next;
        }

        for (my $j=0; $j<$ngenes; $j++) {
            if ($cur_alnstate[$j] eq $alnstate[$j]) {
                $alncount[$j]++;
            } else {
                if ($alncount[$j] == 1) {
                    $new_cigars[$j] .= $alnstate[$j];
                } else {
                    $new_cigars[$j] .= $alncount[$j].$alnstate[$j];
                }
                $alncount[$j] = 1;
                $alnstate[$j] = $cur_alnstate[$j];
            }
        }
    }

    for (my $j=0; $j<$ngenes; $j++) {
        if ($alncount[$j] == 1) {
            $new_cigars[$j] .= $alnstate[$j];
        } else {
            $new_cigars[$j] .= $alncount[$j].$alnstate[$j];
        }
        $genes->[$j]->cigar_line($new_cigars[$j]);
        my $seq_length = $genes->[$j]->seq_length;
        unless (0 == $seq_length) {
            $genes->[$j]->perc_id( int((100.0 * $nmatch_id[$j] / $seq_length + 0.5)) );
            $genes->[$j]->perc_pos( int((100.0 * $nmatch_pos[$j] / $seq_length + 0.5)) );
            $genes->[$j]->perc_cov( int((100.0 * $nmatch_cov[$j] / $seq_length + 0.5)) );
        }
    }
}



1;
