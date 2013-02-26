=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
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

MemberSet - A superclass for pairwise or multiple relationships, base of
Bio::EnsEMBL::Compara::Family, Bio::EnsEMBL::Compara::Homology and
Bio::EnsEMBL::Compara::Domain.

=head1 DESCRIPTION

A superclass for pairwise and multiple relationships

Currently the Member objects are used in the GeneTree structure
to represent the leaves of the trees. Each leaf contains an aligned
sequence, which is represented as an Member object.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::MemberSet

=head1 METHODS

=cut

package Bio::EnsEMBL::Compara::MemberSet;

use strict;
use Scalar::Util qw(weaken);
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Scalar qw(:all);
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Compara::Member;


####################################
#                                  #
#  Constructor, getters / setters  #
#                                  #
####################################


=head2 new

  Arg [-DBID]  : 
       int - internal ID for this object
  Arg [-ADAPTOR]:
        Bio::EnsEMBL::Compara::DBSQL::MemberSetAdaptor - the object adaptor
  Arg [-STABLE_ID] :
        string - the stable identifier of this object
  Arg [-VERSION] :
        int - the version of the stable identifier of this object
  Arg [-METHOD_LINK_SPECIES_SET_ID] :
        int - the internal ID for the MethodLinkSpeciesSet object
  Arg [-DESCRIPTION]:
        string - the description for the object
  Example    : $family = Bio::EnsEMBL::Compara::MemberSet->new(...);
  Description: Creates a new MemberSet object
  Returntype : Bio::EnsEMBL::Compara::MemberSet
  Exceptions : none
  Caller     : subclass->new
  Status     : Stable

=cut

sub new {
    my ($class, @args) = @_;

    my $self = bless {}, $class;

    if (scalar @args) {
        #do this explicitly.
        my ($dbid, $stable_id, $version, $method_link_species_set_id, $description, $adaptor, $members)
            = rearrange([qw(DBID STABLE_ID VERSION METHOD_LINK_SPECIES_SET_ID DESCRIPTION ADAPTOR MEMBERS)], @args);

        $dbid && $self->dbID($dbid);
        $stable_id && $self->stable_id($stable_id);
        $version && $self->version($version);
        $description && $self->description($description);
        $method_link_species_set_id && $self->method_link_species_set_id($method_link_species_set_id);
        $adaptor && $self->adaptor($adaptor);
        if ($members) {
            $self->clear;
            foreach my $member (@$members) {
                $self->add_Member($member);
            }
        }
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
        assert_ref($mlss, 'Bio::EnsEMBL::Compara::MethodLinkSpeciesSet');
        $self->{'_method_link_species_set'} = $mlss;
        $self->{'_method_link_species_set_id'} = $mlss->dbID;

    } elsif (defined $self->{'_method_link_species_set_id'}) {
    #lazy load from method_link_species_set_id
        if ((not defined $self->{'_method_link_species_set'})
             or ($self->{'_method_link_species_set'}->dbID ne $self->{'_method_link_species_set_id'})) {
            my $mlssa = $self->adaptor->db->get_MethodLinkSpeciesSetAdaptor;
            my $mlss = $mlssa->fetch_by_dbID($self->method_link_species_set_id);
            $self->{'_method_link_species_set'} = $mlss;
        }
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
               this will be either GeneTreeAdaptor, FamilyAdaptor, or
               HomologyAdaptor
  Returntype : Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor object
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
#     Member content      #
#                         #
###########################

=head2 member_class

  Description: Returns the type of member used in the set
  Returntype : String: Bio::EnsEMBL::Compara::Member
  Caller     : general
  Status     : Stable

=cut

sub member_class {
    return 'Bio::EnsEMBL::Compara::Member';
}

=head2 _attr_to_copy_list

  Description: Returns the list of all the attributes to be copied by deep_copy()
  Returntype : Array of String
  Caller     : deep_copy()
  Status     : Stable

=cut

sub _attr_to_copy_list {
    return qw(_dbID _adaptor _version _stable_id _description _method_link_species_set_id);
}

=head2 deep_copy

  Description: Returns a copy of $self. All the members are themselves copied
  Returntype : Bio::EnsEMBL::Compara::MemberSet
  Caller     : general
  Status     : Stable

=cut

sub deep_copy {
    my $self = shift;
    my $copy = {};
    bless $copy, ref($self);

    foreach my $attr ($self->_attr_to_copy_list) {
        $copy->{$attr} = $self->{$attr};
    }

    foreach my $member (@{$self->get_all_Members}) {
        $copy->add_Member($member->copy());
    }

    return $copy;
}


=head2 add_Member

  Arg [1]    : Member
  Example    : 
  Description: Add a new Member to this set
  Returntype : none
  Exceptions : Throws if input objects don't check
  Caller     : general
  Status     : Stable

=cut

sub add_Member {
    my ($self, $member) = @_;

    assert_ref($member, $self->member_class);
    my $source_name = $member->source_name();
    my $taxon_id = $member->taxon_id();
    my $genome_db_id = $member->genome_db_id();
    #print "adding $source_name: ", $member->dbID, "\n";

    if (defined $self->{'_this_one_first'} && $self->{'_this_one_first'} eq $member->dbID) {
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


=head2 get_all_Members

  Arg [1]    : None
  Example    : 
  Description: 
  Returntype : array reference of Bio::EnsEMBL::Compara::Member
  Exceptions : 
  Caller     : 

=cut

sub get_all_Members {
    my ($self) = @_;
  
    unless (defined $self->{'_member_array'}) {

        return [] unless $self->adaptor;
        $self->clear;
        my $members;
        if ($self->isa('Bio::EnsEMBL::Compara::AlignedMemberSet')) {
            $members = $self->adaptor->db->get_AlignedMemberAdaptor->fetch_all_by_AlignedMemberSet($self);
        } else {
            my $members = $self->adaptor->db->get_MemberAdaptor->fetch_all_by_MemberSet($self);
        }
        foreach my $member (@{$members}) {
            $self->add_Member($member);
        }
    }
    return $self->{'_member_array'};
}


=head2 clear

  Arg [1]    : None
  Description: Clears the list of members

=cut

sub clear {
    my $self = shift;
    
    $self->{'_member_array'} = [];
    $self->{'_members_by_source'} = {};
    $self->{'_members_by_source_taxon'} = {};
    $self->{'_members_by_source_genome_db'} = {};
    $self->{'_members_by_genome_db'} = {};
} 


=head2 get_all_GeneMember

  Arg [1]    : None
  Example    : 
  Description: 
  Returntype : array reference of Bio::EnsEMBL::Compara::Member
  Exceptions : 
  Caller     : public

=cut

sub get_all_GeneMembers {
    my ($self) = @_;

    my $members = [];
    foreach my $aligned_member (@{$self->get_all_Members}) {
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
    return $self->get_all_GeneMembers
}


sub print_sequences_to_fasta {
    my ($self, $pep_file, $subset_header) = @_;
    my $pep_counter = 0;
    open PEP, ">$pep_file";
    foreach my $member (@{$self->get_all_Members}) {
        next if $member->source_name eq 'ENSEMBLGENE';
        my $member_stable_id = $member->stable_id;
        my $member_id = $member->member_id;
        my $seq = $member->sequence;

        if ($subset_header) {
            my $source_name = $member->source_name;
            my $genome_db_id = $member->genome_db_id || 0;
            my $description = $member->description;
            print PEP ">$source_name:$member_stable_id IDs:$genome_db_id:$member_id $description\n";
        } else {
            print PEP ">$member_id\n";
        }
        $seq =~ s/(.{72})/$1\n/g;
        chomp $seq;
        unless (defined($seq)) {
            my $set_id = $self->dbID;
            die "member $member_stable_id in MemberSet $set_id doesn't have a sequence";
        }
        print PEP $seq,"\n";
        $pep_counter++;
    }
    close PEP;
    return $pep_counter;
}


#################################
#                               #
#  Members per category  #
#                               #
#################################

=head2 get_Member_by_source

  Arg [1]    : string $source_name
               e.g. "ENSEMBLPEP"
  Example    : 
  Description: 
  Returntype : array reference of Bio::EnsEMBL::Compara::Member
  Exceptions : 
  Caller     : public

=cut

sub get_Member_by_source {
    my ($self, $source_name) = @_;
    throw("Should give defined source_name as arguments\n") unless (defined $source_name);
    my ($scope, $key) = ('_members_by_source', $source_name);
    return $self->_get_Member($scope, $key);
}

=head2 get_Member_by_source_taxon

  Arg [1]    : string $source_name
  Arg [2]    : int $taxon_id
  Example    : $domain->get_Member_by_source_taxon('ENSEMBLPEP',9606)
  Description: 
  Returntype : array reference of Bio::EnsEMBL::Compara::Member
  Exceptions : 
  Caller     : public

=cut

sub get_Member_by_source_taxon {
    my ($self, $source_name, $taxon_id) = @_;
    throw("Should give defined source_name and taxon_id as arguments\n") unless (defined $source_name && defined $taxon_id);
    my ($scope, $key) = ('_members_by_source_taxon', "${source_name}_${taxon_id}");
    return $self->_get_Member($scope, $key);
}

=head2 get_Member_by_GenomeDB

  Arg [1]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Example    : $domain->get_Member_by_GenomeDB($genome_db)
  Description: Returns all [Member] entries linked to this GenomeDB. 
               This will only return EnsEMBL based entries since UniProtKB 
               entries are not linked to a GenomeDB.
  Returntype : array reference of Bio::EnsEMBL::Compara::Member
  Exceptions : If input is undefined & genome db is not of expected type
  Caller     : public

=cut

sub get_Member_by_GenomeDB {
    my ($self, $genome_db) = @_;
    throw("Should give defined genome_db as an argument\n") unless defined $genome_db;
    assert_ref($genome_db, 'Bio::EnsEMBL::Compara::GenomeDB');
    my ($scope, $key) = ('_members_by_genome_db', $genome_db->dbID());
    return $self->_get_Member($scope, $key);
}

=head2 get_Member_by_source_GenomeDB

  Arg [1]    : string $source_name
  Arg [2]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Example    : $domain->get_Member_by_source_taxon('ENSEMBLPEP', $genome_db)
  Description: Returns all [Member] entries linked to this GenomeDB
               and the given source_name. This will only return EnsEMBL based 
               entries since UniProtKB entries are not linked to a GenomeDB.
  Returntype : array reference of Bio::EnsEMBL::Compara::Member
  Exceptions : If input is undefined & genome db is not of expected type
  Caller     : public

=cut

sub get_Member_by_source_GenomeDB {
    my ($self, $source_name, $genome_db) = @_;
    throw("Should give defined source_name & genome_db as arguments\n") unless defined $source_name && $genome_db;
    assert_ref($genome_db, 'Bio::EnsEMBL::Compara::GenomeDB');
    my ($scope, $key) = ('_members_by_source_genome_db', "${source_name}_".$genome_db->dbID());
    return $self->_get_Member($scope, $key);
}

=head2 _get_Member

  Arg [1]    : string $scope
  Arg [2]    : string $key
  Example    : $domain->_get_Member('_members_by_source', 'ENSEMBLPEP')
  Description: Used as the generic reference point for all 
               get_Memeber_by* methods. The method searches the given
               scope & if the values cannot be found will initalize that value
               to an empty array reference.
  Returntype : array reference of Bio::EnsEMBL::Compara::Member
  Exceptions : None.
  Caller     : internal

=cut

sub _get_Member {
    my ($self, $scope, $key) = @_;
    $self->get_all_Members();
    $self->{$scope}->{$key} = [] unless defined $self->{$scope}->{$key};
    return $self->{$scope}->{$key};
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

    return scalar @{$self->get_Member_by_source($source_name)};
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

    return scalar @{$self->get_Member_by_source_taxon($source_name,$taxon_id)};
}

=head2 Member_count_by_GenomeDB

  Arg [1]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Example    : Member_count_by_GenomeDB($genome_db);
  Description: Convenience wrapper for member counts by a GenomeDB
  Returntype : int
  Exceptions : Thrown by subrountines this call. See get_Member
               equivalent
  Caller     : public

=cut

sub Member_count_by_GenomeDB {
    my ($self, $genome_db) = @_;
    return scalar @{$self->get_Member_by_GenomeDB($genome_db)};
}

=head2 Member_count_by_source_GenomeDB

  Arg [1]    : string $source_name
  Arg [2]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Example    : Member_count_by_source_GenomeDB('ENSEMBLPEP', $genome_db);
  Description: Convenience wrapper for member counts by a GenomeDB
  Returntype : int
  Exceptions : Thrown by subrountines this call. See get_Member
               equivalent
  Caller     : public

=cut


sub Member_count_by_source_GenomeDB {
    my ($self, $source_name, $genome_db) = @_;
    return scalar @{$self->get_Member_by_source_GenomeDB($source_name, $genome_db)};
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
    $self->get_all_Members;
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
    $self->get_all_Members;
    foreach my $key (keys %{$self->{_members_by_source_genome_db}}) {
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
  
  foreach my $member (@{$self->get_all_Members}) {
    return 1 if defined $member->genome_db and ($member->genome_db->name eq $species_name);
  }
  return 0;
}


1;
