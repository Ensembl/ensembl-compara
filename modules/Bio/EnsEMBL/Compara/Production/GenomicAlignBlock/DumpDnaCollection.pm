#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::DumpDnaCollection

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

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::DumpDnaCollection;

use strict;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;;
use Bio::EnsEMBL::Utils::Exception;
use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::EnsEMBL::Analysis::Runnable::Blat;

#use Bio::EnsEMBL::Pipeline::Runnable::Blat;
#our @ISA = qw(Bio::EnsEMBL::Pipeline::RunnableDB);

use Bio::EnsEMBL::Analysis::RunnableDB;
use Bio::EnsEMBL::Hive::Process;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);

my $DEFAULT_DUMP_MIN_SIZE = 11500000;


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

  #must have dump_nib or dump_ooc defined
  throw("Missing dump_nib or dump_ooc method or dump_dna") unless ($self->dump_nib || $self->dump_dna);

  return 1;
}



sub run
{
  my $self = shift;

  if ($self->dump_nib) {
      $self->dumpNibFiles;
  } 
  if ($self->dump_dna) {
      $self->dumpDnaFiles;
  }

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

sub dump_dna {
  my $self = shift;
  $self->{'_dump_dna'} = shift if(@_);
  return $self->{'_dump_dna'};
}

sub dump_nib {
  my $self = shift;
  $self->{'_dump_nib'} = shift if(@_);
  return $self->{'_dump_nib'};
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
  #print("parsing parameter string : ",$param_string,"\n");

  my $params = eval($param_string);
  return unless($params);
  if(defined($params->{'dna_collection_name'})) {
    $self->dna_collection_name($params->{'dna_collection_name'});
  }
  if(defined($params->{'dump_min_size'})) {
    $self->dump_min_size($params->{'dump_min_size'});
  }
  if(defined($params->{'dump_dna'})) {
    $self->dump_dna($params->{'dump_dna'});
  }
  if(defined($params->{'dump_nib'})) {
    $self->dump_nib($params->{'dump_nib'});
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

      system("faToNib", "$fastafile", "$nibfile") and throw("Could not convert fasta file $fastafile to nib: $!\n");

      #hack to use newer version of faToNib to dump larger fa files eg cow Un.fa
      #system("/nfs/team71/phd/klh/progs/kent/bin/i386_64/faToNib", "$fastafile", "$nibfile") and throw("Could not convert fasta file $fastafile to nib: $!\n");
      unlink $fastafile;
      $dna_object = undef;
    }
  }

  if($self->debug){printf("%1.3f secs to dump nib for \"%s\" collection\n", (time()-$starttime), $self->collection_name);}

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

  return 1;
}

sub dumpDnaFiles {
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

      my $first_dna_object = $dna_object->get_all_DnaFragChunks->[0];
      my $chunk_array = $dna_object->get_all_DnaFragChunks;

      my $name = $first_dna_object->dnafrag->name . "_" . $first_dna_object->seq_start . "_" . $first_dna_object->seq_end;

      my $fastafile = "$dump_loc/". $name . ".fa";

      #Must always dump new fasta files because different runs call the chunks 
      #different names and the chunk name is what is stored in the fasta file.
      if (-e $fastafile) {
	  unlink $fastafile
      }
      foreach my $chunk (@$chunk_array) {
	  #A chunk_set will contain several seq_regions which will be appended
	  #to a single fastafile. This means I can't use 
	  #dump_chunks_to_fasta_file because this deletes the fastafile each
	  #time!
	  $chunk->dump_to_fasta_file(">".$fastafile);
      }
    }
    if($dna_object->isa('Bio::EnsEMBL::Compara::Production::DnaFragChunk')) {
      next if ($dna_object->length <= $self->dump_min_size);

      my $name = $dna_object->dnafrag->name . "_" . $dna_object->seq_start . "_" . $dna_object->seq_end;

      my $fastafile = "$dump_loc/". $name . ".fa";
      
      if (-e $fastafile) {
	  unlink $fastafile
      }
      $dna_object->dump_to_fasta_file(">".$fastafile);
    }
    $dna_object = undef;
  }

  if($self->debug){printf("%1.3f secs to dump nib for \"%s\" collection\n", (time()-$starttime), $self->collection_name);}

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

  return 1;
}

#Xreate a ooc file used in blat analysis. Not used for translated blat.
sub create_ooc_file {
  my ($dir, $seq_region) = @_;

  my $ooc_file = "$dir/$seq_region/5ooc";
  
  #make new directory to store 5ooc file for each seq_region
  if (!-e "$dir/$seq_region") {
      mkdir("$dir/$seq_region")
        or throw("Directory $dir/$seq_region cannot be created");
  }

  my $runnable = new Bio::EnsEMBL::Analysis::Runnable::Blat (
							     -database => "$dir/$seq_region.fa",
							     -query_type => "dnax",
							     -target_type => "dnax",
							     -options => "-ooc=$ooc_file -tileSize=5 -makeOoc=$ooc_file -mask=lower -qMask=lower");
  $runnable->run;
  
  return $ooc_file;
}

1;
