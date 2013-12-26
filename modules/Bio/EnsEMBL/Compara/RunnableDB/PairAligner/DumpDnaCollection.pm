=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::DumpDnaCollection

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION


=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::DumpDnaCollection;

use strict;
use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::EnsEMBL::Analysis::Runnable::Blat;
use Bio::EnsEMBL::Analysis::RunnableDB;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');
use File::Path;


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  #Check for DnaFragChunk or DnaFragChunkSet
  die("Missing DnaFragChunk or DnaFragChunkSet") unless ($self->param('DnaFragChunk') || $self->param('DnaFragChunkSet'));

  #If not defined, use one in path
  unless ($self->param('faToNib_exe')) {
      $self->param('faToNib_exe', 'faToNib');
  }

  #must have dump_nib or dump_dna defined
  die("Missing dump_nib or dump_dna") unless ($self->param('dump_nib') || $self->param('dump_dna'));

  return 1;
}



sub run
{
  my $self = shift;

  if ($self->param('dump_nib')) {
      $self->dumpNibFiles;
  }
  if ($self->param('dump_dna')) {
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
# internal methods
#
##########################################

sub dumpNibFiles {
  my $self = shift;

  $self->compara_dba->dbc->disconnect_when_inactive(1);

  my $starttime = time();

  my $dna_collection = $self->compara_dba->get_DnaCollectionAdaptor->fetch_by_set_description($self->param('collection_name'));
  my $dump_loc = $dna_collection->dump_loc;

  unless (defined $dump_loc) {
    die("dump_loc directory is not defined, can not dump nib files\n");
  }

  #Make directory if does not exist
  if (!-e $dump_loc) {
      print "$dump_loc does not currently exist. Making directory\n";
      mkpath($dump_loc); 
  }

  if ($self->param('DnaFragChunk')) {
      my $dna_object = $self->compara_dba->get_DnaFragChunkAdaptor->fetch_by_dbID($self->param('DnaFragChunk'));

      my $nibfile = "$dump_loc/". $dna_object->dnafrag->name . ".nib";

      #don't dump nibfile if it already exists and don't want to overwrite. Default is to overwrite
      if (! -e $nibfile || $self->param("overwrite")) {
          my $fastafile = "$dump_loc/". $dna_object->dnafrag->name . ".fa";
          
          #$dna_object->dump_to_fasta_file($fastafile);
          #use this version to solve problem of very large chromosomes eg opossum
          $dna_object->dump_chunks_to_fasta_file($fastafile);
          
          if (-e $self->param('faToNib_exe')) {
              system($self->param('faToNib_exe'), "$fastafile", "$nibfile") and die("Could not convert fasta file $fastafile to nib: $!\n");
          } else {
              die("Unable to find faToNib. Must either define faToNib_exe or it must be in your path");
          }
          
          unlink $fastafile;
          $dna_object = undef;
      }
  }

  if($self->debug){printf("%1.3f secs to dump nib for \"%s\" collection\n", (time()-$starttime), $self->param('collection_name'));}

  $self->compara_dba->dbc->disconnect_when_inactive(0);

  return 1;
}

sub dumpDnaFiles {
  my $self = shift;

  $self->compara_dba->dbc->disconnect_when_inactive(1);

  my $starttime = time();

  my $dna_collection = $self->compara_dba->get_DnaCollectionAdaptor->fetch_by_set_description($self->param('collection_name'));
  my $dump_loc = $dna_collection->dump_loc;
  unless (defined $dump_loc) {
    die("dump_loc directory is not defined, can not dump nib files\n");
  }

  #Make directory if does not exist
  if (!-e $dump_loc) {
      print "$dump_loc does not currently exist. Making directory\n";
      mkpath($dump_loc); 
  }

  if ($self->param('DnaFragChunkSet')) {
	my $dna_object = $self->compara_dba->get_DnaFragChunkSetAdaptor->fetch_by_dbID($self->param('DnaFragChunkSet'));

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

  if($self->debug){printf("%1.3f secs to dump nib for \"%s\" collection\n", (time()-$starttime), $self->param('collection_name'));}

  $self->compara_dba->dbc->disconnect_when_inactive(0);

  return 1;
}

#Xreate a ooc file used in blat analysis. Not used for translated blat.
sub create_ooc_file {
  my ($dir, $seq_region) = @_;

  my $ooc_file = "$dir/$seq_region/5ooc";

  #make new directory to store 5ooc file for each seq_region
  if (!-e "$dir/$seq_region") {
      mkdir("$dir/$seq_region")
        or die("Directory $dir/$seq_region cannot be created");
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
