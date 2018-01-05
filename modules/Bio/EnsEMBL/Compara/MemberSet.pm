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

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 NAME

MemberSet - A superclass for pairwise or multiple gene relationships

=head1 DESCRIPTION

A superclass for pairwise and multiple gene relationships

MemberSet is the deepest base class of Bio::EnsEMBL::Compara::Family, Bio::EnsEMBL::Compara::Homology and Bio::EnsEMBL::Compara::GeneTree

It holds the methods to construct / use a set of Bio::EnsEMBL::Compara::Member
Currently the Member objects are used in the GeneTree structure
to represent the leaves of the trees. Each leaf contains an aligned
sequence, which is represented as an Member object.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::MemberSet

=head1 SYNOPSIS

Global properties of the set:
 - stable_id() and version()
 - description()
 - method_link_species_set()

Be aware that not all of the above methods are implemented in all the derived objects (for instance, Homologies do not have stable_id)

The set of members can be accessed / edited with:
 - add_Member()
 - get_all_Members()
 - get_all_GeneMembers()
 - clear()
 - get_Member_by_*() and Member_count_by_*()

I/O:
 - print_sequences_to_file()

Methods about the set of species refered to by the members:
 - get_all_taxa_by_member_source_name()
 - get_all_GenomeDBs_by_member_source_name()
 - has_species_by_name()

=head1 METHODS

=cut

package Bio::EnsEMBL::Compara::MemberSet;

use strict;
use warnings;

use Scalar::Util qw(weaken);

use Bio::SeqIO;

use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Scalar qw(:all);
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Utils::Preloader;

use base ('Bio::EnsEMBL::Storable');        # inherit dbID(), adaptor() and new() methods



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

    my $self = $class->SUPER::new(@args);       # deal with Storable stuff

    if (scalar @args) {
        #do this explicitly.
        my ($stable_id, $version, $method_link_species_set_id, $description, $members)
            = rearrange([qw(STABLE_ID VERSION METHOD_LINK_SPECIES_SET_ID DESCRIPTION MEMBERS)], @args);

        $stable_id && $self->stable_id($stable_id);
        $version && $self->version($version);
        $description && $self->description($description);
        $method_link_species_set_id && $self->method_link_species_set_id($method_link_species_set_id);
        if ($members) {
            $self->clear;
            foreach my $member (@$members) {
                $self->add_Member($member);
            }
        }
    }

    return $self;
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
        assert_ref($mlss, 'Bio::EnsEMBL::Compara::MethodLinkSpeciesSet', 'mlss');
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
    return qw(dbID adaptor _version _stable_id _description _method_link_species_set_id);
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
        $copy->{$attr} = $self->{$attr} if exists $self->{$attr};;
    }

    foreach my $member (@{$self->get_all_Members}) {
        $copy->add_Member($member->copy());
    }

    return $copy;
}


=head2 add_Member

  Arg [1]    : Bio::EnsEMBL::Compara::Member $member
  Example    : $gene_tree->add_Member($member);
  Description: Add a new Member to this set
  Returntype : none
  Exceptions : Throws if input objects don't check
  Caller     : general
  Status     : Stable

=cut

sub add_Member {
    my ($self, $member) = @_;

    assert_ref($member, $self->member_class, 'member');
    my $source_name = $member->source_name() || 'NA';
    my $taxon_id = $member->taxon_id() || 'NA';
    my $genome_db_id = $member->genome_db_id() || 'NA';
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


=head2 remove_Member

  Arg [1]    : Bio::EnsEMBL::Compara::Member $member
  Example    : $gene_tree->remove_Member($member);
  Description: Remove a new Member from this set
  Returntype : none
  Exceptions : Throws if input objects don't check
  Caller     : general
  Status     : Stable

=cut

sub remove_Member {
    my ($self, $member) = @_;

    assert_ref($member, $self->member_class, 'member');
    my $source_name = $member->source_name() || 'NA';
    my $taxon_id = $member->taxon_id() || 'NA';
    my $genome_db_id = $member->genome_db_id() || 'NA';

    $self->{'_member_array'} = [grep {$_ ne $member} @{$self->{'_member_array'}}];
    $self->{'_members_by_source'}{$source_name} = [grep {$_ ne $member} @{$self->{'_members_by_source'}{$source_name}}];
    $self->{'_members_by_source_taxon'}{"${source_name}_${taxon_id}"} = [grep {$_ ne $member} @{$self->{'_members_by_source_taxon'}{"${source_name}_${taxon_id}"}}];
    $self->{'_members_by_genome_db'}{$genome_db_id} = [grep {$_ ne $member} @{$self->{'_members_by_genome_db'}{$genome_db_id}}];
    $self->{'_members_by_source_genome_db'}{"${source_name}_${genome_db_id}"} = [grep {$_ ne $member} @{$self->{'_members_by_source_genome_db'}{"${source_name}_${genome_db_id}"}}];
}


=head2 get_all_Members

  Example    : 
  Description: Returns all the members in this set
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
            $members = $self->adaptor->db->get_MemberAdaptor->fetch_all_by_MemberSet($self);
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


=head2 get_all_GeneMembers

  Arg [1]    : (optional) genome db id 
  Example    : my $gene_members = $ortholog->get_all_GeneMembers($genome_db->dbID')
  Example    : my $gene_members = $ortholog->get_all_GeneMembers($genome_db->dbID)
  Description: 
  Returntype : array reference of Bio::EnsEMBL::Compara::Member
  Exceptions : 
  Caller     : public

=cut

sub get_all_GeneMembers {
    my ($self,$genome_db_id) = @_;

    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_GeneMembers($self->adaptor->db->get_GeneMemberAdaptor, $self->get_all_Members);

    my %seen_gene_members = ();
    foreach my $member (@{$self->get_all_Members}) {
        next unless $member->gene_member_id;
        die "Cannot find the GeneMember of ".$member->stable_id unless $member->gene_member;

        # The genome_db_id is not the one requested
        next if ((defined $genome_db_id) and ($member->genome_db_id != $genome_db_id));

        $seen_gene_members{$member->gene_member_id} = $member->gene_member;
    }

    return [values %seen_gene_members];
}


=head2 gene_list

  Example    : my $pair = $homology->gene_list
  Description: return the pair of members for the homology
  Returntype : array ref of (2) Bio::EnsEMBL::Compara::Member objects
  Caller     : general

=cut

sub gene_list {  # DEPRECATED ?
    my $self = shift;
    return $self->get_all_GeneMembers
}


=head2 print_sequences_to_file

  Arg [1]     : scalar (string or file handle) - output file
  Arg [-FORMAT]   : string - format of the output (cf BioPerl capabilities) (example: 'fasta')
  Arg [-UNIQ_SEQ] : boolean - whether only 1 copy of each sequence should be printed
                    (when multiple proteins share the same sequence)
  Arg [...]  : all the other arguments of SeqMember::bioseq()
  Example    : $family->print_sequences_to_file(-file => 'output.fa', -format => 'fasta', -id_type => 'MEMBER');
  Description: Prints the sequences of the members into a file
  Returntype : number of unique sequences in the set
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut

sub print_sequences_to_file {
    my ($self, $file, @args) = @_;
    my ($format, $unique_seqs, $seq_type) = rearrange([qw(FORMAT UNIQ_SEQ SEQ_TYPE)], @args);

    my $seqio = Bio::SeqIO->new( ref($file) ? (-fh => $file) : (-file => ">$file"), -format => $format );

    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences($self->adaptor->db->get_SequenceAdaptor, $seq_type, $self) if ( $self->adaptor );

    my %seq_hash = ();
    foreach my $member (@{$self->get_all_Members}) {
        next unless $member->isa('Bio::EnsEMBL::Compara::SeqMember');

        my $bioseq = $member->bioseq(@args);
        next if $unique_seqs and $seq_hash{$bioseq->seq};
        $seq_hash{$bioseq->seq} = 1;

        $seqio->write_seq($bioseq);
    }
    return scalar(keys %seq_hash);
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
  Example    : $family->get_Member_by_source_taxon('ENSEMBLPEP',9606)
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
  Example    : $family->get_Member_by_GenomeDB($genome_db)
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
    assert_ref($genome_db, 'Bio::EnsEMBL::Compara::GenomeDB', 'genome_db');
    my ($scope, $key) = ('_members_by_genome_db', $genome_db->dbID());
    return $self->_get_Member($scope, $key);
}

=head2 get_Member_by_source_GenomeDB

  Arg [1]    : string $source_name
  Arg [2]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Example    : $family->get_Member_by_source_taxon('ENSEMBLPEP', $genome_db)
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
    assert_ref($genome_db, 'Bio::EnsEMBL::Compara::GenomeDB', 'genome_db');
    my ($scope, $key) = ('_members_by_source_genome_db', "${source_name}_".$genome_db->dbID());
    return $self->_get_Member($scope, $key);
}

=head2 _get_Member

  Arg [1]    : string $scope
  Arg [2]    : string $key
  Example    : $family->_get_Member('_members_by_source', 'ENSEMBLPEP')
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
  Example    : $family->Member_count_by_source('ENSEMBLPEP');
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
