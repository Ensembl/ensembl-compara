=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::SeqMember

=head1 DESCRIPTION

Class to represent a member that has a sequence attached.
It is currently used for proteins and RNAs.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::SeqMember
  `- Bio::EnsEMBL::Compara::Member

=head1 SYNOPSIS

Member properties:
 - seq_member_id() is an alias for dbID()

Accessors to the sequence (s):
 - sequence() and sequence_id()
 - seq_length()
 - other_sequence()
 - bioseq()

Links with the Ensembl Core objects:
 - get_Transcript()
 - get_Translation()

Links with other Ensembl Compara Member objects:
 - gene_member() and gene_member_id()

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=head1 METHODS

=cut


package Bio::EnsEMBL::Compara::SeqMember;

use strict;
#use warnings;

#use feature qw(switch);

use Bio::Seq;

use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Scalar qw(:all);


use base ('Bio::EnsEMBL::Compara::Member');


=head2 new (CONSTRUCTOR)

    Arg [-SEQUENCE_ID] (opt) : int
        the $sequence_id for the sequence table in the database
    Example :
	my $peptide = new Bio::EnsEMBL::Compara::SeqMember(-sequence_id => $seq_id);
    Description: Creates a new SeqMember object
    Returntype : Bio::EnsEMBL::Compara::SeqMember
    Exceptions : none

=cut

sub new {
  my ($class, @args) = @_;

  my $self = $class->SUPER::new(@args);
  
  if (scalar @args) {
    my ($sequence_id, $sequence) = rearrange([qw(SEQUENCE_ID SEQUENCE)], @args);

    $sequence_id && $self->sequence_id($sequence_id);
    $sequence && $self->sequence($sequence);
  }

  return $self;
}


=head2 copy

  Arg [1]    : object $source_object (optional)
  Example    : my $member_copy = $member->copy();
  Description: copies the object, optionally by topping up a given structure (to support multiple inheritance)
  Returntype : Bio::EnsEMBL::Compara::SeqMember
  Exceptions : none

=cut

sub copy {
  my $self = shift;
  
  my $mycopy = $self->SUPER::copy(@_);
  
  $self->sequence;  # To make sure the sequence is loaded
  # And now we can copy all the sequence keys
  foreach my $key (keys %$self) {
      if (($key =~ /^_seq_/) or ($key =~ /^_sequence/)) {
          $mycopy->{$key} = $self->{$key};
      }
  }
  $mycopy->gene_member_id($self->gene_member_id);
  
  return $mycopy;
}



=head2 new_from_Transcript

  Arg [-TRANSCRIPT] : Bio::EnsEMBL::Transcript
  Arg [-GENOME_DB] : Bio::EnsEMBL::Compara::GenomeDB
  Arg [-TRANSLATE] : boolean: whether the transcript should be translated
  Example    : $member = Bio::EnsEMBL::Compara::SeqMember->new_from_Transcript(
                  $transcript, $genome_db, 'translate');
  Description: contructor method which takes an Ensembl::Gene object
               and Compara:GenomeDB object and creates a new SeqMember object
               translating from the Gene object
  Returntype : Bio::Ensembl::Compara::SeqMember
  Exceptions :

=cut

sub new_from_Transcript {
    my ($class, @args) = @_;

    my ($transcript, $genome_db, $translate) = rearrange([qw(TRANSCRIPT GENOME_DB TRANSLATE)], @args);

    assert_ref($transcript, 'Bio::EnsEMBL::Transcript');

    my $seq_string;
    my ($start, $end) = ($transcript->seq_region_start, $transcript->seq_region_end);
    my $stable_id = $transcript->stable_id ||
      throw("COREDB error: does not contain transcript stable id for transcript_id ".$transcript->dbID."\n");

    if ($translate) {
        my ($start, $end) = ($transcript->coding_region_start, $transcript->coding_region_end);

        if(not defined($transcript->translation)) {
            throw("request to translate a transcript without a defined translation", $transcript->stable_id);
        }

        $stable_id = $transcript->translation->stable_id ||
            throw("COREDB error: does not contain translation stable id for translation_id ".$transcript->translation->dbID."\n");

        $seq_string = $transcript->translation->seq;

        if ($seq_string =~ /^X+$/) {
            warn("X+ in sequence from translation " . $transcript->translation->stable_id."\n");
        } elsif (length($seq_string) == 0) {
            warn("zero length sequence from translation " . $transcript->translation->stable_id."\n");
        }

    } else {
        unless ($seq_string = $transcript->spliced_seq) {
            throw("COREDB error: unable to get a BioSeq spliced_seq from ". $transcript->stable_id);
        }
        if (length($seq_string) == 0) {
            warn("zero length sequence from transcript " . $transcript->stable_id."\n");
        }
    }

    my $seq_member = Bio::EnsEMBL::Compara::SeqMember->new(
        -STABLE_ID => $stable_id,
        -DISPLAY_LABEL => ($transcript->display_xref ? $transcript->display_xref->display_id : undef),
        -DNAFRAG_START => $start,
        -DNAFRAG_END => $end,
        -DNAFRAG_STRAND => $transcript->seq_region_strand,

        -DNAFRAG => $genome_db->adaptor->db->get_DnaFragAdaptor->fetch_by_GenomeDB_and_name($genome_db, $transcript->seq_region_name),
        -GENOME_DB_ID => $genome_db->dbID,
        -TAXON_ID => $genome_db->taxon_id,

        -SOURCE_NAME => ($translate ? 'ENSEMBLPEP' : 'ENSEMBLTRANS'),
        -SEQUENCE => $seq_string,
        -DESCRIPTION => $transcript->description,
    );
    $seq_member->{core_transcript} = $transcript;
    return $seq_member;
}


sub member_id { ## DEPRECATED
  my $self = shift;
  deprecate('SeqMember::member_id() is deprecated and will be removed in e79. Please use seq_member_id() instead');
  return $self->dbID(@_);
}


=head2 seq_member_id

  Arg [1]    : (opt) integer
  Description: alias for dbID()

=cut

sub seq_member_id {
  my $self = shift;
  return $self->dbID(@_);
}



#
# Sequence methods
#####################



=head2 sequence

  Arg [1]    : (opt) string $sequence
  Example    : my $seq = $member->sequence;
  Description: Get/set the sequence string of this member
               Will lazy load by sequence_id if needed and able
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub sequence {
  my $self = shift;
  my $sequence = shift;
  if(defined $sequence) {
    $self->{'_seq_length'} = undef;
    $self->{'_sequence'} = $sequence;
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


sub sequence_exon_cased {  ## DEPRECATED
    my $self = shift;

    deprecate('SeqMember::sequence_exon_cased() is deprecated and will be removed in e79. Use SeqMember::other_sequence("exon_cased") instead');
    return $self->other_sequence('exon_cased');
}

sub sequence_exon_bounded { ## DEPRECATED
    my $self = shift;

    deprecate('SeqMember::sequence_exon_bounded() is deprecated and will be removed in e79. Use SeqMember::other_sequence("exon_bounded") instead');
    return $self->other_sequence('exon_bounded');
}

sub sequence_cds {  ## DEPRECATED
    my $self = shift;

    deprecate('SeqMember::sequence_cds() is deprecated and will be removed in e79. Use SeqMember::other_sequence("cds") instead');
    return $self->other_sequence('cds');
}


=head2 other_sequence

  Arg [1]    : string $seq_type
  Arg [2]    : (opt) string $sequence
  Example    : my $filtered_seq = $member->other_sequence('cds');
  Description: Get/Set the alternative sequence of type $seq_type for this member.
                Currently, proteins have 'cds', 'exon_bounded' and 'exon_cased'
                sequences, while RNAs have 'seq_with_flanking' sequences.
                The undef $seq_type maps to the default sequence ($member->sequence())
                If $sequence is set: store it in the database.
                'exon_cased' maps to the sequence string of this member with alternating upper
                and lower case corresponding to the translateable exons.
                'exon_bounded' maps to the sequence string of this member with exon boundaries
                denoted as O, B, or J depending on the phase (O=0, B=1, J=2)
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub other_sequence {
    my $self = shift;
    my $seq_type = shift;
    my $sequence = shift;

    # Defaults to "->sequence()"
    return $self->sequence($sequence) unless $seq_type;

    my $key = "_sequence_$seq_type";

    # Called as a setter
    if (defined $sequence) {
        $self->adaptor->db->get_SequenceAdaptor->store_other_sequence($self, $sequence, $seq_type);
        $self->{$key} = $sequence;
    }

    # First option, we look in the compara db
    if (not defined $self->{$key}) {
        $self->{$key} = $self->adaptor->db->get_SequenceAdaptor->fetch_other_sequence_by_member_id_type($self->seq_member_id, $seq_type);
    }

    # Second option, we build the sequence from the core db
    if (not defined $self->{$key}) {
        if ($seq_type eq 'cds') {
            $self->_prepare_cds_sequence;
        } elsif ($seq_type =~ /^exon_/) {
            $self->_prepare_exon_sequences;
        }
    }

    return $self->{$key};
}

# This method gets the CDS of a peptide
sub _prepare_cds_sequence {
    my $self = shift;

    die "ncRNA transcripts don't have CDS sequences. Their nucleotide sequence is directly accessible with SeqMember::sequence().\n" if $self->source_name =~ /TRANS$/;
    die "Uniprot entries don't have CDS sequences. They are only defined at the protein level.\n" if $self->source_name =~ m/^Uniprot/;

    if ($self->source_name eq 'ENSEMBLPEP') {
        $self->{_sequence_cds} = $self->get_Transcript->translateable_seq;
    } else {
        warn "SeqMember doesn't know how to get a CDS sequence for ", $self->source_name;
        $self->{_sequence_cds} = '';
    }
}

# This method gets the exons of the peptide, and builds the exon_cased and exon_bounded sequences
# Given that it is quite slow, all the exon-based sequences should be computed here
sub _prepare_exon_sequences {
    my $self = shift;

    # If there is the exon_bounded sequence, it is only a matter of splitting it and alternating the case
    my $exon_bounded_seq = $self->{_sequence_exon_bounded};
    $exon_bounded_seq = $self->adaptor->db->get_SequenceAdaptor->fetch_other_sequence_by_member_id_type($self->seq_member_id, 'exon_bounded') unless $exon_bounded_seq;

    if ($exon_bounded_seq) {
        $self->{_sequence_exon_bounded} = $exon_bounded_seq;
        my $i = 0;
        $self->{_sequence_exon_cased} = join('', map {$i++%2 ? lc($_) : $_} split( /[boj]/, $exon_bounded_seq));

    } else {

        my $sequence = $self->sequence;
        my $transcript = $self->get_Transcript;
        my @exons = @{$transcript->get_all_translateable_Exons};
        # @exons probably doesn't match the protein if there are such edits
        my @seq_edits = @{$transcript->translation->get_all_SeqEdits('amino_acid_sub')};
        push @seq_edits, @{$transcript->get_all_SeqEdits('_rna_edit')};

        if (((scalar @exons) <= 1) or (scalar(@seq_edits) > 0)) {
            $self->{_sequence_exon_cased} = $sequence;
            $self->{_sequence_exon_bounded} = $sequence;
            return;
        }

        # Otherwise, we have to parse the exons
        my %boundary_chars = (0 => 'o', 1 => 'b', 2 => 'j');
        my $left_over = $exons[0]->phase > 0 ? -$exons[0]->phase : 0;
        my @this_seq = ();
        my @exon_sequences = ();
        foreach my $exon (@exons) {
            my $exon_pep_len = POSIX::ceil(($exon->length - $left_over) / 3);
            my $exon_seq = substr($sequence, 0, $exon_pep_len, '');
            $left_over += 3*$exon_pep_len - $exon->length;
            #printf("%s: exon of len %d -> phase %d: %s\n", $transcript->stable_id, $exon_pep_len, $left_over, $exon_seq);
            push @this_seq, $exon_seq;
            push @this_seq, $boundary_chars{$left_over};
            push @exon_sequences, scalar(@exon_sequences)%2 ? $exon_seq : lc($exon_seq);
            die sprintf('Invalid phase: %s', $left_over) unless exists $boundary_chars{$left_over}
        }
        die sprintf('%d characters left in the sequence of %s', length($sequence), $transcript->stable_id) if $sequence;
        pop @this_seq;
        $self->{_sequence_exon_bounded} = join('', @this_seq);
        $self->{_sequence_exon_cased} = join('', @exon_sequences);
    }
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

  Arg [1]    : (opt) int $sequence_id
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

  Arg [1]    : (opt) int $gene_member_id
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

  Arg [-SEQ_TYPE] : string - alternate sequence to use
  Arg [-ID_TYPE] : string - how to form the display_id of the Bio::Seq object
                            - SEQ_MEMBER_ID => dbID of this SeqMember (default)
                            - SEQUENCE_ID => sequence ID
                            - STABLE_ID => stable ID
                            - VERSION => stable ID and version number
                            - SOURCE_STABLE_ID => source name and stable ID
  Arg [-WITH_DESCRIPTION] : boolean - add this Member's description
  Example    : my $bioperl_seq = $member->bioseq;
  Description: returns sequence of this member as a Bio::Seq object
  Returntype : Bio::Seq object
  Exceptions : none
  Caller     : general

=cut

sub bioseq {
    my $self = shift;
    my ($seq_type, $id_type, $with_description) =
        rearrange([qw(SEQ_TYPE ID_TYPE WITH_DESCRIPTION)], @_);

    throw("Member stable_id undefined") unless defined($self->stable_id());

    my $sequence = $self->other_sequence($seq_type);
    throw("No sequence for member " . $self->stable_id()) unless defined($sequence);

    my $alphabet = $self->source_name =~ /TRANS$/ ? 'dna' : 'protein';
    $alphabet = 'dna' if $seq_type and ($seq_type eq 'cds');

    my $seqname = $self->seq_member_id;
    if ($id_type) {
        $seqname = $self->sequence_id if $id_type =~ m/^SEQUENCE/i;
        $seqname = $self->stable_id if $id_type =~ m/^STA/i;
        $seqname = $self->stable_id.($self->version ? '.'.$self->version : '') if $id_type =~ m/^VER/i;
        $seqname = $self->source_name . ':' . $self->stable_id if $id_type =~ m/^SOU/i;
    };

    return Bio::Seq->new(
        -seq                => $sequence,
        -display_id         => $seqname,
        -desc               => $with_description ? $self->description() : undef,
        -alphabet           => $alphabet,
    );
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
    assert_ref($gene_member, 'Bio::EnsEMBL::Compara::GeneMember');
    $self->{'_gene_member'} = $gene_member;
  }
  return undef unless $self->source_name =~ /^ENSEMBL/;
  if(!defined($self->{'_gene_member'}) and
     defined($self->adaptor) and $self->dbID)
  {
    $self->{'_gene_member'} = $self->adaptor->db->get_GeneMemberAdaptor->fetch_by_dbID($self->gene_member_id);
  }
  return $self->{'_gene_member'};
}



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
  
  return undef unless $self->source_name =~ /^ENSEMBL/;
  return $self->{'core_transcript'} if($self->{'core_transcript'});

  unless($self->genome_db and 
         $self->genome_db->db_adaptor and
         $self->genome_db->db_adaptor->isa('Bio::EnsEMBL::DBSQL::DBAdaptor')) 
  {
    throw("unable to connect to core ensembl database: missing registry and genome_db.locator");
  }
  my $coreDBA = $self->genome_db->db_adaptor;
  if ($self->source_name eq 'ENSEMBLPEP') {
      $self->{'core_transcript'} = $coreDBA->get_TranscriptAdaptor->fetch_by_translation_stable_id($self->stable_id);
  } else {
      $self->{'core_transcript'} = $coreDBA->get_TranscriptAdaptor->fetch_by_stable_id($self->stable_id);
  }
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



### Deprecated methods

sub get_exon_bounded_sequence {  # DEPRECATED
    my $self = shift;
    deprecate('get_exon_bounded_sequence() is deprecated and will be removed in e79. Use other_sequence("exon_bounded") instead.');
    return $self->other_sequence('exon_bounded');
}

sub get_other_sequence {  # DEPRECATED
    my $self = shift;
    my $seq_type = shift;
    deprecate('get_other_sequence() is deprecated and will be removed in e79. Use other_sequence($seq_type) instead.');
    return $self->other_sequence($seq_type);
}


1;
