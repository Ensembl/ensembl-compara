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
use warnings;

use File::Path;
use File::Basename;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Analysis::Runnable::Blat;
use Bio::EnsEMBL::Analysis::RunnableDB;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
  my( $self) = @_;

    #Convert chunkSetID into DnaFragChunkSet object
    my $chunkset = $self->compara_dba->get_DnaFragChunkSetAdaptor->fetch_by_dbID($self->param('chunkSetID'));
    die "No ChunkSet with the id " . $self->param('chunkSetID') unless $chunkset;
    $self->param('dnaFragChunkSet', $chunkset);

    $self->param_required('faToNib_exe');

}



sub run
{
  my $self = shift;

  $self->dumpNibFiles;

  return 1;
}



##########################################
#
# internal methods
#
##########################################

sub dumpNibFiles {
  my $self = shift;

  #
  #Get all the chunks in this dnaFragChunkSet
  #
  my $chunkSet = $self->param('dnaFragChunkSet');
  #Masking options are stored in the dna_collection
  my $dna_collection = $chunkSet->dna_collection;
  my $chunk_array = $chunkSet->get_all_DnaFragChunks;

  my $starttime = time();

  unless (defined $dna_collection->dump_loc) {
    die("dump_loc directory is not defined, can not dump nib files\n");
  }

  my $dump_loc = $dna_collection->dump_loc.'/nib_files';

  #Make directory if does not exist
  if (!-e $dump_loc) {
      print "$dump_loc does not currently exist. Making directory\n";
      mkpath($dump_loc); 
  }

  foreach my $dna_object (@$chunk_array) {
      next if $dna_object->length < $self->param_required('dump_min_nib_size');

      my $nibfile = "$dump_loc/". $dna_object->dnafrag->name . ".nib";

      #don't dump nibfile if it already exists and don't want to overwrite. Default is to overwrite
      if (! -e $nibfile || $self->param("overwrite")) {
          my $fastafile = "$dump_loc/". $dna_object->dnafrag->name . ".fa";
          
          $dna_object->dnafrag->genome_db;  # to preload it before disconnecting
          $self->compara_dba->dbc->disconnect_if_idle();
          #$dna_object->dump_to_fasta_file($fastafile);
          #use this version to solve problem of very large chromosomes eg opossum
          $dna_object->dump_chunks_to_fasta_file($fastafile);
          
          if (-e $self->param('faToNib_exe')) {
              $self->run_command([$self->param('faToNib_exe'), $fastafile, $nibfile], { die_on_failure => 1, description => 'convert fasta file $fastafile to nib' } );
          } else {
              die("Unable to find faToNib. Must either define faToNib_exe or it must be in your path");
          }
          
          unlink $fastafile;
          $dna_object = undef;
      }
  }

  if($self->debug){printf("%1.3f secs to dump nib for \"%s\" collection\n", (time()-$starttime), $self->param('collection_name'));}

}


1;
