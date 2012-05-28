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
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;

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

sub method_link_type {
    my $self = shift;

    return $self->method_link_species_set->method->type() if defined $self->{'_method_link_species_set_id'};
}


=head2 method_link_id

    DEPRECATED. Use method_link_species_set()->method()->dbID() instead. This is not a setter any more.

=cut

sub method_link_id {
    my $self = shift;

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



=head2 get_all_GeneMembers

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
  foreach my $aligned_member (@{$self->get_all_AlignedMember}) {
    push @$members, $aligned_member->gene_member if defined $aligned_member->gene_member;
  }

  return $members;
}



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


1;
