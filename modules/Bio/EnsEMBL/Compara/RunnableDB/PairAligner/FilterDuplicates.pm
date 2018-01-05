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

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::FilterDuplicates

=cut

=head1 DESCRIPTION

This analysis/RunnableDB is designed to run after all GenomicAlignBlock entries for a 
specific MethodLinkSpeciesSet has been completed and filters out all duplicate entries
which can result from jobs being rerun or from regions of overlapping chunks generating
the same HSP hits.  It takes as input (on the input_id string) 

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::FilterDuplicates;

use strict;
use warnings;

use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Compara::Production::DnaFragChunk;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;


use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'window_size'   => 1000000,
    }
}


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   prepares global variables and DB connections
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  throw("No dnafrag_id specified") unless defined($self->param('dnafrag_id'));
  throw("Window size (".$self->param('window_size').")must be > 0") if (!$self->param('window_size') or $self->param('window_size') <= 0);
  $self->print_params;

}


sub run
{
  my $self = shift;
  $self->filter_duplicates;
}



######################################
#
# subroutines
#
#####################################


sub print_params {
  my $self = shift;

  print(" params:\n");
  print("   method_link_species_set_id : ", $self->param('method_link_species_set_id'),"\t");
  print "chunk_size ", $self->param('chunk_size'), " overlap ", $self->param('overlap'), "\n";
}


sub filter_duplicates {
  my $self = shift;

  my $overlap = $self->param('overlap');
  my $chunk_size = $self->param('chunk_size');
  my $window_size = $self->param('window_size');

  $self->param('overlap_count', 0);
  $self->param('identical_count', 0);
  $self->param('gab_count', 0);
  $self->param('truncate_count', 0);
  $self->param('not_truncate_count', 0);
  $self->param('delete_hash', {}); #all the genomic_align_blocks that need to be deleted

  my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->param('method_link_species_set_id'));
  $self->param('is_self_alignment', (scalar(@{ $mlss->species_set->genome_dbs }) == 1 ? 1 : 0));
#  my ($gdb1, $gdb2) = @{$mlss->species_set->genome_dbs};
#  if($gdb1->dbID > $gdb2->dbID) {
#    my $tmp = $gdb1; $gdb1=$gdb2; $gdb2=$tmp;
#  }

  my $GAB_DBA = $self->compara_dba->get_GenomicAlignBlockAdaptor;
  # create a list of dnafrag here in case we want to make this runnable working with an input_id 
  # containing a list of dnafrag_ids
  my $dnafrag_list = [$self->compara_dba->get_DnaFragAdaptor->fetch_by_dbID($self->param('dnafrag_id'))];

  foreach my $dnafrag (@{$dnafrag_list}) {
    my $seq_region_start = $self->param('seq_region_start');
    $seq_region_start = 1 unless (defined $seq_region_start);
    #printf("dnafrag (%d)%s:%s len=%d\n", $dnafrag->dbID, $dnafrag->coord_system_name, $dnafrag->name, $dnafrag->length);
    my $seq_region_end = $self->param('seq_region_end');
    $seq_region_end = $dnafrag->length unless (defined $seq_region_end);

    if ($dnafrag->is_reference) {
	#find identical matches over all the dnafrag
	$self->find_identical_matches($seq_region_start, $seq_region_end, $window_size, $mlss, $dnafrag);
	
	#find edge artefacts only in the overlap regions
	if (defined $overlap && $overlap > 0) {
	    $self->find_edge_artefacts($seq_region_start, $seq_region_end, $overlap, $chunk_size, $mlss, $dnafrag);
	}
    } else {
	#get correct start and end if non_reference eg haplotype. 
	#NB cannot overwrite by defining seq_region_start and seq_region_end
	    my $slice_adaptor = $dnafrag->genome_db->db_adaptor->get_SliceAdaptor;
	    my $slices = $slice_adaptor->fetch_by_region_unique($dnafrag->coord_system_name, $dnafrag->name);
	    foreach my $slice (@$slices) {
		my $seq_region_start = $slice->start;
		my $seq_region_end = $slice->end;

		#find identical matches over all the dnafrag
		$self->find_identical_matches($seq_region_start, $seq_region_end, $window_size, $mlss, $dnafrag);
		
		#find edge artefacts only in the overlap regions
		if (defined $overlap && $overlap > 0) {
		    $self->find_edge_artefacts($seq_region_start, $seq_region_end, $overlap, $chunk_size, $mlss, $dnafrag);
		}
	    }
    }
  }

  my @del_list = keys(%{$self->param('delete_hash')});

  my $sql_ga = "delete ignore from genomic_align where genomic_align_block_id in ";
  my $sql_gab = "delete ignore from genomic_align_block where genomic_align_block_id in ";

  for (my $i=0; $i < scalar @del_list; $i=$i+1000) {
      my (@gab_ids);
      for (my $j = $i; ($j < scalar @del_list && $j < $i+1000); $j++) {
	  push @gab_ids, $del_list[$j];
      }
      my $sql_gab_to_exec = $sql_gab . "(" . join(",", @gab_ids) . ")";
      my $sql_ga_to_exec = $sql_ga . "(" . join(",", @gab_ids) . ")";
 
      foreach my $sql ($sql_ga_to_exec,$sql_gab_to_exec) {
 	  my $sth = $self->compara_dba->dbc->prepare($sql);
 	  $sth->execute;
 	  $sth->finish;
       }
  }

  printf("%d gabs to delete\n", scalar(keys(%{$self->param('delete_hash')})));
  printf("found %d equal GAB pairs\n", $self->param('identical_count'));
  printf("found %d overlapping GABs\n", $self->param('overlap_count'));
  printf("%d GABs loaded\n", $self->param('gab_count'));
  printf("%d TRUNCATE gabs\n", $self->param('truncate_count'));
  printf("%d not TRUNCATE gabs\n", $self->param('not_truncate_count'));
}

#Remove identical matches over all the dnafrag to remove matches either from 
#overlaps or because a job has been run more than once
sub find_identical_matches {
    my ($self, $region_start, $seq_region_end, $window_size, $mlss, $dnafrag) = @_;

    return $self->_process_gabs_per_chunk($region_start, $seq_region_end, $window_size, $window_size, $mlss, $dnafrag, 'removed_equals_from_genomic_align_block_list');
}

#Remove matches spanning the overlap using "in_chunk_overlap" mode which 
#checks just the region of the overlap and not the whole dnafrag
sub find_edge_artefacts {
    my ($self, $region_start, $seq_region_end, $overlap, $chunk_size, $mlss, $dnafrag) = @_;

    return $self->_process_gabs_per_chunk($region_start+$chunk_size-$overlap, $seq_region_end, $chunk_size-$overlap, $overlap-1, $mlss, $dnafrag, 'remove_edge_artifacts_from_genomic_align_block_list');
}

# Convenient method to check $dnafrag with a sliding window
sub _process_gabs_per_chunk {
    my ($self, $region_start, $seq_region_end, $step_size, $window_size, $mlss, $dnafrag, $method) = @_;

    my $GAB_DBA = $self->compara_dba->get_GenomicAlignBlockAdaptor;

    while($region_start <= $seq_region_end) {
        my $region_end = $region_start + $window_size;

        my $genomic_align_block_list = $GAB_DBA->fetch_all_by_MethodLinkSpeciesSet_DnaFrag($mlss, $dnafrag, $region_start, $region_end);

        if ($self->param('is_reference')) {
            $genomic_align_block_list = [grep {($_->reference_genomic_align->dnafrag_id != $_->get_all_non_reference_genomic_aligns->[0]->dnafrag_id) || ($_->reference_genomic_align_id < $_->get_all_non_reference_genomic_aligns->[0]->dbID)} @$genomic_align_block_list];
        } else {
            $genomic_align_block_list = [grep {($_->reference_genomic_align->dnafrag_id != $_->get_all_non_reference_genomic_aligns->[0]->dnafrag_id) || ($_->reference_genomic_align_id > $_->get_all_non_reference_genomic_aligns->[0]->dbID)} @$genomic_align_block_list];
        }
        printf STDERR "PROCESS GABS: dnafrag %s %s %d:%d has %d GABs\n", $dnafrag->coord_system_name, $dnafrag->name, $region_start, $region_end, scalar(@$genomic_align_block_list);

        # first sort the list for processing
        my @sorted_GABs = sort sort_alignments @$genomic_align_block_list;
        $self->param('gab_count', $self->param('gab_count')+scalar(@sorted_GABs));
        # and call the method
        $self->$method(\@sorted_GABs, $region_start, $region_end);
        $region_start += $step_size;
    }
}

sub sort_alignments{
  # $a,$b are GenomicAlignBlock objects
  my $a_ref = $a->reference_genomic_align;
  my ($a_other) = @{$a->get_all_non_reference_genomic_aligns};
  my $b_ref = $b->reference_genomic_align;
  my ($b_other) = @{$b->get_all_non_reference_genomic_aligns};

  return 
    ($a_other->dnafrag_id <=> $b_other->dnafrag_id) ||
    ($a_ref->dnafrag_strand <=> $b_ref->dnafrag_strand) ||
    ($a_other->dnafrag_strand <=> $b_other->dnafrag_strand) ||
    ($a_ref->dnafrag_start <=> $b_ref->dnafrag_start) ||
    ($a_ref->dnafrag_end <=> $b_ref->dnafrag_end) ||
    ($a_other->dnafrag_start <=> $b_other->dnafrag_start) ||
    ($a_other->dnafrag_end <=> $b_other->dnafrag_end) ||
    ($a->score <=> $b->score) ||
    ($a->dbID <=> $b->dbID);
}

sub remove_deletes_from_list {
  my $self = shift;
  my $genomic_align_block_list = shift;

  my @new_list;  
  foreach my $gab (@$genomic_align_block_list) {
    push @new_list, $gab unless($self->param('delete_hash')->{$gab->dbID});
  }
  @$genomic_align_block_list = @new_list;
  return $genomic_align_block_list; 
}


sub removed_equals_from_genomic_align_block_list {
  my $self = shift;
  my $genomic_align_block_list = shift;
  
  # Flag to define whether we are filtering raw alignments or net alignments
  # By default, it is set to raw alignment
  my $filter_duplicates_net = 0;
  if (defined $self->param('filter_duplicates_net')) {
  	$filter_duplicates_net = $self->param('filter_duplicates_net');
  }
  
  return unless(scalar(@$genomic_align_block_list));
  if($self->debug > 2) {
    for(my $index=0; $index<(scalar(@$genomic_align_block_list)); $index++) {
      my $gab1 = $genomic_align_block_list->[$index];
      print_gab($gab1);
    }
  }
  for(my $index=0; $index<(scalar(@$genomic_align_block_list)); $index++) {
    my $gab1 = $genomic_align_block_list->[$index];
    next if($self->param('delete_hash')->{$gab1->dbID}); #already deleted so skip it
    
    for(my $index2=$index+1; $index2<(scalar(@$genomic_align_block_list)); $index2++) {
      my $gab2 = $genomic_align_block_list->[$index2];
      last if($gab2->reference_genomic_align->dnafrag_start > 
              $gab1->reference_genomic_align->dnafrag_start);

      next if($self->param('delete_hash')->{$gab2->dbID}); #already deleted so skip it

      if(genomic_align_blocks_identical($gab1, $gab2)) {
        if($gab1->score != $gab2->score) {
          # Choose which one to delete based on the score first
          if ($gab1->score > $gab2->score) {
            $self->param('delete_hash')->{$gab2->dbID} = 1;
          }
          else {
            $self->param('delete_hash')->{$gab1->dbID} = 1;
          }
        } else {
          # If scores are identical, keep the block with lower id
          if ($gab1->dbID < $gab2->dbID) {
            $self->param('delete_hash')->{$gab2->dbID} = 1;
          }
          else {
            $self->param('delete_hash')->{$gab1->dbID} = 1;
          }
        }
        $self->param('identical_count', $self->param('identical_count')+1);        
      }
      elsif ($filter_duplicates_net) {
	  # At the net step, check for overlapping blocks as well
	  if (genomic_align_blocks_overlap ($gab1, $gab2)) {
	      if($gab1->score >= $gab2->score) {
		  $self->param('delete_hash')->{$gab2->dbID} = 1;
	      } else {
		  $self->param('delete_hash')->{$gab1->dbID} = 1;
	      }
	      $self->param('identical_count', $self->param('identical_count')+1);       
	  }
      }
    }
  }

  $self->remove_deletes_from_list($genomic_align_block_list);
}


sub remove_edge_artifacts_from_genomic_align_block_list {
  my $self = shift;
  my $genomic_align_block_list = shift;
  my $region_start = shift;
  my $region_end = shift;
  
  return unless(scalar(@$genomic_align_block_list));
  
  for(my $index=0; $index<(scalar(@$genomic_align_block_list)); $index++) {
    my $gab1 = $genomic_align_block_list->[$index];
    next if($self->param('delete_hash')->{$gab1->dbID}); #already deleted so skip it

    for(my $index2=$index+1; $index2<(scalar(@$genomic_align_block_list)); $index2++) {
      my $gab2 = $genomic_align_block_list->[$index2];
      last if($gab2->reference_genomic_align->dnafrag_start > 
              $gab1->reference_genomic_align->dnafrag_end);
      next if($self->param('delete_hash')->{$gab2->dbID}); #already deleted so skip it

      if(genomic_align_blocks_overlap($gab1, $gab2)) {
        $self->param('overlap_count', $self->param('overlap_count')+1);

        unless($self->process_overlap_for_chunk_edge_truncation($gab1, $gab2, $region_start, $region_end)) {
          if($self->debug) {
            print("  "); print_gab($gab1);
            print("  "); print_gab($gab2);
          }
        }
      } 
    }
  }
  #printf("found %d identical, %d overlapping GABs\n", $self->param('identical_count'), $self->param('overlap_count'));  

  $self->remove_deletes_from_list($genomic_align_block_list);
}


sub print_gab {
  my $gab = shift;
  
  my ($gab_1, $gab_2) = @{$gab->genomic_align_array};
  printf(" id(%d)  %s:(%d)%d-%d    %s:(%d)%d-%d  score=%d\n", 
         $gab->dbID,
         $gab_1->dnafrag->name, $gab_1->dnafrag_strand, $gab_1->dnafrag_start, $gab_1->dnafrag_end,
         $gab_2->dnafrag->name, $gab_2->dnafrag_strand, $gab_2->dnafrag_start, $gab_2->dnafrag_end,
         $gab->score);
}


sub genomic_align_blocks_identical {
  my ($gab1, $gab2) = @_;
  
  my ($gab1_1, $gab1_2) = sort {$a->dnafrag_id <=> $b->dnafrag_id} @{$gab1->genomic_align_array};
  my ($gab2_1, $gab2_2) = sort {$a->dnafrag_id <=> $b->dnafrag_id} @{$gab2->genomic_align_array};

  return 0 if(($gab1_1->dnafrag_id != $gab2_1->dnafrag_id) or ($gab1_2->dnafrag_id != $gab2_2->dnafrag_id));
  return 0 if(($gab1_1->dnafrag_strand != $gab2_1->dnafrag_strand) or ($gab1_2->dnafrag_strand != $gab2_2->dnafrag_strand));

  return 0 if(($gab1_1->dnafrag_start != $gab2_1->dnafrag_start) or ($gab1_1->dnafrag_end != $gab2_1->dnafrag_end));  
  return 0 if(($gab1_2->dnafrag_start != $gab2_2->dnafrag_start) or ($gab1_2->dnafrag_end != $gab2_2->dnafrag_end));  
  
  # if they have different score, let's still consider them as identical
  #return 0 if($gab1->score != $gab2->score);

  return 0 if($gab1_1->cigar_line ne $gab2_1->cigar_line);  
  return 0 if($gab1_2->cigar_line ne $gab2_2->cigar_line);
  
  return 1;
}


sub genomic_align_blocks_overlap {
  my ($gab1, $gab2) = @_;
  
  my ($gab1_1, $gab1_2) = sort {$a->dnafrag_id <=> $b->dnafrag_id} @{$gab1->genomic_align_array};
  my ($gab2_1, $gab2_2) = sort {$a->dnafrag_id <=> $b->dnafrag_id} @{$gab2->genomic_align_array};
  
  return 0 if(($gab1_1->dnafrag_id != $gab2_1->dnafrag_id) or ($gab1_2->dnafrag_id != $gab2_2->dnafrag_id));
  return 0 if(($gab1_1->dnafrag_strand != $gab2_1->dnafrag_strand) or ($gab1_2->dnafrag_strand != $gab2_2->dnafrag_strand));

  return 0 if(($gab1_1->dnafrag_end < $gab2_1->dnafrag_start) or ($gab1_1->dnafrag_start > $gab2_1->dnafrag_end));  
  return 0 if(($gab1_2->dnafrag_end < $gab2_2->dnafrag_start) or ($gab1_2->dnafrag_start > $gab2_2->dnafrag_end));  
  
  return 1;
}


sub process_overlap_for_chunk_edge_truncation {
  my ($self, $gab1, $gab2, $region_start, $region_end) = @_;
   
  my $aligns_1_1 = $gab1->reference_genomic_align;
  my $aligns_1_2 = $gab1->get_all_non_reference_genomic_aligns->[0];
  my $aligns_2_1 = $gab2->reference_genomic_align;
  my $aligns_2_2 = $gab2->get_all_non_reference_genomic_aligns->[0];
    
  #first test if this overlapping pair is such that one of them crosses
  #one of the region boundaries and the other one does not
  #Processings is done such that we walk through the overlap regions of 
  #one genome, which in the GAB is the 'reference' so only need to test the
  #reference for region_edge artifacts.
  #IF both genomes are chunked and overlapped, then this needs to be run twice
  #1) with genome1 on the genome1 chunking regions
  #2) with genome2 on the genome2 chunking regions
  return undef 
    unless((($aligns_1_1->dnafrag_start < $region_start) and
            ($aligns_2_1->dnafrag_start >= $region_start))
           or
           (($aligns_1_1->dnafrag_start >= $region_start) and
            ($aligns_2_1->dnafrag_start < $region_start))
           or
           (($aligns_1_1->dnafrag_end > $region_end) and
            ($aligns_2_1->dnafrag_end <= $region_end))
           or
           (($aligns_1_1->dnafrag_end <= $region_end) and
            ($aligns_2_1->dnafrag_end > $region_end)));
            

  if(
      (($aligns_1_1->dnafrag_strand == $aligns_1_2->dnafrag_strand)
        and(
          (($aligns_1_1->dnafrag_start == $aligns_2_1->dnafrag_start) and 
           ($aligns_1_2->dnafrag_start == $aligns_2_2->dnafrag_start)) 
          or
          (($aligns_1_1->dnafrag_end   == $aligns_2_1->dnafrag_end) and 
           ($aligns_1_2->dnafrag_end   == $aligns_2_2->dnafrag_end))
        )
      ) 
      or
      (($aligns_1_1->dnafrag_strand != $aligns_1_2->dnafrag_strand)
        and(
          (($aligns_1_1->dnafrag_start == $aligns_2_1->dnafrag_start) and 
           ($aligns_1_2->dnafrag_end   == $aligns_2_2->dnafrag_end)) 
          or
          (($aligns_1_1->dnafrag_end   == $aligns_2_1->dnafrag_end) and 
           ($aligns_1_2->dnafrag_start == $aligns_2_2->dnafrag_start))
        )
      ) 
    )   
  {
    if($gab1->score > $gab2->score) {
      $self->param('delete_hash')->{$gab2->dbID} = 1;
    } else {
      $self->param('delete_hash')->{$gab1->dbID} = 1;
    }
    $self->param('truncate_count', $self->param('truncate_count')+1);  
  }
  else {
    $self->param('not_truncate_count', $self->param('not_truncate_count')+1);
   }
}

1;
