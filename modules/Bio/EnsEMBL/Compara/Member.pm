package Bio::EnsEMBL::Compara::Member;

use strict;
use Bio::Seq;
use Bio::EnsEMBL::Root;
use Bio::EnsEMBL::Gene;
use Bio::EnsEMBL::Compara::GenomeDB;

our @ISA = qw(Bio::EnsEMBL::Root);

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);

  if (scalar @args) {
    #do this explicitly.
    my ($dbid, $stable_id, $description, $source_id, $source_name, $adaptor, $taxon_id, $genome_db_id, $sequence_id) = $self->_rearrange([qw(DBID STABLE_ID DESCRIPTION SOURCE_ID SOURCE_NAME ADAPTOR TAXON_ID GENOME_DB_ID SEQUENCE_ID)], @args);

    $dbid && $self->dbID($dbid);
    $stable_id && $self->stable_id($stable_id);
    $description && $self->description($description);
    $source_id && $self->source_id($source_id);
    $source_name && $self->source_name($source_name);
    $adaptor && $self->adaptor($adaptor);
    $taxon_id && $self->taxon_id($taxon_id);
    $genome_db_id && $self->genome_db_id($genome_db_id);
    $sequence_id && $self->sequence_id($sequence_id);
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

=cut

sub new_fast {
  my ($class, $hashref) = @_;

  return bless $hashref, $class;
}

=head2 new_from_gene

  Args       : Requires both an Bio::Ensembl:Gene object and a
             : Bio::Ensembl:Compara:GenomeDB object
  Example    : $member = Bio::EnsEMBL::Compara::Member->new_from_gene(
                -gene   => $gene,
                -genome_db => $genome_db);
  Description: contructor method which takes an Ensembl::Gene object
               and Compara:GenomeDB object and creates a new Member object
               translating from the Gene object
  Returntype : Bio::Ensembl::Compara::Member
  Exceptions :
  Caller     :

=cut

sub new_from_gene {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);

  if (scalar @args) {

    my ($gene, $genome_db) = $self->_rearrange([qw(GENE GENOME_DB)], @args);

    unless(defined($gene) and $gene->isa('Bio::EnsEMBL::Gene')) {
      $self->throw(
      "gene arg must be a [Bio::EnsEMBL::Gene] ".
      "not a [$gene]");
    }
    unless(defined($genome_db) and $genome_db->isa('Bio::EnsEMBL::Compara::GenomeDB')) {
      $self->throw(
      "genome_db arg must be a [Bio::EnsEMBL::Compara::GenomeDB] ".
      "not a [$genome_db]");
    }

    $self->stable_id($gene->stable_id);
    $self->taxon_id($genome_db->taxon_id);
    $self->description("NULL");
    $self->genome_db_id($genome_db->dbID);
    $self->chr_name($gene->seq_region_name);
    $self->chr_start($gene->seq_region_start);
    $self->chr_end($gene->seq_region_end);
    $self->chr_strand($gene->seq_region_strand);
    $self->seq_length(0);
    $self->source_name("ENSEMBLGENE");
    $self->version($gene->version);
  }
  return $self;
}


=head2 new_from_transcript

  Arg[1]     : Bio::Ensembl:Transcript object
  Arg[2]     : Bio::Ensembl:Compara:GenomeDB object
  Arg[3]     : string where value='translate' causes transcript object to translate
               to a peptide
  Example    : $member = Bio::EnsEMBL::Compara::Member->new_from_transcript(
                  $transcript, $genome_db,
                -translate);
  Description: contructor method which takes an Ensembl::Gene object
               and Compara:GenomeDB object and creates a new Member object
               translating from the Gene object
  Returntype : Bio::Ensembl::Compara::Member
  Exceptions :
  Caller     :

=cut

sub new_from_transcript {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  my $peptideBioSeq;
  my $seq_string;

  my ($transcript, $genome_db, $translate, $description) = $self->_rearrange([qw(TRANSCRIPT GENOME_DB TRANSLATE DESCRIPTION)], @args);
  #my ($transcript, $genome_db, $translate) = @args;

  unless(defined($transcript) and $transcript->isa('Bio::EnsEMBL::Transcript')) {
    $self->throw(
    "transcript arg must be a [Bio::EnsEMBL::Transcript]".
    "not a [$transcript]");
  }
  unless(defined($genome_db) and $genome_db->isa('Bio::EnsEMBL::Compara::GenomeDB')) {
    $self->throw(
    "genome_db arg must be a [Bio::EnsEMBL::Compara::GenomeDB] ".
    "not a [$genome_db]");
  }
  $self->taxon_id($genome_db->taxon_id);
  if(defined($description)) { $self->description($description); }
  else { $self->description("NULL"); }
  $self->genome_db_id($genome_db->dbID);
  $self->chr_name($transcript->seq_region_name);
  $self->chr_start($transcript->coding_region_start);
  $self->chr_end($transcript->coding_region_end);
  $self->chr_strand($transcript->seq_region_strand);
  $self->seq_length(0);
  $self->version($transcript->translation->version);

  if(($translate eq 'translate') or ($translate eq 'yes')) {
    if(not defined($transcript->translation)) {
      $self->throw(
        "request to translate a transcript without a defined translation",
        $transcript->stable_id);
    }
    $self->stable_id($transcript->translation->stable_id);
    $self->source_name("ENSEMBLPEP");

    $peptideBioSeq = $transcript->translate;
    $seq_string = $peptideBioSeq->seq;
    # OR
    #$seq_string = $transcript->translation->seq;

    if ($seq_string =~ /^X+$/) {
      warn "X+ in sequence from translation " . $transcript->translation->stable_id."\n";
    }
    else {
      #$seq_string =~ s/(.{72})/$1\n/g;
      $self->sequence($seq_string);
      $self->seq_length($peptideBioSeq->length);
    }
  }
  else {
    $self->stable_id($transcript->stable_id);
    $self->source_name("ENSEMBLTRANS");
    #$self->sequence($transcript->seq);
    #$self->seq_length($transcript->length);
  }

  #print("Member->new_from_transcript\n");
  #print("  source_name = '" . $self->source_name . "'\n");
  #print("  stable_id = '" . $self->stable_id . "'\n");
  #print("  taxon_id = '" . $self->taxon_id . "'\n");
  #print("  chr_name = '" . $self->chr_name . "'\n");
  return $self;
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

=head2 source_id

=cut

sub source_id {
  my $self = shift;
  $self->{'_source_id'} = shift if (@_);
  return $self->{'_source_id'};
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

=head2 chr_name

=cut

sub chr_name {
  my $self = shift;
  $self->{'_chr_name'} = shift if (@_);
  return $self->{'_chr_name'};
}

=head2 chr_start

=cut

sub chr_start {
  my $self = shift;
  $self->{'_chr_start'} = shift if (@_);
  return $self->{'_chr_start'};
}

=head2 chr_end

=cut

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

=head taxon_id

=cut

sub taxon_id {
    my $self = shift;
    $self->{'_taxon_id'} = shift if (@_);
    return $self->{'_taxon_id'};
}

=head2 taxon

=cut

sub taxon {
  my $self = shift;

  if (@_) {
    my $taxon = shift;
    unless ($taxon->isa('Bio::EnsEMBL::Compara::Taxon')) {
      $self->throw(
		   "taxon arg must be a [Bio::EnsEMBL::Compara::Taxon".
		   "not a [$taxon]");
    }
    $self->{'_taxon'} = $taxon;
    $self->taxon_id($taxon->ncbi_taxid);
  } else {
    unless (defined $self->{'_taxon'}) {
      unless (defined $self->taxon_id) {
        $self->throw("can't fetch Taxon without a taxon_id");
      }
      my $TaxonAdaptor = $self->adaptor->db->get_TaxonAdaptor;
      $self->{'_taxon'} = $TaxonAdaptor->fetch_by_dbID($self->taxon_id);
    }
  }

  return $self->{'_taxon'};
}

=head genome_db_id

=cut

sub genome_db_id {
    my $self = shift;
    $self->{'_genome_db_id'} = shift if (@_);
    return $self->{'_genome_db_id'};
}

=head2 genome_db

=cut

sub genome_db {
  my $self = shift;

  if (@_) {
    my $genome_db = shift;
    unless ($genome_db->isa('Bio::EnsEMBL::Compara::GenomeDB')) {
      $self->throw(
		   "arg must be a [Bio::EnsEMBL::Compara::GenomeDB".
		   "not a [$genome_db]");
    }
    $self->{'_genome_db'} = $genome_db;
    $self->genome_db_id($genome_db->dbID);
  } else {
    unless (defined $self->{'_genome_db'}) {
      unless (defined $self->genome_db_id) {
        $self->throw("can't fetch GenomeDB without a genome_db_id");
      }
      my $GenomeDBAdaptor = $self->adaptor->db->get_GenomeDBAdaptor;
      $self->{'_genome_db'} = $GenomeDBAdaptor->fetch_by_dbID($self->genome_db_id);
    }
  }

  return $self->{'_genome_db'};
}

=head2 sequence

  Arg [1]    : string $sequence
  Example    : my $seq = $member->sequence;
  Description: Extracts the sequence string of this member
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub sequence {
  my $self = shift;
  $self->{'_sequence'} = shift if(@_);
  return $self->{'_sequence'};
}


=head2 seq_length

  Arg [1]    : int $seq_length
  Example    : my $seq_length = $member->seq_length;
  Description: Extracts the sequence length of this member
  Returntype : int
  Exceptions : none
  Caller     : general

=cut

sub seq_length {
  my $self = shift;
  $self->{'_seq_length'} = shift if(@_);
  return $self->{'_seq_length'};
}


=head2 sequence_id

  Arg [1]    : int $sequence_id
  Example    : my $sequence_id = $member->sequence_id;
  Description: Extracts the sequence_id of this member
  Returntype : int
  Exceptions : none
  Caller     : general

=cut

sub sequence_id {
  my $self = shift;
  $self->{'_sequence_id'} = shift if(@_);
  if(!defined($self->{'_sequence_id'})) { $self->{'_sequence_id'}=0; }
  return $self->{'_sequence_id'};
}


=head2 bioseq

  Args       : none
  Example    : my $primaryseq = $member->primaryseq;
  Description: returns sequence this member as a Bio::Seq object
  Returntype : Bio::Seq object
  Exceptions : none
  Caller     : general

=cut

sub bioseq {
  my $self = shift;

  $self->throw("Member stable_id undefined") unless defined($self->stable_id());
  $self->throw("No sequence for member " . $self->stable_id()) unless defined($self->sequence());

  my $seq = Bio::Seq->new(-seq        => $self->sequence(),
                          -id         => $self->stable_id(),
                          -primary_id => $self->stable_id(),
                          -desc       => $self->description(),
                         );
  return $seq;
}

=head2 gene_member

  Arg[1]     : Bio::EnsEMBL::Compara::Member $geneMember (optional)
  Example    : my $primaryseq = $member->primaryseq;
  Description: returns sequence this member as a Bio::Seq object
  Returntype : Bio::EnsEMBL::Compara::Member object
  Exceptions : if arg[0] isn't a Bio::EnsEMBL::Compara::Member object
  Caller     : MemberAdaptor(set), general

=cut

sub gene_member {
  my $self = shift;
  my $gene_member = shift;

  if ($gene_member) {
    $self->throw("arg must be a [Bio::EnsEMBL::Compara::Member] not a [$gene_member]")
      unless ($gene_member->isa('Bio::EnsEMBL::Compara::Member'));
    $self->{'_gene_member'} = $gene_member;
  }
  return $self->{'_gene_member'};
}


=head2 print_member

  Arg[1]     : string $postfix
  Example    : $member->print_member("BRH");
  Description: used for debugging, prints out key descriptive elements
               of member
  Returntype : none
  Exceptions : none
  Caller     : general

=cut
sub print_member
{
  my $self = shift;
  my $postfix = shift;

  print("   ".$self->stable_id.
        "(".$self->dbID.")".
        "\t".$self->chr_name ." : ".
        $self->chr_start ."- ". $self->chr_end);
  if($postfix) { print(" $postfix"); }
  else { print("\n"); }
}

1;
