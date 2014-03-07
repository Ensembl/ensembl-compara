=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

=head1 NAME

Bio::EnsEMBL::Compara::Member

=head1 DESCRIPTION

Abstract class to represent a biological (gene-related) object used
as part of other Compara structures (gene trees, gene families, homologies).
The (inherited) objects actually used are SeqMember and GeneMember, and Member
should not be directly used. Some methods are still available for compatibility
until release 75 (included).

A Member is a specialized Locus that deals with genes / gene products.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::Member
  `- Bio::EnsEMBL::Compara::Locus

=head1 SYNOPSIS

Member properties:
 - dbID() or member_id()
 - stable_id()
 - version()
 - display_label()
 - description()
 - source_name()
 - genome_db_id() and genome_db()
 - taxon_id() and taxon()

You can print the summary of a Member with print_member()

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::Member;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Scalar qw(:assert);
use Bio::EnsEMBL::Gene;
use Bio::EnsEMBL::Compara::GenomeDB;

use Bio::EnsEMBL::Compara::SeqMember;
use Bio::EnsEMBL::Compara::GeneMember;

use base qw(Bio::EnsEMBL::Compara::Locus);

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

    if ($source_name) {
      if ($source_name eq 'ENSEMBLGENE') {
          bless $self, 'Bio::EnsEMBL::Compara::GeneMember';
      } else {
          bless $self, 'Bio::EnsEMBL::Compara::SeqMember';
      }
    }
    $dbid && $self->dbID($dbid);
    $stable_id && $self->stable_id($stable_id);
    $description && $self->description($description);
    $source_name && $self->source_name($source_name);
    $adaptor && $self->adaptor($adaptor);
    $taxon_id && $self->taxon_id($taxon_id);
    $genome_db_id && $self->genome_db_id($genome_db_id);
    $sequence_id && $self->sequence_id($sequence_id);
  }

  return $self;
}


=head2 copy

  Arg [1]    : object $parent_object (optional)
  Example    : my $member_copy = $member->copy();
  Description: copies the object, optionally by topping up a given structure (to support multiple inheritance)
  Returntype : Bio::EnsEMBL::Compara::Member
  Exceptions : none

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
  $mycopy->dnafrag_start($self->dnafrag_start);
  $mycopy->dnafrag_end($self->dnafrag_end);
  $mycopy->dnafrag_strand($self->dnafrag_strand);
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

  Arg [1]    : (opt) integer
  Description: alias for dbID()

=cut

sub member_id {
  my $self = shift;
  return $self->dbID(@_);
}


=head2 dbID

  Arg [1]    : (opt) integer
  Description: Getter/Setter for the internal database ID

=cut

sub dbID {
  my $self = shift;
  $self->{'_dbID'} = shift if(@_);
  return $self->{'_dbID'};
}


=head2 stable_id

  Arg [1]    : (opt) string
  Description: Getter/Setter for the stable ID

=cut

sub stable_id {
  my $self = shift;
  $self->{'_stable_id'} = shift if(@_);
  return $self->{'_stable_id'};
}


=head2 display_label

  Arg [1]    : (opt) string
  Description: Getter/Setter for the display label

=cut

sub display_label {
  my $self = shift;
  $self->{'_display_label'} = shift if(@_);
  return $self->{'_display_label'};
}


=head2 version

  Arg [1]    : (opt) int
  Description: Getter/Setter for the version of the stable ID

=cut

sub version {
  my $self = shift;
  $self->{'_version'} = shift if(@_);
  $self->{'_version'} = 0 unless(defined($self->{'_version'}));
  return $self->{'_version'};
}


=head2 description

  Arg [1]    : (opt) string
  Returntype : Getter/Setter for the description

=cut

sub description {
  my $self = shift;
  $self->{'_description'} = shift if(@_);
  return $self->{'_description'};
}


=head2 source_name

  Arg [1]    : (opt) string
  Description: Getter/Setter for the source of the member
               Genes should have ENSEMBLGENE
               ncRNAs should have ENSEMBLTRANS
               Peptides / Proteins should have ENSEMBLPEP or Uniprot/SPTREMBL or Uniprot/SWISSPROT

=cut

sub source_name {
  my $self = shift;
  $self->{'_source_name'} = shift if (@_);
  return $self->{'_source_name'};
}

=head2 adaptor

  Arg [1]    : (opt) instance of an adaptor in Bio::EnsEMBL::Compara::DBSQL
  Description: Getter/Setter for the database adaptor

=cut

sub adaptor {
  my $self = shift;
  $self->{'_adaptor'} = shift if(@_);
  return $self->{'_adaptor'};
}


=head2 dnafrag_id

  Arg [1]    : integer $dnafrag_id
  Example    : $dnafrag_id = $genomic_align->dnafrag_id;
  Example    : $genomic_align->dnafrag_id(134);
  Description: Getter/Setter for the attribute dnafrag_id. If no
               argument is given and the dnafrag_id is not defined, it tries to
               get the ID from other sources like the corresponding
               Bio::EnsEMBL::Compara::DnaFrag object or the database using the dnafrag_id
               of the Bio::EnsEMBL::Compara::Locus object.
               Use 0 as argument to clear this attribute.
  Returntype : integer
  Exceptions : thrown if $dnafrag_id does not match a previously defined
               dnafrag
  Warning    : warns if getting data from other sources fails.
  Caller     : object->methodname
  Status     : Stable

=cut


sub dnafrag_id {
    my $self = shift;
    if (@_) {
        $self->SUPER::dnafrag_id(@_);
        $self->{'dnafrag'} = $self->adaptor->db->get_DnaFragAdaptor->fetch_by_dbID($self->{'dnafrag_id'});
        $self->{'_chr_name'} = $self->{'dnafrag'}->name();
    } elsif (not $self->{'dnafrag_id'}) {
        $self->{'dnafrag_id'} = $self->dnafrag->dbID;
    }
    return $self->{'dnafrag_id'};
}


=head2 dnafrag

  Arg 1       : (optional) Bio::EnsEMBL::Compara::DnaFrag object
  Example     : $dnafrag = $locus->dnafrag;
  Description : Getter/setter for the Bio::EnsEMBL::Compara::DnaFrag object
                corresponding to this Bio::EnsEMBL::Compara::Locus object.
                If no argument is given, the dnafrag is not defined but
                both the dnafrag_id and the adaptor are, it tries
                to fetch the data using the dnafrag_id
  Returntype  : Bio::EnsEMBL::Compara::Dnafrag object
  Exceptions  : thrown if $dnafrag is not a Bio::EnsEMBL::Compara::DnaFrag
                object or if $dnafrag does not match a previously defined
                dnafrag_id
  Warning     : warns if getting data from other sources fails.
  Caller      : object->methodname

=cut


sub dnafrag {
    my $self = shift;
    if (@_) {
        $self->SUPER::dnafrag(@_);
        $self->{'dnafrag_id'} = $self->{'dnafrag'}->dbID();
        $self->{'_chr_name'} = $self->{'dnafrag'}->name();
    } elsif (not $self->{'dnafrag'}) {
        $self->{'dnafrag'} = $self->adaptor->db->get_DnaFragAdaptor->fetch_by_GenomeDB_and_name($self->{'_genome_db_id'}, $self->{'_chr_name'});
    }
    return $self->{'dnafrag'};
}


=head2 chr_name

  Arg [1]    : (opt) string
  Description: Getter/Setter for the chromosome (or scaffold, contig, etc) name

=cut

sub chr_name {
    my $self = shift;
    if (@_) {
        $self->{'_chr_name'} = shift;
        delete $self->{'dnafrag'};
        delete $self->{'dnafrag_id'};
    }
    return $self->{'_chr_name'};
}


=head2 chr_start

  Description: Alias for dnafrag_start()

=cut

sub chr_start {
  my $self = shift;
  #deprecate('chr_start() is deprecated and will be removed in e76. Use dnafrag_start() instead.');
  return $self->dnafrag_start(@_);
}


=head2 chr_end

  Description: Alias for dnafrag_end()

=cut

sub chr_end {
  my $self = shift;
  #deprecate('chr_end() is deprecated and will be removed in e76. Use dnafrag_end() instead.');
  return $self->dnafrag_end(@_);
}


=head2 chr_strand

  Description: Alias for dnafrag_strand()

=cut

sub chr_strand {
  my $self = shift;
  #deprecate('chr_strand() is deprecated and will be removed in e76. Use dnafrag_strand() instead.');
  return $self->dnafrag_strand(@_);
}


=head2 taxon_id

  Arg [1]    : (opt) integer
  Description: Getter/Setter for the taxon ID (cf the NCBI database) of the species containing that member

=cut

sub taxon_id {
    my $self = shift;
    $self->{'_taxon_id'} = shift if (@_);
    return $self->{'_taxon_id'};
}


=head2 taxon

  Arg [1]    : (opt) Bio::EnsEMBL::Compara::NCBITaxon
  Description: Getter/Setter for the NCBITaxon object refering to the species containing that member

=cut

sub taxon {
  my $self = shift;

  if (@_) {
    my $taxon = shift;
    assert_ref($taxon, 'Bio::EnsEMBL::Compara::NCBITaxon');
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


=head2 genome_db_id

  Arg [1]    : (opt) integer
  Description: Getter/Setter for the genomeDB ID of the species containing that member

=cut

sub genome_db_id {
    my $self = shift;
    $self->{'_genome_db_id'} = shift if (@_);
    return $self->{'_genome_db_id'};
}


=head2 genome_db

  Arg [1]    : (opt) Bio::EnsEMBL::Compara::GenomeDB
  Description: Getter/Setter for the genomeDB refering to the species containing that member

=cut

sub genome_db {
  my $self = shift;

  if (@_) {
    my $genome_db = shift;
    assert_ref($genome_db, 'Bio::EnsEMBL::Compara::GenomeDB');
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


=head2 sequence_exon_bounded

  Description: DEPRECATED. Use SeqMember::sequence_exon_bounded() instead

=cut

sub sequence_exon_bounded { # DEPRECATED
    my $self = shift;
    return $self->_wrap_method_seq('sequence_exon_bounded', @_);
}


sub _compose_sequence_exon_bounded { # DEPRECATED
    my $self = shift;
    return $self->_wrap_method_seq('_compose_sequence_exon_bounded', @_);
}


=head2

  Description: DEPRECATED. Use SeqMember::sequence_cds() instead

=cut

sub sequence_cds { # DEPRECATED
    my $self = shift;
    return $self->_wrap_method_seq('sequence_cds', @_);
}


=head2

  Description: DEPRECATED. Use SeqMember::sequence_exon_bounded() instead

=cut

sub get_exon_bounded_sequence { # DEPRECATED
    my $self = shift;
    return $self->_rename_method_seq('get_exon_bounded_sequence', 'sequence_exon_bounded', @_);
}


=head2

  Description: DEPRECATED. Use SeqMember::get_other_sequence() instead

=cut

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
            $self->dbID || -1,$self->chr_name,$self->dnafrag_start,$self->dnafrag_end);
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




=head2 get_canonical_Member

  Description: DEPRECATED. Use GeneMember::get_canonical_SeqMember() instead

=cut

sub get_canonical_Member { # DEPRECATED
    my $self = shift;
    return $self->_rename_method_gene('get_canonical_Member', 'get_canonical_SeqMember', @_);
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

use Bio::EnsEMBL::ApiVersion;

sub _text_warning {
    my $msg = shift;
    return
        "\n------------------ DEPRECATED ---------------------\n"
        . "$msg\n"
        . stack_trace_dump(5). "\n"
        . "You are using the version ".software_version()." of the API. The old methods / objects are available for compatibility until version 74 (included)\n"
        . "---------------------------------------------------\n";
}


sub _wrap_global_gene {
    my $self = shift;
    my $method = shift;
    warn _text_warning(qq{
        $method() should not be called from a Member / SeqMember namespaces, but from the GeneMember one. Please review your code and call $method() from the namespace Bio::EnsEMBL::Compara::GeneMember.
    });
    my $method_wrap = "Bio::EnsEMBL::Compara::GeneMember::$method";
    return $method_wrap->(@_);
}


sub _wrap_global_seq {
    my $self = shift;
    my $method = shift;
    warn _text_warning(qq{
        $method() should not be called from the Member / GeneMember namespaces, but from the SeqMember one. Please review your code and call $method() from the namespace Bio::EnsEMBL::Compara::SeqMember.
    });
    my $method_wrap = "Bio::EnsEMBL::Compara::SeqMember::$method";
    return $method_wrap->(@_);
}

sub _wrap_method_seq {
    my $self = shift;
    my $method = shift;
    if ($self->source_name eq 'ENSEMBLGENE') {
        die _text_warning(qq{
        $method() is not defined for genes. You may want to first call get_canonical_SeqMember() or get_all_SeqMembers() in order to have a SeqMember that will accept $method().
        });
    } else {
        warn _text_warning(qq{
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
        warn _text_warning(qq{
        $method() should be called on a GeneMember object. Please review your code and bless $self as a GeneMember (then, $method() will work).
        })
    } elsif ($self->source_name eq 'ENSEMBLPEP' or $self->source_name eq 'ENSEMBLTRANS') {
        warn _text_warning(qq{
        $method() should not be called on a protein / ncRNA, but on a gene. Perhaps You want to call $self->gene_member()->$method().
        });
    } else {
        warn _text_warning(qq{
        $method() should not be called on a non-Ensembl peptide (e.g. Uniprot entries). Now returning undef.
        });
        return undef;
    }
    my $method_wrap = "Bio::EnsEMBL::Compara::GeneMember::$method";
    return $method_wrap->($self->source_name eq 'ENSEMBLGENE' ? $self : $self->gene_member, @_);
}

sub _rename_method_gene {
    my $self = shift;
    my $method = shift;
    my $new_name = shift;
    if ($self->isa('Bio::EnsEMBL::Compara::GeneMember')) {
        warn _text_warning(qq{
        $method() is renamed to $new_name(). Please review your code and call $new_name() instead.
        });
    } elsif ($self->source_name eq 'ENSEMBLGENE') {
        warn _text_warning(qq{
        $method() is renamed to $new_name() and should be called on a GeneMember object. Please review your code: bless $self as a GeneMember, and use $new_name() instead.
        });
    } elsif ($self->source_name eq 'ENSEMBLPEP' or $self->source_name eq 'ENSEMBLTRANS') {
        warn _text_warning(qq{
        $method() is renamed to $new_name() and cannot be called on a protein / ncRNA. Perhaps you want to call $self->gene_member()->$new_name().
        });
    } else {
        warn _text_warning(qq{
        $method() should not be called on a non-Ensembl peptide (e.g. Uniprot entries). Now returning undef.
        });
        return undef;
    }
    my $method_wrap = "Bio::EnsEMBL::Compara::GeneMember::$new_name";
    return $method_wrap->($self->source_name eq 'ENSEMBLGENE' ? $self : $self->gene_member, @_);
}

sub _rename_method_seq {
    my $self = shift;
    my $method = shift;
    my $new_name = shift;
    if ($self->isa('Bio::EnsEMBL::Compara::SeqMember')) {
        warn _text_warning(qq{
        $method() is renamed to $new_name(). Please review your code and call $new_name() instead.
        });
    } elsif ($self->source_name ne 'ENSEMBLGENE') {
        warn _text_warning(qq{
        $method() is renamed to $new_name() and should be called on a SeqMember object. Please review your code: bless $self as a SeqMember, and use $new_name() instead.
        });
    } else {
        die _text_warning(qq{
        $method() is renamed to $new_name() and cannot be called on a gene. Perhaps you want to call $self->get_canonical_SeqMember()->$new_name().
        });
    }
    my $method_wrap = "Bio::EnsEMBL::Compara::SeqMember::$new_name";
    return $method_wrap->($self, @_);
}


##
##
## These methods calls the raw SQL methods in member adaptor
##
#########

sub number_of_families {
  my ($self) = @_;

  return $self->adaptor->families_for_member($self->stable_id);
}

sub has_GeneTree {
  my ($self) = @_;

  return $self->adaptor->member_has_GeneTree($self->stable_id);
}

sub has_GeneGainLossTree {
  my ($self) = @_;

  return $self->adaptor->member_has_GeneGainLossTree($self->stable_id);
}

sub number_of_orthologues {
  my ($self) = @_;

  return $self->adaptor->orthologues_for_member($self->stable_id);
}

sub number_of_paralogues {
  my ($self) = @_;

  return $self->adaptor->paralogues_for_member($self->stable_id);
}

sub number_of_homoeologues {
  my ($self) = @_;

  return $self->adaptor->homoeologues_for_member($self->stable_id);
}

1;
