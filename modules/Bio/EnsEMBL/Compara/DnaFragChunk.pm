=head1 NAME - Bio::EnsEMBL::Compara::DnaFragChunk

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DnaFragChunk;

use strict;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Compara::DBSQL::SequenceAdaptor;
use Bio::EnsEMBL::Utils::Exception;

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
  Caller     : general, self->get_sequence()
=cut
sub slice {
  my ($self) = @_;

  return $self->{'_slice'} if(defined($self->{'slice'}));

  return undef unless($self->dnafrag);
  return undef unless($self->dnafrag->genomedb);
  return undef unless(my $dba = $self->dnafrag->genomedb->db_adaptor);

  my $sliceDBA = $dba->get_SliceAdaptor;
  if ($self->seq_end > $self->seq_start) {
    $self->{'_slice'} = $sliceDBA->fetch_by_region($self->dnafrag->type, $self->dnafrag->name,
                                                   $self->seq_start, $self->seq_end);
  } else {
    $self->{'_slice'} = $sliceDBA->fetch_by_region($self->dnafrag->type, $self->dnafrag->name);
  }
  return $self->{'_slice'};
}


=head2 fetch_sequence
  Arg [1]    : (int) masked status of the sequence [optional]
                0 unmasked (default)
                1 masked
                2 soft-masked
  Arg[2]     : (ref to hash) hash of masking options [optional]
  Example    : $bioseq = $chunk->get_sequence(1);
  Description: Meta method which uses the slice associated with this chunk
               and from the slice to extract the DNA sequence
               Returns as Bio::Seq object.  does not cache sequence internally
  Returntype : Bio::Seq or undef if a problem
  Exceptions : none
  Caller     : general
=cut
sub fetch_sequence {
  my $self = shift;
  my $masked = shift;
  my $not_default_masking_cases = shift;
  my $seq;

  $masked=0 unless($masked);

  return undef unless(my $slice = $self->slice());

  my $dnafrag = $self->dnafrag;
  my $id = $dnafrag->type.":".
           $dnafrag->name.".".
           ($dnafrag->start+$self->seq_start-1).".".
           ($dnafrag->start+$self->seq_end-1);

  if ($masked == 1) {

    #print STDERR "getting masked sequence...";
    if ($not_default_masking_cases) {
      $seq = $slice->get_repeatmasked_seq(undef,0,$not_default_masking_cases);
    } else {
      $seq = $slice->get_repeatmasked_seq;
    }
    #print STDERR "...got masked sequence...";

  } elsif ($masked == 2) {
    
    #print STDERR "getting soft masked sequence...";
    if ($not_default_masking_cases) {
      $seq = $slice->get_repeatmasked_seq(undef,1,$not_default_masking_cases);
    } else {
      $seq = $slice->get_repeatmasked_seq(undef,1);
    }
    #print STDERR "...got soft masked sequence...";
    
  } else {
    
    #print STDERR "getting unmasked sequence...";
    $seq = Bio::PrimarySeq->new( -id => $id, -seq => $slice->seq);
    #print STDERR "...got unmasked sequence...";
    
  }

  unless($seq->isa('Bio::PrimarySeq')) {
    #print("seq is a [$seq] not a [Bio::PrimarySeq]\n");
    my $oldseq = $seq;
    $seq = Bio::PrimarySeq->new( -id => $id, -seq => $oldseq->seq);
  }

  #print STDERR "sequence length : ",$seq->length,"\n";
  return $seq;
}


##########################
#
# getter/setter methods
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
    $self->{'dnafrag'} = $dnafrag;
    $self->dnafrag_id($dnafrag->dbID);
  }
  return $self->{'dnafrag'};
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
    $end=$self->dnafrag->end if($end > $self->dnafrag->end);
    $self->{'seq_end'} = $end;
  }
  $self->{'seq_end'}=0 unless(defined($self->{'seq_end'}));
  return $self->{'seq_end'};
}

sub sequence_id {
  my $self = shift;
  return $self->{'sequence_id'} = shift if(@_);
  return $self->{'sequence_id'};
}

sub sequence {
  my $self = shift;
  return $self->{'_sequence'} = shift if(@_);
  return $self->{'_sequence'} if(defined($self->{'_sequence'}));	

	#lazy load the sequence if sequence_id is set
  if(defined($self->sequence_id()) and defined($self->adaptor())) {
    $self->{'_sequence'} = $self->adaptor->db->get_SequenceAdaptor->fetch_by_dbID($self->sequence_id);
  }
	return $self->{'_sequence'};
}


=head3
sub display_chunk {
  my $self = shift;

  my $dbID = $self->dbID;
  $dbID = '' unless($dbID);

  my $header = "dnafrag_chunk(".$dbID.")";
  while(length($header)<20) { $header .= ' '; }
  printf($header);
  print($self->stable_id,"(".$self->seq_start,",",$self->seq_start,")",
        "(",$qm->chr_name,":",$qm->seq_start,")\t",
        "\t" , $hm->stable_id, "(".$self->hstart,",",$self->hend,")",
        "(",$hm->chr_name,":",$hm->seq_start,")\t",
        "\t" , $self->score ,
        "\t" , $self->alignment_length ,
        "\t" , $self->perc_ident ,
        "\t" , $self->perc_pos ,
        "\t" , $self->hit_rank ,
        "\n");
}
=cut

1;
