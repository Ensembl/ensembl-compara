=head1 LICENSE

# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

=head1 NAME

Bio::EnsEMBL::Compara::Production::Analysis::AlignmentNets;

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::EnsEMBL::Compara::Production::Analysis::AlignmentNets;

use warnings ;
use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentProcessing');


sub run_nets {
  my ($self) = @_;

  my $res_chains;

  my ($query_name) = keys %{$self->param('query_length_hash')};

  $self->cleanup_worker_temp_directory;
  my $work_dir = $self->worker_temp_directory;
  
  my $chain_file = "$work_dir/$query_name.chain";
  my $query_length_file  = "$work_dir/$query_name.query.lengths";
  my $target_length_file = "$work_dir/$query_name.target.lengths";
  my $query_net_file     = "$work_dir/$query_name.query.net";
  my $target_net_file    = "$work_dir/$query_name.target.net";
  my $fh;
  
  ##############################
  # write the seq length files
  ##############################
  foreach my $el ([$query_length_file, $self->param('query_length_hash')],
                  [$target_length_file, $self->param('target_length_hash')]) {
    my ($file, $hash) = @$el;
    
    open $fh, '>', $file or
        $self->throw("Could not open seq length file '$file' for writing");
    foreach my $k (keys %{$hash}) {
      print $fh $k, "\t", $hash->{$k}, "\n";
    }
    close($fh);
  }
  
  ##############################
  # sort chains, if necessary
  ##############################
  if (not $self->param('chains_sorted')) {
    my $chains = $self->param('chains');
    for(my $i=0; $i < @{$chains}; $i++) {
      if ($chains->[$i]->[0]->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock")) {
        $chains->[$i] = [
                               sort {
                                 $a->reference_genomic_align->dnafrag_start <=> 
                                 $a->reference_genomic_align->dnafrag_end 
                               } @{$chains->[$i]}
                               ];
      } else {
        $chains->[$i] = [
                               sort { $a->start <=> $b->start } @{$chains->[$i]}
                               ];
      }
    }
  }

  
  ##############################
  # write chains
  ############################## 
  open $fh, '>', $chain_file or
      $self->throw("could not open chain file '$chain_file' for writing\n");
  $self->write_chains($fh);
  close($fh);
  
  ##################################
  # Get the Nets from chainNet
  ##################################
  my @arg_list;
  if (defined $self->param('min_chain_score')) {
    @arg_list = ("-minScore=" . $self->param('min_chain_score'));
  }
  push @arg_list, ($chain_file, 
                   $query_length_file, 
                   $target_length_file, 
                   $query_net_file,
                   $target_net_file);

  $self->run_command([$self->param_required('chainNet_exe'), @arg_list], { die_on_failure => 1 });
  
  ##################################
  # Apply the synteny filter if requested
  ##################################
  if ($self->param('filter_non_syntenic')) {
    my $syntenic_net_file = "$work_dir/$query_name.query.synteny_annotated.net";
    my $filtered_net_file = "$work_dir/$query_name.query.synteny.net";
    
    $self->run_command([$self->param_required('netSyntenic_exe'), $query_net_file, $syntenic_net_file], { die_on_failure => 1 });
    $self->run_command($self->param_required('netFilter_exe') . " -syn $syntenic_net_file > $filtered_net_file", { die_on_failure => 1 });

    $query_net_file = $filtered_net_file;
  }
  
  open $fh, '<', $query_net_file or
      $self->throw("Could not open net file '$query_net_file' for reading\n");
  $res_chains = $self->parse_Net_file($fh);
  close($fh);
  
  return $res_chains;
}


#####################################################

sub write_chains {
  my ($self, $fh) = @_;

  # in the absence of a chain score, we will take the score of the 
  # first block in the chain to be the score

  my $chains = $self->param('chains');
  for(my $chain_id=1; $chain_id <= @{$chains}; $chain_id++) {
    my $chain = $chains->[$chain_id-1];

    my (@ungapped_features, 
        $chain_score,
        $query_name,
        $query_strand,
        $target_name,
        $target_strand);

    foreach my $gf (@$chain) {
      if (not defined $query_name) {
        # all members of the chain must come from the same
        # query and target, and be on the same strand on those
        # sequences, otherwise all bets are off

        if ($gf->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock")) {
          my $qga = $gf->reference_genomic_align;
          my ($tga) = @{$gf->get_all_non_reference_genomic_aligns};

          $query_name = $qga->dnafrag->name,
          $target_name = $tga->dnafrag->name,
          $query_strand = $qga->dnafrag_strand;
          $target_strand = $tga->dnafrag_strand;

        } else {
          # assume Bio::EnsEMBL::DnaDnaAlignFeature
          $query_name = $gf->seqname;
          $target_name = $gf->hseqname,
          $query_strand = $gf->strand;
          $target_strand = $gf->hstrand;
        }

        # the chain must be written with respect to the forward strand
        # of the query. Since we are dealing with the ungapped blocks below,
        # this can be achieved by swapping the strands if the query is reverse. 
        if ($query_strand == -1) {
          $query_strand  *= -1;
          $target_strand *= -1;
        }
      }
      
      if (not defined $chain_score or $chain_score < $gf->score) {
        $chain_score = $gf->score;
      }
      
      if ($gf->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock")) {
        foreach my $uf (@{$gf->get_all_ungapped_GenomicAlignBlocks}) {
          my $qga = $uf->reference_genomic_align;
          my ($tga) = @{$uf->get_all_non_reference_genomic_aligns};

          my $sens_f = {
            q_start  => $qga->dnafrag_start,
            q_end    => $qga->dnafrag_end,
            t_start  => $tga->dnafrag_start,
            t_end    => $tga->dnafrag_end,
            len      => $qga->dnafrag_end - $qga->dnafrag_start + 1,
          };

          if ($target_strand == -1) {
            $sens_f->{t_start} = $self->param('target_length_hash')->{$tga->dnafrag->name} - $tga->dnafrag_end + 1;
            $sens_f->{t_end}   = $self->param('target_length_hash')->{$tga->dnafrag->name} - $tga->dnafrag_start + 1;
          }

          push @ungapped_features, $sens_f;
        }
      } else {
        foreach my $uf ($gf->ungapped_features) {        
          
          my $sens_f = {
            q_start  => $uf->start,
            q_end    => $uf->end,
            t_start  => $uf->hstart,
            t_end    => $uf->hend,
            len      => $uf->end - $uf->start + 1,
          };
          
          if ($target_strand == -1) {
            $sens_f->{t_start} = $self->param('target_length_hash')->{$uf->hseqname} - $uf->hend + 1;
            $sens_f->{t_end}   = $self->param('target_length_hash')->{$uf->hseqname} - $uf->hstart + 1;
          }
          
          push @ungapped_features, $sens_f;
        }
      }
    }
    
    @ungapped_features = sort {$a->{q_start} <=> $b->{q_start}} @ungapped_features;

    # write chain header here
#    printf($fh "chain %d %s %d %s %d %d %s %d %s %s %s %d\n",
    print $fh join(" ",("chain",
           $chain_score,
           $query_name,
           $self->param('query_length_hash')->{$query_name},
           $query_strand == -1 ? "-" : "+",
           $ungapped_features[0]->{q_start} - 1,
           $ungapped_features[-1]->{q_end},
           $target_name,
           $self->param('target_length_hash')->{$target_name},
           $target_strand == -1 ? "-" : "+",
           $ungapped_features[0]->{t_start} - 1,
           $ungapped_features[-1]->{t_end},
           $chain_id)), "\n";
    
    for (my $i = 0; $i < @ungapped_features; $i++) {
      my $f = $ungapped_features[$i];
      
      print $fh $f->{len};
      
      if ($i == @ungapped_features - 1) {
        print $fh "\n";
      } else {
        my $next_f = $ungapped_features[$i+1];
        my $q_gap = $next_f->{q_start} - $f->{q_end} - 1;
        my $t_gap = $next_f->{t_start} - $f->{t_end} - 1;
        
        print $fh "\t$q_gap\t$t_gap\n";
      }
    }
    print $fh "\n";
  }
}


sub parse_Net_file {
  my ($self, $fh) = @_;
  
  my (%new_chains, %new_chain_scores, @last_gap, @last_parent_chain);

  my $chains = $self->param('chains');
    my $direction = $self->param_required('direction');

  while(<$fh>) {

    /(\s+)fill\s+(\d+)\s+(\d+)\s+\S+\s+\S+\s+\d+\s+\d+\s+(.+)$/ and do {
      my $indent = length($1) - 1;
      my $level_id = int( $indent / 2 ) + 1;
      my $q_start  = $2 + 1;
      my $q_end    = $q_start + $3 - 1;
      my $rest     = $4;
      
      my ($score)    = $rest =~ /score\s+(\d+)/;
      my ($chain_id) = $rest =~ /id\s+(\d+)/;

      if (exists $new_chains{$chain_id}) {
        $self->die_no_retry("Not expecting multiple instances of chain ID '$chain_id' in net file");
      }

      $new_chain_scores{$chain_id} += $score;

      next if (!defined $chains->[$chain_id-1]);

      my ($restricted_fps)
         = $self->restrict_between_positions($chains->[$chain_id-1],
                                            $q_start,
                                            $q_end);

      foreach my $fp (@$restricted_fps) {
        $fp->score($score);
	$fp->level_id($level_id);
        $fp->direction($direction);
      }
      
      if (@$restricted_fps) {
        push @{$new_chains{$chain_id}}, @$restricted_fps;

        if ($indent > 0) {
          # the new alignment has been inserted into the parent gap
          # need to split parent chain into two:
          #  begin -> $insert_start - 1,
          #  $insert_end + 1 -> end
          my $parent_chain = $new_chains{$last_parent_chain[$indent - 2]};
          
          my ($insert_start, $insert_end) = ($last_gap[$indent - 1]->[0],
                                             $last_gap[$indent - 1]->[1]);
          my ($left_start, $right_end);
          if ($parent_chain->[0]->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock")) {
            $left_start = $parent_chain->[0]->reference_genomic_align->dnafrag_start;
          } else {
            $left_start = $parent_chain->[0]->start;
          }
          if ($parent_chain->[-1]->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock")) {
            $right_end = $parent_chain->[-1]->reference_genomic_align->dnafrag_end;
          } else {
            $right_end = $parent_chain->[-1]->end;
          }

          my ($chain1) = $self->restrict_between_positions($parent_chain, 
                                                         $left_start,
                                                         $insert_start - 1);
          my ($chain2) = $self->restrict_between_positions($parent_chain, 
                                                         $insert_end + 1,
                                                         $right_end);
          
          $new_chains{$last_parent_chain[$indent - 2]} = [@$chain1, @$chain2];
        }
        $last_parent_chain[$indent] = $chain_id;
      }
    };
    /^(\s+)gap\s+(\d+)\s+(\d+)/ and do {
      my $indent = length($1) - 1;

      my $q_insert_start = $2 + 1;
      my $q_insert_end = $q_insert_start + $3 - 1;

      $last_gap[$indent] = [$q_insert_start, $q_insert_end];
    };

  }
  foreach my $cid (keys %new_chains) {
    my $chain_score = $new_chain_scores{$cid};
    foreach my $fp (@{$new_chains{$cid}}) {
      $fp->score($chain_score);
      $fp->direction($direction);
    }
  }
  return [values %new_chains];
}


sub restrict_between_positions {
  my ($self, $chain, $q_start, $q_end) = @_;

  #my @blocks = @$chain;

  my @new_chain;
  #my $chain_left = [];
  #my $chain_right = [];

  my $first_idx = $self->_bin_search_start($chain, $q_start);
  my $last_idx = $self->_bin_search_end($chain, $q_end);

  if ($first_idx < 0) {
    # all blocks to left of range

    #$chain_left = $chain;
    #$chain_right = [];
  } elsif ($last_idx < 0) {
    # all blocks to right of range

    #$chain_left = [];
    #$chain_right = $chain;
  } else {

    if ($first_idx > 0) {
      #@$chain_left = @{@$chain}[0..$first_idx-1];
    }
    if ($last_idx < scalar(@$chain) - 1) {
      #@$chain_right = @{@$chain}[$last_idx+1..scalar(@$chain)-1];
    }

    if ($first_idx <= $last_idx) {
      @new_chain = @{$chain}[$first_idx..$last_idx];
    }
    
    # may be necessary to cut the boundary blocks

    if (@new_chain) {
      my $block = shift @new_chain;
      my $b_start = $block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock")
          ? $block->reference_genomic_align->dnafrag_start
          : $block->start;
      my $b_end = $block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock")
          ? $block->reference_genomic_align->dnafrag_end
          : $block->end;
      
      if ($b_start < $q_start) {
        # need to cut the block;
        my $inside;
        # my $outside
        
        if ($block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock")) {
          #$outside = $block->restrict_between_reference_positions($b_start, $q_start - 1);
          $inside  = $block->restrict_between_reference_positions($q_start, $b_end);
        } else {
          #$outside = $block->restrict_between_positions($b_start, $q_start - 1, "SEQ");
          $inside = $block->restrict_between_positions($q_start, $b_end, "SEQ");
        }
        
        #push @$chain_left, $outside;
        unshift @new_chain, $inside;
      } else {
        unshift @new_chain, $block;
      }
      
      $block = pop @new_chain;
      $b_start = $block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock")
          ? $block->reference_genomic_align->dnafrag_start
          : $block->start;
      $b_end = $block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock")
          ? $block->reference_genomic_align->dnafrag_end
          : $block->end;
      
      if ($b_end > $q_end) {
        # need to cut the block;
        my $inside;
        #my $outside;
        
        if ($block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock")) {
          $inside  = $block->restrict_between_reference_positions($b_start, $q_end);
          #$outside = $block->restrict_between_reference_positions($q_end + 1, $b_end);
        } else {
          $inside  = $block->restrict_between_positions($b_start, $q_end, "SEQ");
          #$outside = $block->restrict_between_positions($q_end + 1, $b_end, "SEQ");
        }

        #unshift @$chain_right, $outside;        
        push @new_chain, $inside;
      } else {
        push @new_chain, $block;
      }
    }    
  }

  #return (\@new_chain,
  #        $chain_left,
  #        $chain_right);
  return (\@new_chain);

}

sub _bin_search_start {
  my ($self, $blocks, $position) = @_; 

  # find index of left-most block that ends to the right of $position
  my ($left, $right) = (0, scalar(@$blocks));
  while ($right - $left > 0) {
    my $mid = int(($left + $right) / 2);

    my ($block_end, $block_start);
    if ($blocks->[0]->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock")) {
      $block_end   = $blocks->[$mid]->reference_genomic_align->dnafrag_end;
    } else {
      $block_end   = $blocks->[$mid]->end;
    }

    if ($block_end < $position) {
      $left = $mid + 1;
    } else { 
      $right = $mid;
    }

  }
  
  if ($right > scalar(@$blocks)-1) {
    return -1;
  } else {
    return $right;
  }
}


sub _bin_search_end {
  my ($self, $blocks, $position) = @_; 

  # find index of rightmost block that starts before $position
  my ($left, $right) = (-1, scalar(@$blocks)-1);
  while ($right - $left > 0) {
    my $mid = int(($left + $right + 1) / 2);

    my ($block_end, $block_start);
    if ($blocks->[0]->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock")) {
      $block_start = $blocks->[$mid]->reference_genomic_align->dnafrag_start;
    } else {
      $block_start = $blocks->[$mid]->start;
    }

    if ($block_start > $position) {
      $right = $mid - 1;
    } else { 
      $left = $mid;
    }

  }
  
  # returns -1 if all blocks to right of $position
  return $right;
}


1;
