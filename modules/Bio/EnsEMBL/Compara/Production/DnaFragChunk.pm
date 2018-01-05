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

=head1 NAME

Bio::EnsEMBL::Compara::Production::DnaFragChunk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::DnaFragChunk;

use strict;
use warnings;

use File::Path;
use File::Basename;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::Seq;
use Bio::SeqIO;

use Bio::EnsEMBL::Utils::Scalar qw(:assert);

use Bio::EnsEMBL::Hive::Utils 'dir_revhash';

use base ('Bio::EnsEMBL::Storable');        # inherit dbID(), adaptor() and new() methods


sub new {
  my ($class, $dnafrag, $start, $end, $dnafrag_chunk_set_id) = @_;

  my $self = {};
  bless $self, $class;

  $self->dnafrag($dnafrag)                     if($dnafrag);
  $self->seq_start($start)                     if($start);
  $self->seq_end($end)                         if($end);
  $self->dnafrag_chunk_set_id($dnafrag_chunk_set_id) if ($dnafrag_chunk_set_id);
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
  Caller     : general

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
  
  return undef unless($self->dnafrag);
  return undef unless($self->dnafrag->genome_db);
  return undef unless(my $dba = $self->dnafrag->genome_db->db_adaptor);
  my $seq;
  $dba->dbc->prevent_disconnect( sub {
      $seq = $self->_fetch_masked_sequence();
  } );
  return $seq;
}

sub _fetch_masked_sequence {
  my $self = shift;

  return undef unless(my $slice = $self->slice());

  my $seq;
  my $id = $self->display_id;
  my $masking_options;
  my $starttime = time();

  if(defined($self->masking_options)) {
    $masking_options = eval($self->masking_options);
    my $logic_names = $masking_options->{'logic_names'};
    my $soft_masking = $masking_options->{'default_soft_masking'} // 1;
    #printf("getting %s masked sequence...\n", $soft_masking ? 'SOFT' : 'HARD');

    my $masked_slice = $slice->get_repeatmasked_seq($logic_names, $soft_masking, $masking_options);
    $seq = Bio::PrimarySeq->new( -id => $id, -seq => $masked_slice->seq);
  }
  else {  # no masking options set, so get unmasked sequence
    #print "getting UNMASKED sequence...\n";
    $seq = Bio::PrimarySeq->new( -id => $id, -seq => $slice->seq);
  }

  #print ((time()-$starttime), " secs\n");

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

  my $seq_str = $self->sequence();
  if(not defined $seq_str) {
    $seq_str = $self->fetch_masked_sequence;
  }
  
  return Bio::Seq->new(-seq        => $seq_str,
                       -display_id => $self->display_id(),
                       -primary_id => $self->sequence_id(),
                       );
}

##########################
#
# getter/setter methods of data which is stored in database
#
##########################

sub dnafrag {
  my ($self,$dnafrag) = @_;

  if (defined($dnafrag)) {
    assert_ref($dnafrag, 'Bio::EnsEMBL::Compara::DnaFrag', 'dnafrag');
    $self->{'_dnafrag'} = $dnafrag;
    $self->dnafrag_id($dnafrag->dbID);
  }

  #lazy load the DnaFrag
  if(!defined($self->{'_dnafrag'}) and defined($self->dnafrag_id) and $self->adaptor) {
    $self->{'_dnafrag'} = $self->adaptor->db->get_DnaFragAdaptor->fetch_by_dbID($self->dnafrag_id);
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

sub dnafrag_chunk_set_id {
  my $self = shift;
  return $self->{'dnafrag_chunk_set_id'} = shift if(@_);
  return $self->{'dnafrag_chunk_set_id'};
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
  }
  return $self->{'_masking_options'};
}

sub dump_to_fasta_file
{
  my $self = shift;
  my $fastafile = shift;

  mkpath(dirname($fastafile));
  
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


=head2 dump_loc_file

  Example     : $chunk->dump_loc_file();
  Description : Returns the path to this Chunk in the dump location of its DnaCollection
  Returntype  : String
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub dump_loc_file {
    my $self = shift;
    my $dna_collection = shift;

    my $dump_loc = $dna_collection->dump_loc;
    my $sub_dir  = dir_revhash($self->dbID);
    return sprintf('%s/%s/chunk_%s.fa', $dump_loc, $sub_dir, $self->dbID);
}


1;
