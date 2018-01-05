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

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreateAlignmentChainsJobs

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $runnableDB = Bio::EnsEMBL::Compara::RunnableDB::CreateAlignmentChainsJobs->new (
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$runnableDB->fetch_input(); #reads from DB
$runnableDB->run();
$runnableDB->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreateAlignmentChainsJobs;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(throw);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults() },

        'max_blocks_for_chaining'   => undef,   # If too many blocks, chaining may hang, so we allow here a maximum number of blocks (undef === no filter)
    };
}

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

  # get MethodLinkSpeciesSet
  throw("Must specify 'mlss_id' to identify a MethodLinkSpeciesSet") unless (defined($self->param('input_mlss_id')));
  $self->param('method_link_species_set', $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->param('input_mlss_id')));

  throw("unable to find method_link_species_set for mlss_id=",$self->param('input_mlss_id')) unless(defined($self->param('method_link_species_set')));

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
  $self->createAlignmentChainsJobs();
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
  printf("   method_link_species_set_id : %d\n", $self->param('method_link_species_set')->dbID);
  printf("   query_collection           : (%d) %s\n", 
         $self->param('query_collection')->dbID, $self->param('query_collection')->description);
  printf("   target_collection          : (%d) %s\n",
         $self->param('target_collection')->dbID, $self->param('target_collection')->description);
}


sub createAlignmentChainsJobs
{
  my $self = shift;

  my (%qy_dna_hash, %tg_dna_hash);

  my $max_blocks_for_chaining = $self->param('max_blocks_for_chaining');

  foreach my $dnafrag_chunk_set (@{$self->param('query_collection')->get_all_DnaFragChunkSets}) {
    my $dna_chunks = $dnafrag_chunk_set->get_all_DnaFragChunks();

    foreach my $chunk (@$dna_chunks) {
      my $dnafrag = $chunk->dnafrag;
      if (not exists $qy_dna_hash{$dnafrag->dbID}) {
        $qy_dna_hash{$dnafrag->dbID} = $dnafrag;
      }
    }
  }
  my %target_dna_hash;
  foreach my $dnafrag_chunk_set (@{$self->param('target_collection')->get_all_DnaFragChunkSets}) {
    my $dna_chunks = $dnafrag_chunk_set->get_all_DnaFragChunks();
    foreach my $chunk (@$dna_chunks) {
      my $dnafrag = $chunk->dnafrag;
      if (not exists $tg_dna_hash{$dnafrag->dbID}) {
        $tg_dna_hash{$chunk->dnafrag->dbID} = $dnafrag;
      }
    }
  }
  my $count=0;

  my $sql = "select g2.dnafrag_id, count(*) from genomic_align g1, genomic_align g2 where g1.method_link_species_set_id = ? and g1.genomic_align_block_id=g2.genomic_align_block_id and g1.dnafrag_id = ? and g1.genomic_align_id != g2.genomic_align_id group by g2.dnafrag_id";
  my $sth = $self->compara_dba->dbc->prepare($sql);

  my $reverse_pairs; # used to avoid getting twice the same results for self-comparisons
  foreach my $qy_dnafrag_id (keys %qy_dna_hash) {
    $sth->execute($self->param('method_link_species_set')->dbID, $qy_dnafrag_id);

    my $tg_dnafrag_id;
    my $block_count;
    $sth->bind_columns(\$tg_dnafrag_id, \$block_count);
    while ($sth->fetch()) {

      next unless exists $tg_dna_hash{$tg_dnafrag_id};
      next if (defined($reverse_pairs->{$qy_dnafrag_id}->{$tg_dnafrag_id}));

      if ((defined $max_blocks_for_chaining) && ($block_count > $max_blocks_for_chaining)) {
          die sprintf("There are too many alignment-blocks (%d) between '%s' (%s) and '%s' (%s). Raise the 'max_blocks_for_chaining' if you think it's ok.\n",
              $block_count, $qy_dna_hash{$qy_dnafrag_id}->name, $self->param('query_collection')->name, $tg_dna_hash{$tg_dnafrag_id}->name, $self->param('target_collection')->name);
      }
      
      my $input_hash = {};

      $input_hash->{'qyDnaFragID'} = $qy_dnafrag_id;
      $input_hash->{'tgDnaFragID'} = $tg_dnafrag_id;

      $input_hash->{'input_mlss_id'} = $self->param('method_link_species_set')->dbID;
      $input_hash->{'output_mlss_id'} = $self->param('output_mlss_id');

      if ($self->param('query_collection')->dump_loc) {
        my $nib_file = $self->param('query_collection')->dump_loc 
            . "/" 
            . $qy_dna_hash{$qy_dnafrag_id}->name 
            . ".nib";
        if (-e $nib_file) {
          $input_hash->{'query_nib_dir'} = $self->param('query_collection')->dump_loc;
        }
      }
      if ($self->param('target_collection')->dump_loc) {
        my $nib_file = $self->param('target_collection')->dump_loc 
            . "/" 
            . $tg_dna_hash{$tg_dnafrag_id}->name
            . ".nib";
        if (-e $nib_file) {
          $input_hash->{'target_nib_dir'} = $self->param('target_collection')->dump_loc;
        }
      }
      $reverse_pairs->{$tg_dnafrag_id}->{$qy_dnafrag_id} = 1;

      $self->dataflow_output_id($input_hash, 2);
      $count++;
    }
  }
  $sth->finish;

  if ($count == 0) {
      # No alignments have been found. Do not produce any alignment_chain jobs
      $self->input_job->autoflow(0);

    print "No jobs created\n";
  } else {
    printf("created %d jobs for AlignmentChains\n", $count);
  }

  #
  #Flow to 'update_max_alignment_length_after_chain' on branch 1
  #
  my $output_hash = {};
  %$output_hash = ('method_link_species_set_id' => $self->param('output_mlss_id'));
  $self->dataflow_output_id($output_hash,1);

}

1;
