package Bio::EnsEMBL::Compara::Member;

use strict;
use Bio::Seq;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Gene;
use Bio::EnsEMBL::Compara::GenomeDB;

use Bio::EnsEMBL::Compara::NestedSet;
our @ISA = qw(Bio::EnsEMBL::Compara::NestedSet);

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
         (NCBI taxonomy id for the member)
    Arg [-GENOME_DB_ID] (opt)
        : int $genome_db_id
        (the $genome_db->dbID for a species in the database)
    Arg [-SEQUENCE_ID] (opt)
        : int $sequence_id
        (the $sequence_id for the sequence table in the database)
    Example :
	my $member = new Bio::EnsEMBL::Compara::Member;
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
    my ($dbid, $stable_id, $description, $source_name, $adaptor, $taxon_id, $genome_db_id, $sequence_id) = rearrange([qw(DBID STABLE_ID DESCRIPTION SOURCE_NAME ADAPTOR TAXON_ID GENOME_DB_ID SEQUENCE_ID)], @args);

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
  my $self = $class->new(@args);

  if (scalar @args) {

    my ($gene, $genome_db) = rearrange([qw(GENE GENOME_DB)], @args);

    unless(defined($gene) and $gene->isa('Bio::EnsEMBL::Gene')) {
      throw(
      "gene arg must be a [Bio::EnsEMBL::Gene] ".
      "not a [$gene]");
    }
    unless(defined($genome_db) and $genome_db->isa('Bio::EnsEMBL::Compara::GenomeDB')) {
      throw(
      "genome_db arg must be a [Bio::EnsEMBL::Compara::GenomeDB] ".
      "not a [$genome_db]");
    }
    unless (defined $gene->stable_id) {
      throw("COREDB error: does not contain gene_stable_id for gene_id ". $gene->dbID."\n");
    }

    $self->stable_id($gene->stable_id);
    $self->taxon_id($genome_db->taxon_id);
    $self->description($gene->description);
    $self->genome_db_id($genome_db->dbID);
    $self->chr_name($gene->seq_region_name);
    $self->chr_start($gene->seq_region_start);
    $self->chr_end($gene->seq_region_end);
    $self->chr_strand($gene->seq_region_strand);
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
  my $self = $class->new(@args);
  my $peptideBioSeq;
  my $seq_string;

  my ($transcript, $genome_db, $translate, $description) = rearrange([qw(TRANSCRIPT GENOME_DB TRANSLATE DESCRIPTION)], @args);
  #my ($transcript, $genome_db, $translate) = @args;

  unless(defined($transcript) and $transcript->isa('Bio::EnsEMBL::Transcript')) {
    throw(
    "transcript arg must be a [Bio::EnsEMBL::Transcript]".
    "not a [$transcript]");
  }
  unless(defined($genome_db) and $genome_db->isa('Bio::EnsEMBL::Compara::GenomeDB')) {
    throw(
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
  $self->version($transcript->translation->version) if ($translate eq 'yes');

  if(($translate eq 'translate') or ($translate eq 'yes')) {
    if(not defined($transcript->translation)) {
      throw("request to translate a transcript without a defined translation",
            $transcript->stable_id);
    }
    unless (defined $transcript->translation->stable_id) {
      throw("COREDB error: does not contain translation stable id for translation_id ".$transcript->translation->dbID."\n");
    }
    
    $self->stable_id($transcript->translation->stable_id);
    $self->source_name("ENSEMBLPEP");

   unless ($peptideBioSeq = $transcript->translate) {
	throw("COREDB error: unable to get a BioSeq translation from ". $transcript->stable_id);
    }
    eval {
	$seq_string = $peptideBioSeq->seq;
    };
    throw "COREDB error: can't get seq from peptideBioSeq" if $@;
    # OR
    #$seq_string = $transcript->translation->seq;

    if ($seq_string =~ /^X+$/) {
      warn("X+ in sequence from translation " . $transcript->translation->stable_id."\n");
    }
    elsif (length($seq_string) == 0) {
      warn("zero length sequence from translation " . $transcript->translation->stable_id."\n");
    }
    else {
      #$seq_string =~ s/(.{72})/$1\n/g;
      $self->sequence($seq_string);
    }
  }
  else {
    unless (defined $transcript->stable_id) {
      throw("COREDB error: does not contain transcript stable id for transcript_id ".$transcript->dbID."\n");
    }
    $self->stable_id($transcript->stable_id);
    $self->source_name("ENSEMBLTRANS");
    #$self->sequence($transcript->seq);
  }

  #print("Member->new_from_transcript\n");
  #print("  source_name = '" . $self->source_name . "'\n");
  #print("  stable_id = '" . $self->stable_id . "'\n");
  #print("  taxon_id = '" . $self->taxon_id . "'\n");
  #print("  chr_name = '" . $self->chr_name . "'\n");
  return $self;
}

=head2 copy

  Arg [1]    : int $member_id (optional)
  Example    :
  Description: returns copy of object, calling superclass copy method
  Returntype :
  Exceptions :
  Caller     :

=cut

sub copy {
  my $self = shift;
  
  my $mycopy = $self->SUPER::copy;
  bless $mycopy, "Bio::EnsEMBL::Compara::Member";
  
  $mycopy->dbID($self->dbID);
  $mycopy->stable_id($self->stable_id);
  $mycopy->version($self->version);
  $mycopy->description($self->description);
  $mycopy->source_name($self->source_name);
  #$mycopy->adaptor($self->adaptor);
  $mycopy->chr_name($self->chr_name);
  $mycopy->chr_start($self->chr_start);
  $mycopy->chr_end($self->chr_end);
  $mycopy->chr_strand($self->chr_strand);
  $mycopy->taxon_id($self->taxon_id);
  $mycopy->genome_db_id($self->genome_db_id);
  $mycopy->sequence_id($self->sequence_id);
  $mycopy->gene_member_id($self->gene_member_id);
  $mycopy->display_label($self->display_label);
  
  return $mycopy;
}

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

=head2 sequence

  Arg [1]    : string $sequence
  Example    : my $seq = $member->sequence;
  Description: Get/set the sequence string of this member
               Will lazy load by sequence_id if needed and able
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub sequence {
  my $self = shift;

  if(@_) {
    $self->{'_seq_length'} = undef;
    $self->{'_sequence'} = shift;
    $self->{'_seq_length'} = length($self->{'_sequence'}) if(defined($self->{'_sequence'}));
    return $self->{'_sequence'};
  }
  
  if(!defined($self->{'_sequence'}) and
     defined($self->sequence_id()) and     
     defined($self->adaptor))
  {
    $self->{'_sequence'} = $self->adaptor->_fetch_sequence_by_id($self->sequence_id);
    $self->{'_seq_length'} = length($self->{'_sequence'}) if(defined($self->{'_sequence'}));
  }

  return $self->{'_sequence'};
}

=head2 sequence_exon_cased

  Args       : none
  Example    : my $sequence_exon_cased = $member->sequence_exon_cased;

  Description: Get/set the sequence string of this peptide member with
               alternating upper and lower case corresponding to the translateable exons.
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub sequence_exon_cased {
  my $self = shift;

  my $sequence = $self->sequence;
  my $trans = $self->transcript;
  my @exons = @{$trans->get_all_translateable_Exons};
  return $sequence if (1 == scalar @exons);

  my %splice_site;
  my $pep_len = 0;
  my $overlap_len = 0;
  while (my $exon = shift @exons) {
    my $exon_len = $exon->length;
    my $pep_seq = $exon->peptide($trans)->length;
    # remove the first char of seq if overlap ($exon->peptide()) return full overlapping exon seq
    $pep_seq -= 1 if ($overlap_len);
    $pep_len += $pep_seq;
    if ($overlap_len = (($exon_len + $overlap_len ) %3)){          # if there is an overlap
      $splice_site{$pep_len-1}{'overlap'} = $pep_len -1;         # stores overlapping aa-exon boundary
    } else {
      $overlap_len = 0;
    }
    $splice_site{$pep_len}{'phase'} = $overlap_len;                 # positions of exon boundary
  }

  my $seqsplice = '';
  my $splice = 0;
  foreach my $pep_len (sort {$b<=>$a} keys %splice_site) { # We start from the end
    next if (defined($splice_site{$pep_len}{'overlap'}));
    next if ($pep_len > length($sequence)); # Get rid of 1 codon STOP exons in the protein
    $splice++;
    my $length = $pep_len;
    $length-- if (defined($splice_site{$pep_len}{'phase'}) && 1 == $splice_site{$pep_len}{'phase'});
    my $peptide;
    $peptide = substr($sequence,$length,length($sequence),'');
    $peptide = lc($peptide) unless ($splice % 2); # Even splice lower-cased
    $seqsplice = $peptide . $seqsplice;
  }
  $seqsplice = $sequence . $seqsplice; # First exon AS IS

  return $seqsplice;
}

sub sequence_exon_bounded {
  my $self = shift;

  my $sequence = $self->sequence;
  my $trans = $self->transcript;
  my @exons = @{$trans->get_all_translateable_Exons};
  return $sequence if (1 == scalar @exons);

  my %splice_site;
  my $pep_len = 0;
  my $overlap_len = 0;
  while (my $exon = shift @exons) {
    my $exon_len = $exon->length;
    my $pep_seq = $exon->peptide($trans)->length;
    # remove the first char of seq if overlap ($exon->peptide()) return full overlapping exon seq
    $pep_seq -= 1 if ($overlap_len);
    $pep_len += $pep_seq;
    if ($overlap_len = (($exon_len + $overlap_len ) %3)){          # if there is an overlap
      $splice_site{$pep_len-1}{'overlap'} = $pep_len -1;         # stores overlapping aa-exon boundary
    } else {
      $overlap_len = 0;
    }
    $splice_site{$pep_len}{'phase'} = $overlap_len;                 # positions of exon boundary
  }

  my $seqsplice = '';
  my $splice = 0;
  foreach my $pep_len (sort {$b<=>$a} keys %splice_site) { # We start from the end
    next if (defined($splice_site{$pep_len}{'overlap'}));
    next if ($pep_len > length($sequence)); # Get rid of 1 codon STOP exons in the protein
    $splice++;
    my $length = $pep_len;
    $length-- if (defined($splice_site{$pep_len}{'phase'}) && 1 == $splice_site{$pep_len}{'phase'});
    my $peptide;
    $peptide = substr($sequence,$length,length($sequence),'');
    # $peptide = lc($peptide) unless ($splice % 2); # Even splice lower-cased
    $seqsplice = $peptide . $seqsplice;
    $seqsplice = 'o' . $seqsplice if (0 == $splice_site{$pep_len}{'phase'});
    $seqsplice = 'b' . $seqsplice if (1 == $splice_site{$pep_len}{'phase'});
    $seqsplice = 'j' . $seqsplice if (2 == $splice_site{$pep_len}{'phase'});
  }
  $seqsplice = $sequence . $seqsplice; # First exon AS IS

  return $seqsplice;
}

# GJ 2008-11-17
# Returns the amino acid sequence with exon boundaries denoted as O, B, or J depending on the phase (O=0, B=1, J=2)
sub get_exon_bounded_sequence {
    my $self = shift;
    my $numbers = shift;
    my $transcript = $self->get_Transcript;

    # The get_all_translateable_exons creates a list of reformatted "translateable" exon sequences.
    # When the exon phase is 1 or 2, there will be duplicated residues at the end and start of exons.
    # We'll deal with this during the exon loop.
    my @exons = @{$transcript->get_all_translateable_Exons};
    my $seq_string = "";
    # for my $ex (@exons) {
    while (my $ex = shift @exons) {
	my $seq = $ex->peptide($transcript)->seq;

	# PHASE HANDLING
	my $phase = $ex->phase;
	my $end_phase = $ex->end_phase;

	# First, cut off repeated end residues.
	if ($end_phase == 1 && 0 < scalar @exons) {
	    # We only own 1/3, so drop the last residue.
	    $seq = substr($seq,0,-1);
	}

	# Now cut off repeated start residues.
	if ($phase == 2) {
	    # We only own 1/3, so drop the first residue.
	    $seq = substr($seq, 1);
	}

	if ($end_phase > -1) {
	    $seq = $seq . 'o' if ($end_phase == 0);
	    $seq = $seq . 'b' if ($end_phase == 1);
	    $seq = $seq . 'j' if ($end_phase == 2);
	}
	#print "Start_phase: $phase   End_phase: $end_phase\t$seq\n";
	$seq_string .= $seq;
    }
    if (defined $numbers) {
      $seq_string =~ s/o/0/g; $seq_string =~ s/b/1/g; $seq_string =~ s/j/2/g;
    }
    return $seq_string;
}

=head2 seq_length

  Example    : my $seq_length = $member->seq_length;
  Description: get the sequence length of this member
  Returntype : int
  Exceptions : none
  Caller     : general

=cut

sub seq_length {
  my $self = shift;

  unless(defined($self->{'_seq_length'})) {
    #need to check case if user is calling seq_length first
    #call $self->sequence (to lazy load if needed)
    my $seq = $self->sequence;
    $self->{'_seq_length'} = length($seq) if(defined($seq));
  }
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

=head2 gene_member_id

  Arg [1]    : int $gene_member_id
  Example    : my $gene_member_id = $member->gene_member_id;
  Description: Gene_member_id of this protein member
  Returntype : int
  Exceptions : none
  Caller     : general

=cut

sub gene_member_id {
  my $self = shift;
  $self->{'_gene_member_id'} = shift if(@_);
  return $self->{'_gene_member_id'};
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

  throw("Member stable_id undefined") unless defined($self->stable_id());
  throw("No sequence for member " . $self->stable_id()) unless defined($self->sequence());

  my $seqname;
  if (defined($self->genome_db_id) and defined($self->dbID)) {
    $seqname = "IDs:" . $self->genome_db_id . ":" . $self->dbID . " " .
        $self->source_name . ":" . $self->stable_id;
  } else {
    $seqname = $self->source_name . ":" . $self->stable_id;
  }
  my $seq = Bio::Seq->new(-seq        => $self->sequence(),
                          -primary_id => "member_id_".$self->dbID,
                          -display_id => "member_id_".$self->dbID,
                          -desc       => $seqname ."|". $self->description(),
                         );
  return $seq;
}

=head2 gene_member

  Arg[1]     : Bio::EnsEMBL::Compara::Member $geneMember (optional)
  Example    : my $gene_member = $member->gene_member;
  Description: returns gene member object for this protein member
  Returntype : Bio::EnsEMBL::Compara::Member object
  Exceptions : if arg[0] is not a Bio::EnsEMBL::Compara::Member object
  Caller     : MemberAdaptor(set), general

=cut

sub gene_member {
  my $self = shift;
  my $gene_member = shift;

  if ($gene_member) {
    throw("arg must be a [Bio::EnsEMBL::Compara::Member] not a [$gene_member]")
      unless ($gene_member->isa('Bio::EnsEMBL::Compara::Member'));
    $self->{'_gene_member'} = $gene_member;
  }
  if(!defined($self->{'_gene_member'}) and
     defined($self->adaptor) and $self->dbID)
  {
    $self->{'_gene_member'} = $self->adaptor->fetch_gene_for_peptide_member_id($self->dbID);
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

  printf("   %s %s(%d)\t%s : %d-%d",$self->source_name, $self->stable_id,
         $self->dbID,$self->chr_name,$self->chr_start, $self->chr_end);
  if($postfix) { print(" $postfix"); }
  else { print("\n"); }
}


=head2 get_Gene

  Args       : none
  Example    : $gene = $member->get_Gene
  Description: if member is an 'ENSEMBLGENE' returns Bio::EnsEMBL::Gene object
               by connecting to ensembl genome core database
               REQUIRES properly setup Registry conf file or
               manually setting genome_db->db_adaptor for each genome.
  Returntype : Bio::EnsEMBL::Gene or undef
  Exceptions : none
  Caller     : general

=cut

sub get_Gene {
  my $self = shift;
  
  return $self->{'core_gene'} if($self->{'core_gene'});
  
  unless($self->genome_db and 
         $self->genome_db->db_adaptor and
         $self->genome_db->db_adaptor->isa('Bio::EnsEMBL::DBSQL::DBAdaptor')) 
  {
    throw("unable to connect to core ensembl database: missing registry and genome_db.locator");
  }

  my $coreDBA = $self->genome_db->db_adaptor;
  if($self->source_name eq 'ENSEMBLGENE') {    
    $self->{'core_gene'} = $coreDBA->get_GeneAdaptor->fetch_by_stable_id($self->stable_id);
  }
  if($self->source_name eq 'ENSEMBLPEP') {
    $self->{'core_gene'} = $coreDBA->get_GeneAdaptor->fetch_by_stable_id($self->gene_member->stable_id);
  }
  return $self->{'core_gene'};
}

=head2 get_Transcript

  Args       : none
  Example    : $transcript = $member->get_Transcript
  Description: if member is an 'ENSEMBLPEP' returns Bio::EnsEMBL::Transcript object
               by connecting to ensembl genome core database
               REQUIRES properly setup Registry conf file or
               manually setting genome_db->db_adaptor for each genome.
  Returntype : Bio::EnsEMBL::Transcript or undef
  Exceptions : none
  Caller     : general

=cut

sub get_Transcript {
  my $self = shift;
  
  return undef unless($self->source_name eq 'ENSEMBLPEP');
  return $self->{'core_transcript'} if($self->{'core_transcript'});
  
  unless($self->genome_db and 
         $self->genome_db->db_adaptor and
         $self->genome_db->db_adaptor->isa('Bio::EnsEMBL::DBSQL::DBAdaptor')) 
  {
    throw("unable to connect to core ensembl database: missing registry and genome_db.locator");
  }
  my $coreDBA = $self->genome_db->db_adaptor;
  $self->{'core_transcript'} = $coreDBA->get_TranscriptAdaptor->fetch_by_translation_stable_id($self->stable_id);
  return $self->{'core_transcript'};
}


=head2 get_Translation

  Args       : none
  Example    : $translation = $member->get_Translation
  Description: if member is an 'ENSEMBLPEP' returns Bio::EnsEMBL::Translation object
               by connecting to ensembl genome core database
               REQUIRES properly setup Registry conf file or
               manually setting genome_db->db_adaptor for each genome.
  Returntype : Bio::EnsEMBL::Gene or undef
  Exceptions : none
  Caller     : general

=cut

sub get_Translation {
  my $self = shift;
  return $self->get_Transcript->translation if($self->get_Transcript);
  return undef;
}

sub gene {
  my $self = shift;
  return $self->get_Gene;
}
sub transcript {
  my $self = shift;
  return $self->get_Transcript;
}
sub translation {
  my $self = shift;
  return $self->get_Translation;
}

=head2 get_longest_peptide_Member

  Args       : none
  Example    : $longestPepMember = $member->get_longest_peptide_Member
  Description: if member is an "ENSEMBLGENE" it will return the longest peptide member
               if member is an 'ENSEMBLPEP' it will get its gene member and have it
               return the longest peptide (which could be the same as the starting member)
  Returntype : Bio::EnsEMBL::Compara::Member or undef
  Exceptions : none
  Caller     : general

=cut

sub get_longest_peptide_Member {
  my $self = shift;

  return undef unless($self->adaptor);
  my $longestPep = undef;
  if($self->source_name eq 'ENSEMBLGENE') {
    $longestPep = $self->adaptor->fetch_longest_peptide_member_for_gene_member_id($self->dbID);
  }
  if($self->source_name eq 'ENSEMBLPEP') {
    my $geneMember = $self->gene_member;
    return undef unless($geneMember);
    $longestPep = $self->adaptor->fetch_longest_peptide_member_for_gene_member_id($geneMember->dbID);
  }
  return $longestPep;
}


=head2 get_all_peptide_Members

  Args       : none
  Example    : $pepMembers = $gene_member->get_all_peptide_Members
  Description: return listref of all peptide members of this gene_member
  Returntype : array ref of Bio::EnsEMBL::Compara::Member 
  Exceptions : throw if not an ENSEMBLGENE
  Caller     : general

=cut

sub get_all_peptide_Members {
  my $self = shift;

  throw("adaptor undefined, can access database") unless($self->adaptor);
  throw("not an ENSEMBLGENE member") if($self->source_name ne 'ENSEMBLGENE'); 

  return $self->adaptor->fetch_peptides_for_gene_member_id($self->dbID);
}
 

# DEPRECATED METHODS
####################

sub source_id {
  my $self = shift;
  throw("Method deprecated. You can now get the source_name by directly calling source_name method\n");
}


1;
