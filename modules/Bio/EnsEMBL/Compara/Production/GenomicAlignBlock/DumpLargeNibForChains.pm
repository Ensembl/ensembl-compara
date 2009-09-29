#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::DumpLargeNibForChains

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION


=cut

=head1 CONTACT

Abel Ureta-Vidal <abel@ebi.ac.uk>

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::DumpLargeNibForChains;

use strict;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;;
use Bio::EnsEMBL::Utils::Exception;
use Time::HiRes qw(time gettimeofday tv_interval);

our @ISA = qw(Bio::EnsEMBL::Pipeline::RunnableDB);

my $DEFAULT_DUMP_MIN_SIZE = 11500000;

#comment out to use default faToNib
my $BIN_DIR = "/software/ensembl/compara/bin";

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with $self->db (Hive DBAdaptor)
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  throw("Missing dna_collection_name") unless($self->dna_collection_name);
  unless ($self->dump_min_size) {
    $self->dump_min_size($DEFAULT_DUMP_MIN_SIZE);
  }

  return 1;
}



sub run
{
  my $self = shift;
  $self->dumpNibFiles;
  return 1;
}


sub write_output {
  my( $self) = @_;
  return 1;
}

##########################################
#
# getter/setter methods
# 
##########################################

sub dna_collection_name {
  my $self = shift;
  $self->{'_dna_collection_name'} = shift if(@_);
  return $self->{'_dna_collection_name'};
}

sub dump_min_size {
  my $self = shift;
  $self->{'_dump_min_size'} = shift if(@_);
  return $self->{'_dump_min_size'};
}

##########################################
#
# internal methods
#
##########################################

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");

  my $params = eval($param_string);
  return unless($params);
  if(defined($params->{'dna_collection_name'})) {
    $self->dna_collection_name($params->{'dna_collection_name'});
  }
  if(defined($params->{'dump_min_size'})) {
    $self->dump_min_size($params->{'dump_min_size'});
  }

  return 1;
}

sub dumpNibFiles {
  my $self = shift;

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);
  
  my $starttime = time();
  
  my $dna_collection = $self->{'comparaDBA'}->get_DnaCollectionAdaptor->fetch_by_set_description($self->dna_collection_name);
  my $dump_loc = $dna_collection->dump_loc;
  unless (defined $dump_loc) {
    throw("dump_loc directory is not defined, can not dump nib files\n");
  }

  foreach my $dna_object (@{$dna_collection->get_all_dna_objects}) {
    if($dna_object->isa('Bio::EnsEMBL::Compara::Production::DnaFragChunkSet')) {
      warn "At this point you should get DnaFragChunk objects not DnaFragChunkSet objects!\n";
      next;
    }
    if($dna_object->isa('Bio::EnsEMBL::Compara::Production::DnaFragChunk')) {
      next if ($dna_object->length <= $self->dump_min_size);

      my $fastafile = "$dump_loc/". $dna_object->dnafrag->name . ".fa";
      
      #$dna_object->dump_to_fasta_file($fastafile);
      #use this version to solve problem of very large chromosomes eg opossum
      $dna_object->dump_chunks_to_fasta_file($fastafile);

      my $nibfile = "$dump_loc/". $dna_object->dnafrag->name . ".nib";

      if (defined $BIN_DIR) {
	  system("$BIN_DIR/faToNib", "$fastafile", "$nibfile") and throw("Could not convert fasta file $fastafile to nib: $!\n");
      } else {
	  system("faToNib", "$fastafile", "$nibfile") and throw("Could not convert fasta file $fastafile to nib: $!\n");
  }
      unlink $fastafile;
      $dna_object = undef;
    }
  }

  if($self->debug){printf("%1.3f secs to dump nib for \"%s\" collection\n", (time()-$starttime), $self->collection_name);}

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

  return 1;
}





1;
