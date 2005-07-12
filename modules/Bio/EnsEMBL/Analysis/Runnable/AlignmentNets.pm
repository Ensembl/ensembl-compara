#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Pipeline::Runnable::AlignmentNets

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::EnsEMBL::Analysis::Runnable::AlignmentNets;

use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );

use Bio::EnsEMBL::Analysis::Runnable;
use Bio::EnsEMBL::DnaDnaAlignFeature;


@ISA = qw(Bio::EnsEMBL::Analysis::Runnable);

sub new {
  my ($class,@args) = @_;

  my $self = $class->SUPER::new(@args);
  
  my ($chains,
      $query_lengths,
      $target_lengths,
      $chain_net,
      $simple_net,
      $min_chain_score
      ) = $self->_rearrange([qw(
                                CHAINS
                                QUERY_LENGTHS
                                TARGET_LENGTHS
                                CHAINNET
                                SIMPLE_NET
                                MIN_CHAIN_SCORE
                                )],
                                    @args);

  throw("You must supply a ref to array of alignment chains") 
      if not defined $chains;
  throw("You must supply a reference to an hash of query seq. lengths") 
      if not defined $query_lengths;
  throw("You must supply a reference to an hash of query seq. lengths") 
      if not defined $target_lengths;

  $self->query_length_hash($query_lengths);
  $self->target_length_hash($target_lengths);
    
  if (not defined $simple_net or not $simple_net) {    
    $self->chainNet($chain_net) if defined $chain_net;
    $self->simple_net(0);
  } else {
    $self->simple_net($simple_net);
  }

  $self->min_chain_score($min_chain_score) if defined $min_chain_score;
  $self->chains($self->sort_chains_by_max_block_score($chains));

  return $self;
}





=head2 run

  Title   : run
  Usage   : $self->run()
  Function: 
  Returns : none
  Args    : 

=cut

sub run {
  my ($self) = @_;

  my $nets;

  if ($self->simple_net) {
    $nets = $self->calculate_simple_net;
  } else {   
    my ($query_name) = keys %{$self->query_length_hash};
    
    my $work_dir = $self->workdir . "/$query_name.$$.ChainNet";
    while (-e $work_dir) {
      $work_dir .= ".$$";
    }
    
    my $chain_file = "$work_dir/$query_name.chain";
    my $query_length_file  = "$work_dir/$query_name.query.lengths";
    my $target_length_file = "$work_dir/$query_name.target.lengths";
    my $query_net_file     = "$work_dir/$query_name.query.net";
    my $target_net_file    = "$work_dir/$query_name.target.net";
    my $fh;
    
    mkdir $work_dir;
    
    ##############################
    # write the seq length files
    ##############################
    foreach my $el ([$query_length_file, $self->query_length_hash], 
                    [$target_length_file, $self->target_length_hash]) {
      my ($file, $hash) = @$el;
      
      open $fh, ">$file" or
          throw("Could not open seq length file '$file' for writing");
      foreach my $k (keys %{$hash}) {
        print $fh $k, "\t", $hash->{$k}, "\n";
      }
      close($fh);
    }
    
    
    ##############################
    # write chains
    ############################## 
    open $fh, ">$chain_file" or 
        throw("could not open chain file '$chain_file' for writing\n");
    $self->write_chains($fh);
    close($fh);
    
    ##################################
    # Get the Nets from chainNet
    ##################################
    my @arg_list;
    if (defined $self->min_chain_score) {
      @arg_list = ("-minScore=" . $self->min_chain_score);
    }
    push @arg_list, ($chain_file, 
                     $query_length_file, 
                     $target_length_file, 
                     $query_net_file,
                     $target_net_file);

    system($self->chainNet, @arg_list) 
        and throw("Something went wrong with chainNet");
    
    ##################################
    # read the Net file
    ##################################
    open $fh, $query_net_file or 
        throw("Could not open net file '$query_net_file' for reading\n");
    $nets = $self->parse_Net_file($fh);
    close($fh);
      
    unlink $chain_file, $query_length_file, $target_length_file, $query_net_file, $target_net_file;
    rmdir $work_dir;
  }
    
  $self->output($nets);    

  return 1;
}


#####################################################
sub sort_chains_by_max_block_score {
  my ($self, $chains) = @_;

  # sort the chains by maximum score
  my @chain_hashes;
  foreach my $chain (@$chains) {
    my $chain_hash = { chain => $chain };
    foreach my $block (@$chain) {
      if (not exists $chain_hash->{score} or
          $block->score > $chain_hash->{score}) {
        $chain_hash->{score} = $block->score;
      }
    }
    if (not defined $self->min_chain_score or
        $chain_hash->{score} > $self->min_chain_score) {
      push @chain_hashes, $chain_hash;
    }
  }
  
  my @sorted = map { $_->{chain}} sort {$b->{score} <=> $a->{score}} @chain_hashes;

  return \@sorted;
}

#####################################################

sub calculate_simple_net {
  my ($self) = @_;

  my $sorted_chains = $self->chains;

  my @net_chains;

  if ($self->simple_net =~ /HIGH/) {
    # VERY simple: just keep the best chain

    if (@$sorted_chains) {
      @net_chains = ($sorted_chains->[0]);
    }

  } elsif ($self->simple_net =~ /MEDIUM/) {
    # Slightly less simple. Junk chains that have extent overlap
    # with retained chains so far
    foreach my $c (@$sorted_chains) {
      my @b = sort { $a->start <=> $b->start } @$c; 
      my $c_st = $b[0]->start;
      my $c_en = $b[-1]->end;

      my $keep_chain = 1;
      foreach my $oc (@net_chains) {
        my @ob = sort { $a->start <=> $b->start } @$oc; 

        my $oc_st = $ob[0]->start;
        my $oc_en = $ob[-1]->end;

        if ($oc_st <= $c_en and $oc_en >= $c_st) {
          # overlap; junk
          $keep_chain = 0;
          last;
        }
      }

      if ($keep_chain) {
        push @net_chains, $c;
      }
    }

  } elsif ($self->simple_net =~ /LOW/) {
    # not quite so simple. Junk chains that have BLOCK overlap
    # with retained chains so far
    my @retained_blocks;

    foreach my $c (@$sorted_chains) {
      my @b = sort { $a->start <=> $b->start } @$c; 

      my $keep_chain = 1;
      BLOCK: foreach my $b (@b) {
        OTHER_BLOCK: foreach my $ob (@retained_blocks) {
          if ($ob->start <= $b->end and $ob->end >= $b->start) {
            $keep_chain = 0;
            last BLOCK;
          } elsif ($ob->start > $b->end) {
            last OTHER_BLOCK;
          }
        }
      }

      if ($keep_chain) {
        push @net_chains, $c;
        push @retained_blocks, @$c;
        @retained_blocks = sort { $a->start <=> $b->start } @retained_blocks;
      }
    }
  }

  return \@net_chains;
}


#####################################################

sub write_chains {
  my ($self, $fh) = @_;

  # in the absence of a chain score, we will take the score of the 
  # first block in the chain to be the score

  for(my $chain_id=1; $chain_id <= @{$self->chains}; $chain_id++) {
    my $chain = $self->chains->[$chain_id];

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
            $sens_f->{t_start} = $self->target_length_hash->{$tga->dnafrag->name} - $tga->dnafrag_end + 1;
            $sens_f->{t_end}   = $self->target_length_hash->{$tga->dnafrag->name} - $tga->dnafrag_start + 1;
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
            $sens_f->{t_start} = $self->target_length_hash->{$uf->hseqname} - $uf->hend + 1;
            $sens_f->{t_end}   = $self->target_length_hash->{$uf->hseqname} - $uf->hstart + 1;        
          }
          
          push @ungapped_features, $sens_f;
        }
      }
    }
    
    @ungapped_features = sort {$a->{q_start} <=> $b->{q_start}} @ungapped_features;

    # write chain header here
    printf($fh "chain %d %s %d %s %d %d %s %d %s %s %s %d\n",
           $chain_score,
           $query_name,
           $self->query_length_hash->{$query_name},
           $query_strand == -1 ? "-" : "+",
           $ungapped_features[0]->{q_start} - 1,
           $ungapped_features[-1]->{q_end},
           $target_name,
           $self->target_length_hash->{$target_name},
           $target_strand == -1 ? "-" : "+",
           $ungapped_features[0]->{t_start} - 1,
           $ungapped_features[-1]->{t_end},
           $chain_id);
    
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

#######################################

sub parse_Net_file {
  my ($self, $fh) = @_;
  
  my (%new_chains, %new_chain_scores, @last_gap, @last_parent_chain);

  while(<$fh>) {

    /(\s+)fill\s+(\d+)\s+(\d+)\s+\S+\s+\S+\s+\d+\s+\d+\s+(.+)$/ and do {
      my $indent = length($1) - 1;
      my $level_id = int( $indent / 2 ) + 1;
      my $q_start  = $2 + 1;
      my $q_end    = $q_start + $3 - 1;
      my $rest     = $4;
      
      my ($score)    = $rest =~ /score\s+(\d+)/;
      my ($chain_id) = $rest =~ /id\s+(\d+)/;
      
      $new_chain_scores{$chain_id} += $score;
      
      my $restricted_fps = 
          $self->restrict_between_positions($self->chains->[$chain_id],
                                            $q_start,
                                            $q_end);

      foreach my $fp (@$restricted_fps) {
        $fp->score($score);
        if ($fp->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock")) {
          foreach my $align (@{$fp->genomic_align_array}) {
            $align->level_id($level_id);
          }
        } else {
          $fp->level_id($level_id);
        }
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

          my $chain1 = $self->restrict_between_positions($parent_chain, 
                                                         $left_start,
                                                         $insert_start - 1);
          my $chain2 = $self->restrict_between_positions($parent_chain, 
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
    }
  }

  return [values %new_chains];
}


sub restrict_between_positions {
  my ($self, $chain, $q_start, $q_end) = @_;

  my @new_chain;

  my @blocks = @$chain;

  if ($blocks[0]->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock")) {
    foreach my $block (sort { $a->reference_genomic_align->dnafrag_start <=> 
                                  $b->reference_genomic_align->dnafrag_start} @blocks) {


      next if $block->reference_genomic_align->dnafrag_end < $q_start;
      last if $block->reference_genomic_align->dnafrag_start > $q_end;
      
      my $ref_start = $block->reference_genomic_align->dnafrag_start;
      my $ref_end   = $block->reference_genomic_align->dnafrag_end;
      
      $ref_start = $q_start if $q_start > $ref_start;
      $ref_end   = $q_end   if $q_end  < $ref_end;

      my $new_block = $block->restrict_between_reference_positions($ref_start, $ref_end);
      if (defined $new_block) {
        push @new_chain, $new_block;
      }
      
    }
  } else {
    foreach my $block (sort {$a->start <=> $b->start} @blocks) {
      next if $block->end < $q_start;
      last if $block->start > $q_end;
 
      my $new_block = $block->restrict_between_positions($q_start, $q_end, "SEQ");
      if (defined $new_block) {
        push @new_chain, $new_block;
      }
    }
  }

  return \@new_chain;
}



#####################
# instance vars
#####################

sub query_length_hash {
  my ($self, $val) = @_;
  
  if (defined $val) {
    $self->{_query_lengths_hashref} = $val;
  }
  return $self->{_query_lengths_hashref};
}

sub target_length_hash {
  my ($self, $hash_ref) = @_;
  
  if (defined $hash_ref) {
    $self->{_target_lengths_hashref} = $hash_ref;
  }
  return $self->{_target_lengths_hashref};
}

sub chains {
  my ($self, $val) = @_;

  if (defined $val) {
    $self->{_chains} = $val;
  }

  return $self->{_chains};
}


sub min_chain_score {
  my ($self, $val) = @_;

  if (defined $val) {
    $self->{_min_chain_score} = $val;
  }

  if (not exists $self->{_min_chain_score}) {
    return undef;
  } else {
    return $self->{_min_chain_score};
  }
}


sub simple_net {
  my ($self, $val) = @_;

  if (defined $val) {
    $self->{_simple_net} = $val;
  }

  return $self->{_simple_net};
}



##############
#### programs
##############

sub chainNet {
  my ($self,$arg) = @_;
  
  if (defined($arg)) {
    $self->{'_chainNet'} = $arg;
  }
  
  return $self->{'_chainNet'};
}



1;
