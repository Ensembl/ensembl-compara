=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::StoreSequence

=head1 DESCRIPTION

This object gets the DnaFrag objects from a DnaFragChunkSet and stores the
sequence (if short enough) in the Compara sequence table.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_).

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::StoreSequence;

use strict;
use warnings;

use Time::HiRes qw(time);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my( $self) = @_;

    # Add the genome dumps directory to avoid as many connections to external core
    # databases as possible
    $self->compara_dba->get_GenomeDBAdaptor->dump_dir_location($self->param_required('genome_dumps_dir'));

    #Convert chunkSetID into DnaFragChunkSet object
    my $chunkset = $self->compara_dba->get_DnaFragChunkSetAdaptor->fetch_by_dbID($self->param_required('chunkSetID'));
    die "No ChunkSet with the id " . $self->param('chunkSetID') unless $chunkset;
    $self->param('dnaFragChunkSet', $chunkset);
    
    return 1;
}


sub write_output {  
  my ($self) = @_;

  #
  #Get all the chunks in this dnaFragChunkSet
  #
  my $chunkSet = $self->param('dnaFragChunkSet');
  #Masking options are stored in the dna_collection
  my $dna_collection = $chunkSet->dna_collection;
  my $chunk_array = $chunkSet->get_all_DnaFragChunks;

  foreach my $chunk ( @{$chunk_array} ) {
      $chunk->masking($dna_collection->masking);
      $chunk->fetch_masked_sequence;
  }

  if (my $dump_loc = $dna_collection->dump_loc) {
          my $starttime = time();
          $chunkSet->dump_to_fasta_file($chunkSet->dump_loc_file);
          if($self->debug){printf("%1.3f secs to dump ChunkSet %d for \"%s\" collection\n", (time()-$starttime), $chunkSet->dbID, $dna_collection->description);}
      foreach my $chunk (@$chunk_array) {
              my $starttime = time();
              $chunk->dump_to_fasta_file($chunk->dump_loc_file($dna_collection));
              if($self->debug){printf("%1.3f secs to dump Chunk %d for \"%s\" collection\n", (time()-$starttime), $chunk->dbID, $dna_collection->description);}
      }
  }

  return 1;
}
1;
