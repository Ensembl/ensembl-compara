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

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::StoreSequence

=cut

=head1 SYNOPSIS

my $db       = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $runnable = Bio::EnsEMBL::Compara::RunnableDB::PairAligner::StoreSequence>new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$runnable->fetch_input(); #reads from DB
$runnable->run();
$runnable->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This object gets the DnaFrag objects from a DnaFragChunkSet and stores the sequence (if short enough) in the Compara sequence table

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::StoreSequence;

use strict;
use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::EnsEMBL::Analysis::RunnableDB;
use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;
use Bio::EnsEMBL::Compara::Production::DnaCollection;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   prepares global variables and DB connections
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
    my( $self) = @_;

    #Convert chunkSetID into DnaFragChunkSet object
    my $chunkset = $self->compara_dba->get_DnaFragChunkSetAdaptor->fetch_by_dbID($self->param('chunkSetID'));
    $self->param('dnaFragChunkSet', $chunkset);
    
    return 1;
}


sub run {
  my ($self) = @_;

  return 1;
}


sub write_output {  
  my ($self) = @_;

  #
  #Get all the chunks in this dnaFragChunkSet
  #
  if (defined $self->param('dnaFragChunkSet')) {
      my $chunkSet = $self->param('dnaFragChunkSet');
      #Masking options are stored in the dna_collection
      my $dna_collection = $chunkSet->dna_collection;
      my $chunk_array = $chunkSet->get_all_DnaFragChunks;
      
      #Store sequence in Sequence table
      foreach my $chunk (@$chunk_array) {
          $chunk->masking_options($dna_collection->masking_options);
	  my $bioseq = $chunk->bioseq;
	  if($chunk->sequence_id==0) {
	      $self->compara_dba->get_DnaFragChunkAdaptor->update_sequence($chunk);
	  }
      }
  }

  return 1;
}
1;
