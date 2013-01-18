package Bio::EnsEMBL::Compara::SeqMember;

use strict;
use Bio::Seq;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;

use base ('Bio::EnsEMBL::Compara::Member');


=head2 new (CONSTRUCTOR)

    Arg [-SEQUENCE_ID] (opt)
        : int $sequence_id
        (the $sequence_id for the sequence table in the database)
    Example :
	my $peptide = new Bio::EnsEMBL::Compara::SeqMember;
       Description: Creates a new SeqMember object
       Returntype : Bio::EnsEMBL::Compara::SeqMember
       Exceptions : none
       Caller     : general
       Status     : Stable

=cut

sub new {
  my ($class, @args) = @_;

  my $self = $class->SUPER::new(@args);
  
  if (scalar @args) {
    my ($sequence_id) = rearrange([qw(SEQUENCE_ID)], @args);

    $sequence_id && $self->sequence_id($sequence_id);
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
  
  my $mycopy = $self->SUPER::copy(@_);
  bless $mycopy, 'Bio::EnsEMBL::Compara::SeqMember';
  
  $mycopy->sequence_id($self->sequence_id);
  $mycopy->gene_member_id($self->gene_member_id);
  
  return $mycopy;
}



=head2 new_from_transcript

  Arg[1]     : Bio::Ensembl:Transcript object
  Arg[2]     : Bio::Ensembl:Compara:GenomeDB object
  Arg[3]     : string where value='translate' causes transcript object to translate
               to a peptide
  Example    : $member = Bio::EnsEMBL::Compara::SeqMember->new_from_transcript(
                  $transcript, $genome_db,
                -translate);
  Description: contructor method which takes an Ensembl::Gene object
               and Compara:GenomeDB object and creates a new SeqMember object
               translating from the Gene object
  Returntype : Bio::Ensembl::Compara::SeqMember
  Exceptions :
  Caller     :

=cut

sub new_from_transcript {
  my ($class, @args) = @_;
  my $self = $class->new(@args);
  my $peptideBioSeq;
  my $seq_string;

  my ($transcript, $genome_db, $translate, $description) = rearrange([qw(TRANSCRIPT GENOME_DB TRANSLATE DESCRIPTION)], @args);

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
  } elsif ($translate eq 'ncrna') {
    unless (defined $transcript->stable_id) {
      throw("COREDB error: does not contain transcript stable id for transcript_id ".$transcript->dbID."\n");
    }
    $self->stable_id($transcript->stable_id);
    $self->source_name("ENSEMBLTRANS");

    unless ($seq_string = $transcript->spliced_seq) {
      throw("COREDB error: unable to get a BioSeq spliced_seq from ". $transcript->stable_id);
    }
    if (length($seq_string) == 0) {
      warn("zero length sequence from transcript " . $transcript->stable_id."\n");
    }
    $self->sequence($seq_string);
  }
  
  #print("Member->new_from_transcript\n");
  #print("  source_name = '" . $self->source_name . "'\n");
  #print("  stable_id = '" . $self->stable_id . "'\n");
  #print("  taxon_id = '" . $self->taxon_id . "'\n");
  #print("  chr_name = '" . $self->chr_name . "'\n");
  return $self;
}





### SECTION 3 ###
#
# Global methods
###################



































































### SECTION 4 ###
#
# Sequence methods
#####################




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
    $self->{'_sequence'} = $self->adaptor->db->get_SequenceAdaptor->fetch_by_dbID($self->sequence_id);
    $self->{'_seq_length'} = length($self->{'_sequence'}) if(defined($self->{'_sequence'}));
  }

  return $self->{'_sequence'};
}

=head2 sequence_exon_cased

  Args       : none
  Example    : my $sequence_exon_cased = $member->sequence_exon_cased;

  Description: Get/set the sequence string of this member with
               alternating upper and lower case corresponding to the translateable exons.
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub sequence_exon_cased {
  my $self = shift;

  my $sequence = $self->sequence;
  my $trans = $self->get_Transcript;
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

  my @exon_sequences = ();
  foreach my $pep_len (sort {$b<=>$a} keys %splice_site) { # We start from the end
    next if (defined($splice_site{$pep_len}{'overlap'}));
    next if ($pep_len > length($sequence)); # Get rid of 1 codon STOP exons in the protein
    my $length = $pep_len;
    $length-- if (defined($splice_site{$pep_len}{'phase'}) && 1 == $splice_site{$pep_len}{'phase'});
    my $peptide;
    $peptide = substr($sequence,$length,length($sequence),'');
    unshift(@exon_sequences, $peptide);
  }
  unshift(@exon_sequences, $sequence); # First exon (last piece of sequence left)

  my $splice = 1;
  foreach my $exon_sequence (@exon_sequences) {
    if ($splice % 2 == 0) {
      $exon_sequence = lc($exon_sequence);
    }
    $splice++;
  }  
  my $seqsplice = join("", @exon_sequences);

  return $seqsplice;
}

sub sequence_exon_bounded {
  my $self = shift;

  if(@_) {
    $self->{'_sequence_exon_bounded'} = shift;
    return $self->{'_sequence_exon_bounded'};
  }

  if(!defined($self->{'_sequence_exon_bounded'})) {
    $self->{'_sequence_exon_bounded'} = $self->adaptor->db->get_SequenceAdaptor->fetch_other_sequence_by_member_id_type($self->member_id, 'exon_bounded');
  }

  if(!defined($self->{'_sequence_exon_bounded'})) {
    $self->{'_sequence_exon_bounded'} = $self->_compose_sequence_exon_bounded;
  }

  return $self->{'_sequence_exon_bounded'};
}


sub _compose_sequence_exon_bounded {
  my $self = shift;

  my $sequence = $self->sequence;
  my $trans = $self->get_Transcript;
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
  foreach my $pep_len (sort {$b<=>$a} keys %splice_site) { # We start from the end
    next if (defined($splice_site{$pep_len}{'overlap'}));
    next if ($pep_len > length($sequence)); # Get rid of 1 codon STOP exons in the protein
    my $length = $pep_len;
    $length-- if (defined($splice_site{$pep_len}{'phase'}) && 1 == $splice_site{$pep_len}{'phase'});
    my $peptide;
    $peptide = substr($sequence,$length,length($sequence),'');
    $seqsplice = $peptide . $seqsplice;
    $seqsplice = 'o' . $seqsplice if (0 == $splice_site{$pep_len}{'phase'});
    $seqsplice = 'b' . $seqsplice if (1 == $splice_site{$pep_len}{'phase'});
    $seqsplice = 'j' . $seqsplice if (2 == $splice_site{$pep_len}{'phase'});
  }
  $seqsplice = $sequence . $seqsplice; # First exon AS IS

  return $seqsplice;
}

sub sequence_cds {
  my $self = shift;

  if(@_) {
    $self->{'_sequence_cds'} = shift;
    return $self->{'_sequence_cds'};
  }

  if(!defined($self->{'_sequence_cds'})) {
    $self->{'_sequence_cds'} = $self->adaptor->db->get_SequenceAdaptor->fetch_other_sequence_by_member_id_type($self->member_id, 'cds');
  }

  if(!defined($self->{'_sequence_cds'})) {
    if ($self->source_name =~ m/^Uniprot/) {
      warn "Uniprot entries don't have CDS sequences\n";
      return "";
    }
    $self->{'_sequence_cds'} = $self->get_Transcript->translateable_seq;
  }

  return $self->{'_sequence_cds'};
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

sub get_other_sequence {
  my $self = shift;
  my $seq_type = shift;

  my $key = "_sequence_other_$seq_type";

  if(!defined($self->{$key})) {
    $self->{$key} = $self->adaptor->db->get_SequenceAdaptor->fetch_other_sequence_by_member_id_type($self->member_id, $seq_type);
  }

  return $self->{$key};
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
  Description: Gene_member_id of this member
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
  Example    : my $bioperl_seq = $member->bioseq;
  Description: returns sequence of this member as a Bio::Seq object
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
                          -primary_id => $self->dbID,
                          -display_id => $seqname,
                          -desc       => $self->description(),
                         );
  return $seq;
}

=head2 gene_member

  Arg[1]     : Bio::EnsEMBL::Compara::GeneMember $geneMember (optional)
  Example    : my $gene_member = $member->gene_member;
  Description: returns gene member object for this sequence member
  Returntype : Bio::EnsEMBL::Compara::GeneMember object
  Exceptions : if arg[0] is not a Bio::EnsEMBL::Compara::GeneMember object
  Caller     : general

=cut

sub gene_member {
  my $self = shift;
  my $gene_member = shift;

  if ($gene_member) {
    throw("arg must be a [Bio::EnsEMBL::Compara::GeneMember] not a [$gene_member]")
      unless ($gene_member->isa('Bio::EnsEMBL::Compara::GeneMember'));
    $self->{'_gene_member'} = $gene_member;
  }
  if(!defined($self->{'_gene_member'}) and
     defined($self->adaptor) and $self->dbID)
  {
    $self->{'_gene_member'} = $self->adaptor->db->get_MemberAdaptor->fetch_by_dbID($self->gene_member_id);
  }
  return $self->{'_gene_member'};
}




### SECTION 5 ###
#
# print a member
##################








### SECTION 6 ###
#
# connection to core
#####################







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
  Returntype : Bio::EnsEMBL::Translation or undef
  Exceptions : none
  Caller     : general

=cut

sub get_Translation {
    my $self = shift;
    my $transcript = $self->get_Transcript;
    return undef unless $transcript;
    return $transcript->translation();
}



### SECTION 7 ###
#
# canonical transcripts
########################











### SECTION 8 ###
#
# sequence links
####################








### SECTION 9 ###
#
# WRAPPERS
###########





1;
