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

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreateFilterDuplicatesJobs

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $runnable = Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreateFilterDuplicatesJobs->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$runnable->fetch_input(); #reads from DB
$runnable->run();
$runnable->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreateFilterDuplicatesJobs;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Compara::Production::DnaCollection;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
  my $self = shift;

  # get DnaCollection
  throw("must specify 'collection_name' to identify DnaCollection") 
    unless(defined($self->param('collection_name')));
  $self->param('collection', $self->compara_dba->get_DnaCollectionAdaptor->
	       fetch_by_set_description($self->param('collection_name')));
  throw("unable to find DnaCollection with name : ". $self->param('collection_name'))
    unless(defined($self->param('collection')));


  $self->print_params;

  return 1;
}


sub run
{
  my $self = shift;
  $self->createFilterDuplicatesJobs();
  return 1;
}


sub write_output
{
  my $self = shift;
  return 1;
}




##################################
#
# subroutines
#
##################################

sub print_params {
  my $self = shift;

  printf(" params:\n");
  printf("   logic_name : %s\n", $self->param('logic_name'));
  printf("   collection           : (%d) %s\n", 
         $self->param('collection')->dbID, $self->param('collection')->description);
  #if (defined $self->param('region')) {
    #printf("   region          : %s\n", $self->param('region'));
  #}
  if (defined $self->param('method_link_species_set_id')) {
    printf("   method_link_species_set_id          : %s\n", $self->param('method_link_species_set_id'));
  }
}


sub createFilterDuplicatesJobs
{
  my $self = shift;

  my $dna_collection  = $self->param('collection');
  #my $region = $self->param('region');

  #Now that we allow more than one region, this causes too many complications here.
  #Remove this as not restricting the region shouldn't make any difference because the alignments will
  #only be on restricted regions of the dnafrag anyway.
  #my ($coord_system_name, $seq_region_name, $seq_region_start, $seq_region_end);
  #if (defined $region && $region =~ //) {
  #  ($coord_system_name, $seq_region_name, $seq_region_start, $seq_region_end) = split(/:/, $region);
  #}

  my %dnafrag_id_list;
  my $dnafrag_chunk_sets = $dna_collection->get_all_DnaFragChunkSets();
  foreach my $dnafrag_chunk_set (@$dnafrag_chunk_sets) {
      my $dnafrag_chunks = $dnafrag_chunk_set->get_all_DnaFragChunks();
      foreach my $dnafrag_chunk (@$dnafrag_chunks) {
          $dnafrag_id_list{$dnafrag_chunk->dnafrag_id} = 1;
      }
  }

  my $count = 0;
  foreach my $dnafrag_id (keys %dnafrag_id_list) {
    my $input_hash = {};
    $input_hash->{'dnafrag_id'} = $dnafrag_id;
    #$input_hash->{'seq_region_start'} = $seq_region_start if (defined $seq_region_start);
    #$input_hash->{'seq_region_end'} = $seq_region_end if (defined $seq_region_end);

    $self->dataflow_output_id($input_hash,2);
    
    $count++;
  }
  printf("created %d jobs\n", $count);
}

1;
