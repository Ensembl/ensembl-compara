package Bio::EnsEMBL::Compara::Member;

use strict;
use Bio::Seq;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Gene;
use Bio::EnsEMBL::Compara::GenomeDB;

use Bio::EnsEMBL::Compara::SeqMember;
use Bio::EnsEMBL::Compara::GeneMember;


=head2 new (CONSTRUCTOR)

    Arg [-DBID] : (opt) 
        : int $dbID (the database internal ID for this object)
    Arg [-ADAPTOR] 
        : Bio::EnsEMBL::Compara::DBSQL::Member $adaptor
                (the adaptor for connecting to the database)
    Arg [-DESCRIPTION] (opt) 
         : string $description
    Arg [-SOURCE_NAME] (opt) 
         : string $source_name 
         (e.g., "ENSEMBLGENE", "ENSEMBLPEP", "Uniprot/SWISSPROT", "Uniprot/SPTREMBL")
    Arg [-TAXON_ID] (opt)
         : int $taxon_id
         (NCBI taxonomy id of the species)
    Arg [-GENOME_DB_ID] (opt)
        : int $genome_db_id
        (the $genome_db->dbID for a species in the database)
    Arg [-SEQUENCE_ID] (opt)
        : int $sequence_id
        (the $sequence_id for the sequence table in the database)
       Description: Creates a new Member object
       Returntype : Bio::EnsEMBL::Compara::Member
       Exceptions : none
       Caller     : general
       Status     : Stable

=cut

sub new {
  my ($class, @args) = @_;

  my $self = bless {}, $class;
  
  if (scalar @args) {
    #do this explicitly.
    my ($dbid, $stable_id, $description, $source_name, $adaptor, $taxon_id, $genome_db_id, $sequence_id)
        = rearrange([qw(DBID STABLE_ID DESCRIPTION SOURCE_NAME ADAPTOR TAXON_ID GENOME_DB_ID SEQUENCE_ID)], @args);

    $dbid && $self->dbID($dbid);
    $stable_id && $self->stable_id($stable_id);
    $description && $self->description($description);
    $source_name && $self->source_name($source_name);
    $adaptor && $self->adaptor($adaptor);
    $taxon_id && $self->taxon_id($taxon_id);
    $genome_db_id && $self->genome_db_id($genome_db_id);
    $sequence_id && $self->sequence_id($sequence_id);
  }
  if ($self->source_name) {
    if ($self->source_name eq 'ENSEMBLGENE') {
        bless $self, 'Bio::EnsEMBL::Compara::GeneMember';
    } else {
        bless $self, 'Bio::EnsEMBL::Compara::SeqMember';
    }
  }

  return $self;
}


=head2 copy

  Arg [1]    : object $parent_object (optional)
  Example    :
  Description: copies the object, optionally by topping up a given structure (to support multiple inheritance)
  Returntype :
  Exceptions :
  Caller     :

=cut

sub copy {
  my $self = shift;
  
  my $mycopy = @_ ? shift : {};
  bless $mycopy, ref($self);
  
  $mycopy->dbID($self->dbID);
  $mycopy->stable_id($self->stable_id);
  $mycopy->description($self->description);
  $mycopy->source_name($self->source_name);
  #$mycopy->adaptor($self->adaptor);
  $mycopy->chr_name($self->chr_name);
  $mycopy->chr_start($self->chr_start);
  $mycopy->chr_end($self->chr_end);
  $mycopy->chr_strand($self->chr_strand);
  $mycopy->taxon_id($self->taxon_id);
  $mycopy->genome_db_id($self->genome_db_id);
  $mycopy->display_label($self->display_label);
  
  return $mycopy;
}


=head2 new_fast

  Arg [1]    : hash reference $hashref
  Example    : none
  Description: This is an ultra fast constructor which requires knowledge of
               the objects internals to be used.
  Returntype :
  Exceptions : none
  Caller     :

=cut

sub new_fast {
  my ($class, $hashref) = @_;
  if ($hashref->{'_source_name'}) {
    if ($hashref->{'_source_name'} eq 'ENSEMBLGENE') {
        bless $hashref, 'Bio::EnsEMBL::Compara::GeneMember';
    } else {
        bless $hashref, 'Bio::EnsEMBL::Compara::SeqMember';
    }
  } else {
    bless $hashref, $class;
  }

  return $hashref;
}

=head2 new_from_gene

  Description: DEPRECATED. Use SeqMember::new_from_gene() instead

=cut

sub new_from_gene { # DEPRECATED
    my $class = shift;
    return $class->_wrap_global_gene('new_from_gene', @_);
}


=head2 new_from_transcript

  Description: DEPRECATED. Use SeqMember::new_from_transcript() instead

=cut

sub new_from_transcript { # DEPRECATED
    my $class = shift;
    return $class->_wrap_global_seq('new_from_transcript', @_);
}



### SECTION 3 ###
#
# Global methods
###################






=head2 member_id

  Arg [1]    : int $member_id (optional)
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub member_id {
  my $self = shift;
  return $self->dbID(@_);
}


=head2 dbID

  Arg [1]    : int $dbID (optional)
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub dbID {
  my $self = shift;
  $self->{'_dbID'} = shift if(@_);
  return $self->{'_dbID'};
}

=head2 stable_id

  Arg [1]    : string $stable_id (optional)
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub stable_id {
  my $self = shift;
  $self->{'_stable_id'} = shift if(@_);
  return $self->{'_stable_id'};
}

=head2 display_label

  Arg [1]    : string $display_label (optional)
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub display_label {
  my $self = shift;
  $self->{'_display_label'} = shift if(@_);
  return $self->{'_display_label'};
}

=head2 version

  Arg [1]    :
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub version {
  my $self = shift;
  $self->{'_version'} = shift if(@_);
  $self->{'_version'} = 0 unless(defined($self->{'_version'}));
  return $self->{'_version'};
}

=head2 description

  Arg [1]    : string $description (optional)
  Example    :
  Description:
  Returntype : string
  Exceptions :
  Caller     :

=cut

sub description {
  my $self = shift;
  $self->{'_description'} = shift if(@_);
  return $self->{'_description'};
}

=head2 source_name

=cut

sub source_name {
  my $self = shift;
  $self->{'_source_name'} = shift if (@_);
  return $self->{'_source_name'};
}

=head2 adaptor

  Arg [1]    : string $adaptor (optional)
               corresponding to a perl module
  Example    :
  Description:
  Returntype :
  Exceptions :
  Caller     :

=cut

sub adaptor {
  my $self = shift;
  $self->{'_adaptor'} = shift if(@_);
  return $self->{'_adaptor'};
}


sub chr_name {
  my $self = shift;
  $self->{'_chr_name'} = shift if (@_);
  return $self->{'_chr_name'};
}


sub chr_start {
  my $self = shift;
  $self->{'_chr_start'} = shift if (@_);
  return $self->{'_chr_start'};
}


sub chr_end {
  my $self = shift;
  $self->{'_chr_end'} = shift if (@_);
  return $self->{'_chr_end'};
}

=head2 chr_strand

  Arg [1]    : integer
  Description: Returns the strand of the member.  Defined strands are 1 or -1.
               0 is undefined strand.
  Returntype : 1,0,-1
  Exceptions : none
  Caller     : general

=cut

sub chr_strand {
  my $self = shift;
  $self->{'_chr_strand'} = shift if (@_);
  $self->{'_chr_strand'}='0' unless(defined($self->{'_chr_strand'}));
  return $self->{'_chr_strand'};
}


sub taxon_id {
    my $self = shift;
    $self->{'_taxon_id'} = shift if (@_);
    return $self->{'_taxon_id'};
}


sub taxon {
  my $self = shift;

  if (@_) {
    my $taxon = shift;
    unless ($taxon->isa('Bio::EnsEMBL::Compara::NCBITaxon')) {
      throw(
		   "taxon arg must be a [Bio::EnsEMBL::Compara::NCBITaxon".
		   "not a [$taxon]");
    }
    $self->{'_taxon'} = $taxon;
    $self->taxon_id($taxon->ncbi_taxid);
  } else {
    unless (defined $self->{'_taxon'}) {
      unless (defined $self->taxon_id) {
        throw("can't fetch Taxon without a taxon_id");
      }
      my $NCBITaxonAdaptor = $self->adaptor->db->get_NCBITaxonAdaptor;
      $self->{'_taxon'} = $NCBITaxonAdaptor->fetch_node_by_taxon_id($self->taxon_id);
    }
  }

  return $self->{'_taxon'};
}


sub genome_db_id {
    my $self = shift;
    $self->{'_genome_db_id'} = shift if (@_);
    return $self->{'_genome_db_id'};
}


sub genome_db {
  my $self = shift;

  if (@_) {
    my $genome_db = shift;
    unless ($genome_db->isa('Bio::EnsEMBL::Compara::GenomeDB')) {
      throw(
		   "arg must be a [Bio::EnsEMBL::Compara::GenomeDB".
		   "not a [$genome_db]");
    }
    $self->{'_genome_db'} = $genome_db;
    $self->genome_db_id($genome_db->dbID);
  } else {
    unless (defined $self->{'_genome_db'}) {
      unless (defined $self->genome_db_id and defined $self->adaptor) {
        throw("can't fetch GenomeDB without an adaptor and genome_db_id");
      }
      my $GenomeDBAdaptor = $self->adaptor->db->get_GenomeDBAdaptor;
      $self->{'_genome_db'} = $GenomeDBAdaptor->fetch_by_dbID($self->genome_db_id);
    }
  }

  return $self->{'_genome_db'};
}











### SECTION 4 ###
#
# Sequence methods
#####################




=head2 sequence

  Description: DEPRECATED. Use SeqMember::sequence() instead

=cut

sub sequence { # DEPRECATED
    my $self = shift;
    return $self->_wrap_method_seq('sequence', @_);
}

=head2 sequence_exon_cased

  Description: DEPRECATED. Use SeqMember::sequence_exon_cased() instead

=cut

sub sequence_exon_cased { # DEPRECATED
    my $self = shift;
    return $self->_wrap_method_seq('sequence_exon_cased', @_);
}

sub sequence_exon_bounded { # DEPRECATED
    my $self = shift;
    return $self->_wrap_method_seq('sequence_exon_bounded', @_);
}


sub _compose_sequence_exon_bounded { # DEPRECATED
    my $self = shift;
    return $self->_wrap_method_seq('_compose_sequence_exon_bounded', @_);
}

sub sequence_cds { # DEPRECATED
    my $self = shift;
    return $self->_wrap_method_seq('sequence_cds', @_);
}

sub get_exon_bounded_sequence { # DEPRECATED
    my $self = shift;
    return $self->_wrap_method_seq('get_exon_bounded_sequence', @_);
}

sub get_other_sequence { # DEPRECATED
    my $self = shift;
    return $self->_wrap_method_seq('get_other_sequence', @_);
}


=head2 seq_length

  Description: DEPRECATED. Use SeqMember::seq_length() instead

=cut

sub seq_length { # DEPRECATED
    my $self = shift;
    return $self->_wrap_method_seq('seq_length', @_);
}


=head2 sequence_id

  Description: DEPRECATED. Use SeqMember::sequence_id() instead

=cut

sub sequence_id { # DEPRECATED
    my $self = shift;
    return $self->_wrap_method_seq('sequence_id', @_);
}

=head2 gene_member_id

  Description: DEPRECATED. Use SeqMember::gene_member_id() instead

=cut

sub gene_member_id { # DEPRECATED
    my $self = shift;
    return $self->_wrap_method_seq('gene_member_id', @_);
}


=head2 bioseq

  Description: DEPRECATED. Use SeqMember::bioseq() instead

=cut

sub bioseq { # DEPRECATED
    my $self = shift;
    return $self->_wrap_method_seq('bioseq', @_);
}

=head2 gene_member

  Description: DEPRECATED. Use SeqMember::gene_member() instead

=cut

sub gene_member { # DEPRECATED
    my $self = shift;
    return $self->_wrap_method_seq('gene_member', @_);
}




### SECTION 5 ###
#
# print a member
##################



=head2 print_member

  Example    : $member->print_member;
  Description: used for debugging, prints out key descriptive elements
               of member
  Returntype : none
  Exceptions : none
  Caller     : general

=cut

sub print_member {
    my $self = shift;

    printf("   %s %s(%d)\t%s : %d-%d\n",$self->source_name, $self->stable_id,
            $self->dbID,$self->chr_name,$self->chr_start, $self->chr_end);
}





### SECTION 6 ###
#
# connection to core
#####################





=head2 get_Gene

  Description: DEPRECATED. Use SeqMember::get_Gene() instead

=cut

sub get_Gene { # DEPRECATED
    my $self = shift;
    return $self->_wrap_method_gene('get_Gene', @_);
}

=head2 get_Transcript

  Description: DEPRECATED. Use SeqMember::get_Transcript() instead

=cut

sub get_Transcript { # DEPRECATED
    my $self = shift;
    return $self->_wrap_method_seq('get_Transcript', @_);
}


=head2 get_Translation

  Description: DEPRECATED. Use SeqMember::get_Translation() instead

=cut

sub get_Translation { # DEPRECATED
    my $self = shift;
    return $self->_wrap_method_seq('get_Translation', @_);
}



### SECTION 7 ###
#
# canonical transcripts
########################




=head2 get_canonical_SeqMember

  Description: DEPRECATED. Use GeneMember::get_canonical_SeqMember() instead

=cut

sub get_canonical_SeqMember { # DEPRECATED
    my $self = shift;
    return $self->_rename_method_gene('get_canonical_SeqMember', 'get_canonical_SeqMember', @_);
}


=head2 get_canonical_peptide_Member

  Description: DEPRECATED. Use GeneMember::get_canonical_SeqMember() instead

=cut

sub get_canonical_peptide_Member { # DEPRECATED
    my $self = shift;
    return $self->_rename_method_gene('get_canonical_peptide_Member', 'get_canonical_SeqMember', @_);
}


=head2 get_canonical_transcript_Member

  Description: DEPRECATED. Use GeneMember::get_canonical_SeqMember() instead

=cut

sub get_canonical_transcript_Member { # DEPRECATED
    my $self = shift;
    return $self->_rename_method_gene('get_canonical_transcript_Member', 'get_canonical_SeqMember', @_);
}


### SECTION 8 ###
#
# sequence links
####################




=head2 get_all_peptide_Members

  Description: DEPRECATED. Use GeneMember::get_all_SeqMembers() instead

=cut




sub get_all_peptide_Members { # DEPRECATED
    my $self = shift;
    return $self->_rename_method_gene('get_all_peptide_Members', 'get_all_SeqMembers', @_);
}





### SECTION 9 ###
#
# WRAPPERS
###########

no strict 'refs';

sub _wrap_global_gene {
    my $self = shift;
    my $method = shift;
    warning(qq{
        $method() should not be called from a Member / SeqMember namespaces, but from the GeneMember one. Please review your code and call $method() from the namespace Bio::EnsEMBL::Compara::GeneMember.
    });
    my $method_wrap = "Bio::EnsEMBL::Compara::GeneMember::$method";
    return $method_wrap->(@_);
}


sub _wrap_global_seq {
    my $self = shift;
    my $method = shift;
    warning(qq{
        $method() should not be called from the Member / GeneMember namespaces, but from the SeqMember one. Please review your code and call $method() from the namespace Bio::EnsEMBL::Compara::SeqMember.
    });
    my $method_wrap = "Bio::EnsEMBL::Compara::SeqMember::$method";
    return $method_wrap->(@_);
}

sub _wrap_method_seq {
    my $self = shift;
    my $method = shift;
    if ($self->source_name eq 'ENSEMBLGENE') {
        throw(qq{
        $method() is not defined for genes. You may want to first call get_canonical_SeqMember() or get_all_SeqMembers() in order to have a SeqMember that will accept $method().
        });
    } else {
        warning(qq{
        $method() should be called on a SeqMember object. Please review your code and bless $self as a SeqMember (then, $method() will work).
        })
    }
    my $method_wrap = "Bio::EnsEMBL::Compara::SeqMember::$method";
    return $method_wrap->($self, @_);
}

sub _wrap_method_gene {
    my $self = shift;
    my $method = shift;
    if ($self->source_name eq 'ENSEMBLGENE') {
        warning(qq{
        $method() should be called on a GeneMember object. Please review your code and bless $self as a GeneMember (then, $method() will work).
        })
    } else {
        warning(qq{
        $method() should not be called on a protein / ncRNA, but on a gene. Perhaps You want to call $self->gene_member()->$method().
        });
    }
    my $method_wrap = "Bio::EnsEMBL::Compara::GeneMember::$method";
    return $method_wrap->($self->source_name eq 'ENSEMBLGENE' ? $self : $self->gene_member, @_);
}

sub _rename_method_gene {
    my $self = shift;
    my $method = shift;
    my $new_name = shift;
    if ($self->isa('Bio::EnsEMBL::Compara::GeneMember')) {
        warning(qq{
        $method() is renamed to $new_name(). Please review your code and call $new_name() instead.
        });
    } elsif ($self->source_name eq 'ENSEMBLGENE') {
        warning(qq{
        $method() is renamed to $new_name() and should be called on a GeneMember object. Please review your code: bless $self as a GeneMember, and use $new_name() instead.
        });
    } else {
        warning(qq{
        $method() is renamed to $new_name() and cannot be called on a protein / ncRNA. Perhaps you want to call $self->gene_member()->$new_name().
        });
    }
    my $method_wrap = "Bio::EnsEMBL::Compara::GeneMember::$new_name";
    return $method_wrap->($self->source_name eq 'ENSEMBLGENE' ? $self : $self->gene_member, @_);
}



1;
