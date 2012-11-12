=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreatePairAlignerJobs

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreatePairAlignerJobs->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$repmask->fetch_input(); #reads from DB
$repmask->run();
$repmask->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreatePairAlignerJobs;

use strict;

use Bio::EnsEMBL::Analysis::RunnableDB;
use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;
use Bio::EnsEMBL::Compara::Production::DnaCollection;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
  my $self = shift;

  # get DnaCollection of query
  throw("must specify 'query_collection_name' to identify DnaCollection of query") 
    unless(defined($self->param('query_collection_name')));
  $self->param('query_collection', $self->compara_dba->get_DnaCollectionAdaptor->
                                fetch_by_set_description($self->param('query_collection_name')));
  throw("unable to find DnaCollection with name : ". $self->param('query_collection_name'))
    unless(defined($self->param('query_collection')));

  # get DnaCollection of target
  throw("must specify 'target_collection_name' to identify DnaCollection of query") 
    unless(defined($self->param('target_collection_name')));
  $self->param('target_collection', $self->compara_dba->get_DnaCollectionAdaptor->
                                fetch_by_set_description($self->param('target_collection_name')));
  throw("unable to find DnaCollection with name : ". $self->param('target_collection_name'))
    unless(defined($self->param('target_collection')));


  $self->print_params;
    
  
  return 1;
}


sub run
{
  my $self = shift;
  return 1;
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
  my $dnafrag_chunk_set_adaptor = $self->compara_dba->get_DnaFragChunkSetAdaptor;
  
  my $count=0;
  foreach my $target_dnafrag_chunk_set (@{$target_dnafrag_chunk_set_list}) {
    my $pairaligner_hash = {};
    
    $pairaligner_hash->{'mlss_id'} = $self->param('method_link_species_set_id');

    if ($self->param('target_collection')->dump_loc) {
	$pairaligner_hash->{'target_fa_dir'} = $self->param('target_collection')->dump_loc;
    }

    #Currently I don't pass this, but I may do in future if I need to have the options for each pairaligner job 
    #instead of reading from the mlss_tag table
    if ($self->param('options')) {
        $pairaligner_hash->{'options'} = $self->param('options');
    }

    $pairaligner_hash->{'dbChunkSetID'} = undef;
    $pairaligner_hash->{'dbChunkSetID'} = $target_dnafrag_chunk_set->dbID;

    #find the target dnafrag name to check if it is MT. It can only be part of set of 1
    my ($first_db_chunk) = @{$target_dnafrag_chunk_set->get_all_DnaFragChunks};
    my $target_dnafrag_name = $first_db_chunk->dnafrag->name;

    foreach my $query_dnafrag_chunk_set (@{$query_dnafrag_chunk_set_list}) {
      $pairaligner_hash->{'qyChunkSetID'} = undef;

      #find the query dnafrag name to check if it is MT. It can only be part of a set of 1
      my ($first_qy_chunk) = @{$query_dnafrag_chunk_set->get_all_DnaFragChunks};
      my $query_dnafrag_name = $first_qy_chunk->dnafrag->name;

      $pairaligner_hash->{'qyChunkSetID'} = $query_dnafrag_chunk_set->dbID;
      
      #only allow mitochrondria chromosomes to find matches to each other
      next if (($query_dnafrag_name eq "MT" && $target_dnafrag_name ne "MT") || 
	      ($query_dnafrag_name ne "MT" && $target_dnafrag_name eq "MT"));

      #Skip MT unless param is set
      next if ($query_dnafrag_name eq "MT" && $target_dnafrag_name eq "MT" && !$self->param('include_MT'));

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
