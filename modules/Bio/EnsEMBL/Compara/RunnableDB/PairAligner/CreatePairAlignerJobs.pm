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

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreatePairAlignerJobs

=cut

=head1 DESCRIPTION

Iterates over two DnaCollections (a "query" and a "target") and dataflows
all the pairs of DnaFragChunkSets (one of each collection).

Exceptions:
 - Throws if a MT DnaFragChunkSet contains more than 1 DnaFragChunk
 - Pairs crossing MT and non-MT dnafrags are not created

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreatePairAlignerJobs;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(throw);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift;

    my $dca = $self->compara_dba->get_DnaCollectionAdaptor;

    # get DnaCollection of query
    my $query_collection = $dca->fetch_by_set_description($self->param_required('query_collection_name'))
                            || die "unable to find DnaCollection with name : ". $self->param('query_collection_name');
    $self->param('query_collection', $query_collection);

    # get DnaCollection of target
    my $target_collection = $dca->fetch_by_set_description($self->param_required('target_collection_name'))
                            || die "unable to find DnaCollection with name : ". $self->param('target_collection_name');
    $self->param('target_collection', $target_collection);

    $self->print_params;
}


sub write_output
{
  my $self = shift;
  $self->createPairAlignerJobs();

  return 1;
}




##################################
#
# subroutines
#
#
sub print_params {
  my $self = shift;

  printf(" params:\n");
  printf("   method_link_species_set_id : %d\n", $self->param('method_link_species_set_id'));
  printf("   query_collection           : (%d) %s\n", 
         $self->param('query_collection')->dbID, $self->param('query_collection')->description);
  printf("   target_collection          : (%d) %s\n",
         $self->param('target_collection')->dbID, $self->param('target_collection')->description);
}


sub createPairAlignerJobs
{
  my $self = shift;

  my $query_dnafrag_chunk_set_list  = $self->param('query_collection')->get_all_DnaFragChunkSets;
  my $target_dnafrag_chunk_set_list = $self->param('target_collection')->get_all_DnaFragChunkSets;

  #get dnafrag adaptors
  my $dnafrag_adaptor = $self->compara_dba->get_DnaFragAdaptor;
  my $dnafrag_chunk_adaptor = $self->compara_dba->get_DnaFragChunkAdaptor;

  #Currently I don't pass this, but I may do in future if I need to have the options for each pairaligner job
  #instead of reading from the mlss_tag table
  my $pairaligner_hash = {
      'mlss_id' => $self->param('method_link_species_set_id'),
  };
  if ($self->param('options')) {
      $pairaligner_hash->{'options'} = $self->param('options');
  }

  # Prepopulate the cellular_component
  foreach my $query_dnafrag_chunk_set (@{$query_dnafrag_chunk_set_list}) {
    my $query_cellular_component = $query_dnafrag_chunk_set->get_all_DnaFragChunks->[0]->dnafrag->cellular_component;
    $query_dnafrag_chunk_set->{'tmp_query_cellular_component'} = $query_cellular_component;
  }

  my $count=0;
  foreach my $target_dnafrag_chunk_set (@{$target_dnafrag_chunk_set_list}) {
    
    $pairaligner_hash->{'dbChunkSetID'} = $target_dnafrag_chunk_set->dbID;

    my $target_cellular_component = $target_dnafrag_chunk_set->get_all_DnaFragChunks->[0]->dnafrag->cellular_component;

    foreach my $query_dnafrag_chunk_set (@{$query_dnafrag_chunk_set_list}) {

      my $query_cellular_component = $query_dnafrag_chunk_set->{'tmp_query_cellular_component'};

      $pairaligner_hash->{'qyChunkSetID'} = $query_dnafrag_chunk_set->dbID;

      # in !mix_cellular_components mode, we only do MT vs MT, PT vs PT, NUC vs NUC
      next if !$self->param('mix_cellular_components') and ($target_cellular_component ne $query_cellular_component);

      $self->dataflow_output_id($pairaligner_hash,2);
      $count++;
    }
  }
  printf("created %d jobs for pair aligner\n", $count);
  
  my $output_hash = {};
  $output_hash->{'method_link_species_set_id'} = $self->param('method_link_species_set_id');

  $self->dataflow_output_id($output_hash,1);

}

1;
