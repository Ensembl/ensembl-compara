=head1 LICENSE

  Copyright (c) 1999-2011 The European Bioinformatics Institute and
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

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreateFilterDuplicatesJobs

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreateFilterDuplicatesJobs->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$repmask->fetch_input(); #reads from DB
$repmask->run();
$repmask->output();
$repmask->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreateFilterDuplicatesJobs;

use strict;

#use Bio::EnsEMBL::Hive;
#use Bio::EnsEMBL::Hive::Extensions;

use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;

use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;
use Bio::EnsEMBL::Compara::Production::DnaCollection;
use Bio::EnsEMBL::Utils::Exception;

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
  if (defined $self->param('region')) {
    printf("   region          : %s\n", $self->param('region'));
  }
  if (defined $self->param('method_link_species_set_id')) {
    printf("   method_link_species_set_id          : %s\n", $self->param('method_link_species_set_id'));
  }
}


sub createFilterDuplicatesJobs
{
  my $self = shift;

  my $dna_collection  = $self->param('collection');
  my $analysis = $self->param('filter_duplicates_analysis');
  my $region = $self->param('region');
  my $mlss_id = $self->param('method_link_species_set_id');

  #Now that we allow more than one region, this causes too many complications here.
  #Remove this as not restricting the region shouldn't make any difference because the alignments will
  #only be on restricted regions of the dnafrag anyway.
  #my ($coord_system_name, $seq_region_name, $seq_region_start, $seq_region_end);
  #if (defined $region && $region =~ //) {
  #  ($coord_system_name, $seq_region_name, $seq_region_start, $seq_region_end) = split(/:/, $region);
  #}

  my $dnafrag_id_list = $dna_collection->get_all_dnafrag_ids;

  my $count = 0;
  my %already_seen_dnafrag_ids;
  foreach my $dnafrag_id (@{$dnafrag_id_list}) {
    next if (defined $already_seen_dnafrag_ids{$dnafrag_id});
    my $input_hash = {};
    $input_hash->{'dnafrag_id'} = $dnafrag_id;
    #$input_hash->{'seq_region_start'} = $seq_region_start if (defined $seq_region_start);
    #$input_hash->{'seq_region_end'} = $seq_region_end if (defined $seq_region_end);
    $input_hash->{'method_link_species_set_id'} = $mlss_id if (defined $mlss_id);
    
    $self->dataflow_output_id($input_hash,2);
    
    $already_seen_dnafrag_ids{$dnafrag_id} = 1;
    $count++;
  }
  printf("created %d jobs\n", $count);
}

1;
