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
 - dbID()
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

use base qw(Bio::EnsEMBL::Compara::Locus Bio::EnsEMBL::Storable);


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
    my ($dbid, $stable_id, $description, $source_name, $adaptor, $taxon_id, $genome_db_id)
        = rearrange([qw(DBID STABLE_ID DESCRIPTION SOURCE_NAME ADAPTOR TAXON_ID GENOME_DB_ID)], @args);

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



#
# Global methods
###################




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


1;
