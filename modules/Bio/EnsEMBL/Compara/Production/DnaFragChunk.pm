=head1 NAME - Bio::EnsEMBL::Compara::Production::DnaFragChunk

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONTACT

Jessica Severin <jessica@ebi.ac.uk>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::DnaFragChunk;

use strict;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Compara::DBSQL::SequenceAdaptor;
use Bio::EnsEMBL::Utils::Exception;
use Time::HiRes qw(time gettimeofday tv_interval);

sub new {
  my ($class, $dnafrag, $start, $end) = @_;
  my $self = {};
  bless $self,$class;
  $self->dnafrag($dnafrag) if($dnafrag);
  $self->seq_start($start) if($start);
  $self->seq_end($end)     if($end);
  return $self;
}


=head2 slice

  Arg        : none
  Example    : $slice = $chunk->slice;
  Description: Meta method which uses the dnafrag of this chunk to get the genomeDB
               to connect to corresponding core database, and then to uses the core
               SliceAdaptor to get a slice associated with the dnafrag type and name and
               the this chunks start,end.
  Returntype : Bio::EnsEMBL::Slice object
  Exceptions : none
  Caller     : general, self->fetch_masked_sequence()

=cut

sub slice {
  my ($self) = @_;

  return $self->{'_slice'} if(defined($self->{'_slice'}));

  return undef unless($self->dnafrag);
  return undef unless($self->dnafrag->genome_db);
  return undef unless(my $dba = $self->dnafrag->genome_db->db_adaptor);

  my $sliceDBA = $dba->get_SliceAdaptor;
  #if ($self->seq_end > $self->seq_start) {

  #Should be >= to since end can equal start and the slice be one base long
  #If seq_start and seq_end are both 0, set the slice to be whole dnafrag
  if ($self->seq_end >= $self->seq_start && $self->seq_end != 0) {
    $self->{'_slice'} = $sliceDBA->fetch_by_region($self->dnafrag->coord_system_name,
                                                   $self->dnafrag->name,
                                                   $self->seq_start, $self->seq_end);
  } else {
    $self->{'_slice'} = $sliceDBA->fetch_by_region($self->dnafrag->coord_system_name,
                                                   $self->dnafrag->name);
  }
  return $self->{'_slice'};
}


=head2 fetch_masked_sequence

  Description: Meta method which uses the slice associated with this chunk
               and from the external core database associated with the slice
               it extracts the masked DNA sequence.
               Returns as Bio::Seq object.  does not cache sequence internally
  Arg [1]    : (int or string) masked status of the sequence [optional]
                0 or ''     = unmasked (default)
                1 or 'hard' = masked
                2 or 'soft' = soft-masked
  Arg[2]     : (ref to hash) hash of masking options [optional]
  Example    : $bioseq = $chunk->get_sequence(1);
  Returntype : Bio::Seq or undef if a problem
  Exceptions : none
  Caller     : general

=cut

sub fetch_masked_sequence {
  my $self = shift;
  
  return undef unless(my $slice = $self->slice());


  my $dcs = $slice->adaptor->db->dbc->disconnect_when_inactive();
  #print("fetch_masked_sequence disconnect=$dcs\n");
  $slice->adaptor->db->dbc->disconnect_when_inactive(0);
  #printf("fetch_masked_sequence disconnect=%d\n", $slice->adaptor->db->dbc->disconnect_when_inactive());

  my $seq;
  my $id = $self->display_id;
  my $masking_options;
  my $starttime = time();

  if(defined($self->masking_options)) {
    $masking_options = eval($self->masking_options);
    my $logic_names = $masking_options->{'logic_names'};
    if(defined($masking_options->{'default_soft_masking'}) and
       $masking_options->{'default_soft_masking'} == 0)
    {
      #print "getting HARD masked sequence...\n";
      $seq = $slice->get_repeatmasked_seq($logic_names,0,$masking_options);
    } else {
      #print "getting SOFT masked sequence...\n";
      $seq = $slice->get_repeatmasked_seq($logic_names,1,$masking_options);
    }
  }
  else {  # no masking options set, so get unmasked sequence
    #print "getting UNMASKED sequence...\n";
    $seq = Bio::PrimarySeq->new( -id => $id, -seq => $slice->seq);
  }

  unless($seq->isa('Bio::PrimarySeq')) {
    #print("seq is a [$seq] not a [Bio::PrimarySeq]\n");
    my $oldseq = $seq;
    $seq = Bio::PrimarySeq->new( -id => $id, -seq => $oldseq->seq);
  }
  #print ((time()-$starttime), " secs\n");

  $slice->adaptor->db->dbc->disconnect_when_inactive($dcs);
  #printf("fetch_masked_sequence disconnect=%d\n", $slice->adaptor->db->dbc->disconnect_when_inactive());

  #print STDERR "sequence length : ",$seq->length,"\n";

  $seq = $seq->seq;

  if (defined $masking_options) {
    foreach my $ae (@{$slice->get_all_AssemblyExceptionFeatures}) {
      next unless (defined $masking_options->{"assembly_exception_type_" . $ae->type});
      my $length = $ae->end - $ae->start + 1;
      if ($masking_options->{"assembly_exception_type_" . $ae->type} == 0) {
        my $padstr = 'N' x $length;
        substr ($seq, $ae->start, $length) = $padstr;
      } elsif ($masking_options->{"assembly_exception_type_" . $ae->type} == 1) {
        my $padstr = lc substr ($seq, $ae->start, $length);
        substr ($seq, $ae->start, $length) = $padstr;
      }
    }
  }

  $self->sequence($seq);
  return $seq;
}


=head2 display_id

  Args       : none
  Example    : my $id = $chunk->display_id;
  Description: returns string describing this chunk which can be used
               as display_id of a Bio::Seq object or in a fasta file.
               Uses dnafrag information in addition to start and end.  
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub display_id {
  my $self = shift;

  my $id = "";

  if($self->dbID) {
    $id .= 'chunkID'.$self->dbID.":";
  } elsif($self->dnafrag) {
    $id .= $self->dnafrag->display_id.":";
  }
  $id .= $self->seq_start.".".$self->seq_end;
  
  return $id;
}

=head2 bioseq

  Description: returns sequence of this chunk as a Bio::Seq object
               will fetch from core if not previously cached in compara
  Args       : none
  Example    : my $bioseq = $chunk->bioseq;
  Returntype : Bio::Seq object
  Exceptions : none
  Caller     : general

=cut

sub bioseq {
  my $self = shift;

  my $seq = undef;

  if(not defined($self->sequence())) {
    my $starttime = time();

    $seq = $self->fetch_masked_sequence;
    my $fetch_time = time()-$starttime;

    $self->sequence($seq);
  }
  
  $seq = Bio::Seq->new(-seq        => $self->sequence(),
                       -display_id => $self->display_id(),
                       -primary_id => $self->sequence_id(),
                       );
  return $seq;
}



##########################
#
# getter/setter methods of data which is stored in database
#
##########################

sub adaptor {
  my $self = shift;
  $self->{'_adaptor'} = shift if(@_);
  return $self->{'_adaptor'};
}

sub dbID {
  my $self = shift;
  $self->{'_dbID'} = shift if(@_);
  return $self->{'_dbID'};
}

sub dnafrag {
  my ($self,$dnafrag) = @_;

  if (defined($dnafrag)) {
    throw("arg must be a [Bio::EnsEMBL::Compara::DnaFrag] not a [$dnafrag]")
        unless($dnafrag->isa('Bio::EnsEMBL::Compara::DnaFrag'));
    $self->{'_dnafrag'} = $dnafrag;
    $self->dnafrag_id($dnafrag->dbID);
  }

  #lazy load the DnaFrag
  if(!defined($self->{'_dnafrag'}) and defined($self->dnafrag_id) and $self->adaptor) {
    $self->{'_dnafrag'} = $self->adaptor->_fetch_DnaFrag_by_dbID($self->dnafrag_id);
  }

  return $self->{'_dnafrag'};
}

sub dnafrag_id {
  my $self = shift;
  return $self->{'dnafrag_id'} = shift if(@_);
  return $self->{'dnafrag_id'};
}

sub seq_start {
  my $self = shift;
  return $self->{'seq_start'} = shift if(@_);
  $self->{'seq_start'}=0 unless(defined($self->{'seq_start'}));
  return $self->{'seq_start'};
}

sub seq_end {
  my $self = shift;
  my $end  = shift;
  if($end) {
    $end=$self->dnafrag->length if($self->dnafrag and ($end > $self->dnafrag->length));
    $self->{'seq_end'} = $end;
  }
  $self->{'seq_end'}=0 unless(defined($self->{'seq_end'}));
  return $self->{'seq_end'};
}

sub length {
  my $self = shift;
  return $self->{'seq_end'} - $self->{'seq_start'} + 1;
}

sub sequence_id {
  my $self = shift;
  return $self->{'sequence_id'} = shift if(@_);
  return $self->{'sequence_id'};
}

sub sequence {
  my $self = shift;
  if(@_) {
    $self->{'_sequence'} = shift;
    $self->sequence_id(0);
  }

  return $self->{'_sequence'} if(defined($self->{'_sequence'}));

  #lazy load the sequence if sequence_id is set
  if(defined($self->sequence_id()) and defined($self->adaptor())) {
    $self->{'_sequence'} = $self->adaptor->db->get_SequenceAdaptor->fetch_by_dbID($self->sequence_id);
  }
  return $self->{'_sequence'};
}

sub masking_options {
  my $self = shift;
  if(@_) {
    $self->{'_masking_options'} = shift;
    $self->masking_analysis_data_id(0);
  }
  return $self->{'_masking_options'};
}

#method for passing previously known and stored analysis_data_id reference around
#so that there is no need to store it again
sub masking_analysis_data_id {
  my $self = shift;
  $self->{'masking_analysis_data_id'} = shift if(@_);
  $self->{'masking_analysis_data_id'}=0 unless(defined($self->{'masking_analysis_data_id'}));
  return $self->{'masking_analysis_data_id'};
}


sub dump_to_fasta_file
{
  my $self = shift;
  my $fastafile = shift;
  
  my $bioseq = $self->bioseq;

  #printf("  writing chunk %s\n", $self->display_id);
  open(OUTSEQ, ">$fastafile")
    or $self->throw("Error opening $fastafile for write");
  my $output_seq = Bio::SeqIO->new( -fh =>\*OUTSEQ, -format => 'Fasta');
  $output_seq->write_seq($bioseq);
  close OUTSEQ;

  return $self;
}

#Version of dump_to_fasta_file that appends chunk_size portions of the 
#sequence to fastafile. Useful if the sequence is very long eg opossum chr1 & 2
#Must remember that fastafile should not exist beforehand otherwise it will be 
#appended to so check if it exists and delete it
sub dump_chunks_to_fasta_file 
{
  my $self = shift;
  my $fastafile = shift;

  #choosen because it is divisible by 60 (fasta line width used)
  my $chunk_size = 99999960;
  my $start = 1;
  my $end = $chunk_size;
  my $total_length = $self->length;

  #check to see if the fastafile already exists and delete it if it does.
  if (-e $fastafile) {
     unlink $fastafile;
  }

  open(OUTSEQ, ">>$fastafile")
      or $self->throw("Error opening $fastafile for write");
  print OUTSEQ ">" . $self->display_id . "\n";

  while ($start <= $total_length) {

      $self->{'_slice'} = undef;
      $self->{'_sequence'} = undef;

      $self->seq_start($start);
      $self->seq_end($end);

      my $bioseq = $self->bioseq;

      #increment start and end to do next chunk
      $start = $end + 1;
      
      if ($end+$chunk_size < $total_length) {
	  $end += $chunk_size;
      } else {
	  $end = $total_length;
      }
  
      #write out sequence to fasta file
      my $seq = $bioseq->seq;
      $seq =~ s/(.{60})/$1\n/g;
      $seq =~ s/\n$//;
      print OUTSEQ $seq, "\n";
  }
  close OUTSEQ;
  return $self;
}


sub cache_sequence
{
  my $self = shift;
  
  # $self->sequence will load from compara if available, if not go fetch it
  unless($self->sequence) {
    $self->fetch_masked_sequence;
  }
  
  # fetching sequence will set $self->sequence but not sequence_id so store it
  # fetching may have occurred in a previous method call, so keep this logic
  # separate to make sure it will get stored
  if($self->sequence_id==0) {
    $self->adaptor->update_sequence($self);
  }

  return $self;
}

1;
