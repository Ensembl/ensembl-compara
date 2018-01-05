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

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreateAlignmentNetsJobs

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::CreateAlignmentNetsJobs;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
  my $self = shift;

  if (defined ($self->param('query_collection_name'))) {
      $self->param('collection_name', $self->param('query_collection_name'));
  }

  # get DnaCollection of query
  throw("must specify 'collection_name' to identify DnaCollection of query") 
    unless(defined($self->param('collection_name')));
  $self->param('collection', $self->compara_dba->get_DnaCollectionAdaptor->
	       fetch_by_set_description($self->param('collection_name')));
  throw("unable to find DnaCollection with name : ". $self->param('collection_name'))
    unless(defined($self->param('collection')));

  #get the MethodLinkSpeciesSet
  throw("Must specify 'mlss_id' to identify a MethodLinkSpeciesSet") unless (defined($self->param('input_mlss_id')));
  $self->param('method_link_species_set', $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->param('input_mlss_id')));

  throw("unable to find method_link_species_set for mlss_id=",$self->param('input_mlss_id')) unless(defined($self->param('method_link_species_set')));

  $self->print_params;

  return 1;
}


sub run {
  my $self = shift;
  return 1;
}


sub write_output {
  my $self = shift;
  $self->createAlignmentNetsJobs();

  return 1;
}

sub print_params {
  my $self = shift;

  printf(" params:\n");
  printf("   method_link_species_set_id : %d\n", $self->param('method_link_species_set')->dbID);
  printf("   collection           : (%d) %s\n", 
         $self->param('collection')->dbID, $self->param('collection')->description);
}


sub createAlignmentNetsJobs {
  my $self = shift;

  my $query_dnafrag_chunk_sets  = $self->param('collection')->get_all_DnaFragChunkSets;

  my $count=0;
#  my $sql ="select group_id,min(dnafrag_start) as min,max(dnafrag_end) as max from genomic_align ga, genomic_align_group gag where ga.genomic_align_id=gag.genomic_align_id and ga.method_link_species_set_id = ? and ga.dnafrag_id= ? and gag.type = ? group by group_id order by min asc,max asc";

  my $sql = "select ga.dnafrag_start, ga.dnafrag_end from genomic_align ga, genomic_align_block gab where ga.genomic_align_block_id=gab.genomic_align_block_id and ga.method_link_species_set_id= ? and ga.dnafrag_id= ? order by dnafrag_start asc, dnafrag_end asc";

  my $sth = $self->compara_dba->dbc->prepare($sql);

  foreach my $qy_dnafrag_chunk_set (@{$query_dnafrag_chunk_sets}) {
      foreach my $qy_dnafrag_chunk (@{$qy_dnafrag_chunk_set->get_all_DnaFragChunks()}) {
        my $qy_dnafrag_id = $qy_dnafrag_chunk->dnafrag->dbID;
        $sth->execute($self->param('method_link_species_set')->dbID, $qy_dnafrag_id);
        my ($dnafrag_start,$dnafrag_end);
        $sth->bind_columns(\$dnafrag_start, \$dnafrag_end);
        my ($slice_start,$slice_end);
        my @genomic_slices;
        while ($sth->fetch()) {
           unless (defined $slice_start) {
               ($slice_start,$slice_end) = ($dnafrag_start, $dnafrag_end);
               next;
           }
           if ($dnafrag_start > $slice_end) {
               push @genomic_slices, [$slice_start,$slice_end];
               ($slice_start,$slice_end) = ($dnafrag_start, $dnafrag_end);
           } else {
               if ($dnafrag_end > $slice_end) {
                   $slice_end = $dnafrag_end;
               }
           }
       }
        $sth->finish;
        
        # Skip if no alignments are found on this slice
        next if (!defined $slice_start || !defined $slice_end);
        
        push @genomic_slices, [$slice_start,$slice_end];
        
        my @grouped_genomic_slices;
        undef $slice_start;
        undef $slice_end;
        my $max_slice_length = 500000;
        while (my $genomic_slices = shift @genomic_slices) {
            my ($start, $end) = @{$genomic_slices};
            unless (defined $slice_start) {
                ($slice_start,$slice_end) = ($start, $end);
                next;
            }
            my $slice_length = $slice_end - $slice_start + 1;
            my $length = $end - $start + 1;
            if ($slice_length > $max_slice_length || $slice_length + $length > $max_slice_length) {
                push @grouped_genomic_slices, [$slice_start,$slice_end];
                  ($slice_start,$slice_end) = ($start, $end);
            } else {
                $slice_end = $end;
            }
        }
        push @grouped_genomic_slices, [$slice_start,$slice_end];
        
        while (my $genomic_slices = shift @grouped_genomic_slices) {
            my ($start, $end) = @{$genomic_slices};
            my $input_hash = {};
            $input_hash->{'start'} = $start;
            $input_hash->{'end'} = $end;
            $input_hash->{'DnaFragID'} = $qy_dnafrag_id;
            $input_hash->{'input_mlss_id'} = $self->param('method_link_species_set')->dbID;
            $input_hash->{'output_mlss_id'} = $self->param('output_mlss_id');
            
            $self->dataflow_output_id($input_hash, 2);
            $count++;
        }
    }
  }
  if ($count == 0) {
      # No alignments have been found.
      $self->input_job->autoflow(0);
      print "No jobs created\n";
  } else {
      printf("created %d jobs for AlignmentNets\n", $count);
  }
  
  #
  #Flow to 'set_internal_ids' and 'update_max_alignment_length_after_net' on branch 1
  #
  my $output_hash = {};
  %$output_hash = ('method_link_species_set_id' => $self->param('output_mlss_id'));
  $self->dataflow_output_id($output_hash,1);

}

1;
