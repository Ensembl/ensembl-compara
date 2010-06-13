# Cared for by Ensembl
#
# Copyright GRL & EBI
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlign::AlignmentSimple

=head1 SYNOPSIS

  my $db      = Bio::EnsEMBL::DBAdaptor->new($locator);
  my $genscan = Bio::EnsEMBL::Compara::Production::GenomicAlign::SimpleNets->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
  $genscan->fetch_input();
  $genscan->run();
  $genscan->write_output(); #writes to DB


=head1 DESCRIPTION

Given an compara MethodLinkSpeciesSet identifer, and a reference genomic
slice identifer, fetches the GenomicAlignBlocks from the given compara
database, infers chains from the group identifiers, and then forms
an alignment net from the chains and writes the result
back to the database. 

This module implements some simple net-inspired functionality directly
in Perl, and does not rely on Jim Kent's original Axt tools

=cut
package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::SimpleNets;

use strict;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Hive::Process;
use Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::AlignmentProcessing;
use Time::HiRes qw(gettimeofday);

our @ISA = qw(Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::AlignmentProcessing);



############################################################

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");

  my $params = eval($param_string);
  return unless($params);

  $self->SUPER::get_params($param_string);

  if (defined($params->{'qy_dnafrag_id'})) {
    $self->QUERY_DNAFRAG_ID($params->{'qy_dnafrag_id'});
  }
  if (defined($params->{'tg_genomedb_id'})) {
    $self->TARGET_GENOMEDB_ID($params->{'tg_genomedb_id'});
  }
  if (defined $params->{'net_method'}) {
    $self->NET_METHOD($params->{'net_method'});
  }

  return 1;
}


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   
    Returns :   nothing
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_; 

  $self->SUPER::fetch_input;
  $self->compara_dba->dbc->disconnect_when_inactive(0);

  my $mlssa = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
  my $dnafa = $self->compara_dba->get_DnaFragAdaptor;
  my $gdba = $self->compara_dba->get_GenomeDBAdaptor;
  my $gaba = $self->compara_dba->get_GenomicAlignBlockAdaptor;

  $self->get_params($self->analysis->parameters);
  $self->get_params($self->input_id);

  ################################################################
  # get the compara data: MethodLinkSpeciesSet, reference DnaFrag, 
  # and GenomicAlignBlocks
  ################################################################
  my $qy_dnafrag; 

  if ($self->QUERY_DNAFRAG_ID) {
    $qy_dnafrag = $dnafa->fetch_by_dbID($self->QUERY_DNAFRAG_ID); 

    my $disco = $qy_dnafrag->slice->adaptor()->db->disconnect_when_inactive(); 
    $qy_dnafrag->slice->adaptor()->db->disconnect_when_inactive(0);  

##DEBUG: the problem
    my @seq_level_bits = @{$qy_dnafrag->slice->project('seqlevel')};
    $qy_dnafrag->slice->adaptor()->db->disconnect_when_inactive($disco);  
##THIBAUT
    $self->query_seq_level_projection(\@seq_level_bits); 
    print scalar( @seq_level_bits ) . "  seq_level_bits identified\n"; 
  } 

  throw("Could not fetch DnaFrag with dbID " . $self->QUERY_DNAFRAG_ID ) if not defined $qy_dnafrag;

  my $tg_gdb;
  if ($self->TARGET_GENOMEDB_ID) {
    $tg_gdb = $gdba->fetch_by_dbID($self->TARGET_GENOMEDB_ID);
  }
  throw("Could not fetch GenomeDB with dbID " . $self->TARGET_GENOMEDB_ID) if not defined $tg_gdb;

  my $mlss = $mlssa->fetch_by_method_link_type_GenomeDBs($self->INPUT_METHOD_LINK_TYPE, [$qy_dnafrag->genome_db, $tg_gdb]);


  throw("No MethodLinkSpeciesSet for " . $self->INPUT_METHOD_LINK_TYPE) if not defined $mlss;

  my $out_mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
  $out_mlss->method_link_type($self->OUTPUT_METHOD_LINK_TYPE);
  $out_mlss->species_set($mlss->species_set);
  print "storing out_mlss \n"; 
  $mlssa->store($out_mlss);
  print "done\n";  

  ######## needed for output####################
  $self->output_MethodLinkSpeciesSet($out_mlss);

  if ($self->input_job->retry_count > 0) {
    print STDERR "Deleting alignments as it is a rerun\n";
    $self->delete_alignments($out_mlss,
                             $qy_dnafrag);
  }

  print "fetching gabs ...\n"; 
  my $gabs = $gaba->fetch_all_by_MethodLinkSpeciesSet_DnaFrag($mlss, $qy_dnafrag);

  print scalar(@$gabs) . " gabs found - creating chains\n"; 
  ###################################################################
  # get the target slices and bin the GenomicAlignBlocks by group id
  ###################################################################
  my %chains;

  while (my $gab = shift @{$gabs}) {

    my ($qy_ga) = $gab->reference_genomic_align;
    my ($tg_ga) = @{$gab->get_all_non_reference_genomic_aligns};

    my $group_id = $gab->group_id;

    if (not exists $chains{$group_id}) {
      $chains{$group_id} = {
        score => $gab->score,
        query_name => $qy_ga->dnafrag->name,
        query_pos  => $qy_ga->dnafrag_start,
        target_name => $tg_ga->dnafrag->name,
        target_pos  => $tg_ga->dnafrag_start,
        blocks => [],
      };      
    } else {
      if ($gab->score > $chains{$group_id}->{score}) {
        $chains{$group_id}->{score} = $gab->score;
      }
      if ($chains{$group_id}->{query_pos} > $qy_ga->dnafrag_start) {
        $chains{$group_id}->{query_pos} = $qy_ga->dnafrag_start;
      }
      if ($chains{$group_id}->{target_pos} > $tg_ga->dnafrag_start) {
        $chains{$group_id}->{target_pos} = $tg_ga->dnafrag_start;
      }

    }
    push @{$chains{$group_id}->{blocks}}, $gab;
  }
  print "all gabs processed\n"; 
#  for my $group_id ( keys %chains ) { 
#    print "group_id : $group_id " . scalar( @{$chains{$group_id}->{blocks}} ) . "\n";
#  }


  # sort the blocks within each chain
  foreach my $group_id (keys %chains) {
    $chains{$group_id}->{blocks} = [sort { $a->reference_genomic_align->dnafrag_start <=> $b->reference_genomic_align->dnafrag_start; } @{$chains{$group_id}->{blocks}}];
  }

  # now sort the chains by score. Ties are resolved by target and location
  # to make the sort deterministic
  my @chains;
  foreach my $group_id (sort { $chains{$b}->{score} <=> $chains{$a}->{score} or $chains{$a}->{target_name} cmp $chains{$b}->{target_name} or
                               $chains{$a}->{target_pos} <=> $chains{$b}->{target_pos} or $chains{$a}->{query_pos} <=> $chains{$b}->{query_pos} } keys %chains) {
    push @chains, $chains{$group_id}->{blocks};    
  }

  print scalar(@chains) . " input chains identified\n"; 
  $self->input_chains(\@chains);

}


sub run {
  my ($self) = @_;

  my $output;

  if ($self->NET_METHOD) { 
    print "using net method\n"; 
    no strict 'refs';

    my $method = $self->NET_METHOD; 
    print "$method\n"; 
    $output = $self->$method;
  } else { 
    print "running ContigAwareNet \n"; 
    $output = $self->ContigAwareNet();
  }
  print "cleanse_output\n"; 
  $self->cleanse_output($output);
  print "done. now output ...\n"; 
  $self->output($output);
}


sub write_output {
  my $self = shift;

  my $disconnect_when_inactive_default = $self->db->dbc->disconnect_when_inactive;
  $self->compara_dba->dbc->disconnect_when_inactive(0);
  $self->SUPER::write_output;
  $self->compara_dba->dbc->disconnect_when_inactive($disconnect_when_inactive_default);
}


############################
# specific net methods
###########################


my @ALLOWABLE_METHODS = qw(ContigAwareNet);


sub SUPPORTED_METHOD {
  my ($class, $method ) = @_;

  my $allowed = 0;
  foreach my $meth (@ALLOWABLE_METHODS) {
    if ($meth eq $method) {
      $allowed = 1;
      last;
    }
  }

  return $allowed;
}


sub ContigAwareNet {
  my ($self) = @_;
  
  my $chains = $self->input_chains;
  my $time_s1= gettimeofday();  

  # assumption 1: chains are sorted from "best" to "worst"
  # assumption 2: each chain is sorted from start to end in query (ref) sequence

  my (@net_chains, @retained_blocks, %contigs_of_kept_blocks);

  #print "running ContigAwareNet NOW \n";  
  my $cnt_chain=0;

  my @query_seq_level_projection = @{$self->query_seq_level_projection}; 
  my $min =0; 
  for my $seg ( @query_seq_level_projection ) { 
     if ($seg->from_start > $min ) {  
        $min= $seg->from_start;
     } else {  
       throw ( " error \n" ); 
     }
  }    

  CHAIN: foreach my $c (@$chains) {
    my $time_start = gettimeofday();  
    my @blocks = @$c;  
    $cnt_chain++; 
    print "Chains: $cnt_chain/". scalar(@$chains) ." - " . scalar(@blocks) ." blocks   (".scalar(@retained_blocks) . " retained blocks)\n" ; 

    my $keep_chain = 1; 

     # sort get genomic extent of block ( min start + max. end ) 
    my @start_blocks = map { $_->[1] } sort { $a->[0] <=> $b->[0] } map { [$_->reference_genomic_align->dnafrag_start, $_] } @blocks;  
    my @end_blocks = map { $_->[1] } sort { $a->[0] <=> $b->[0] } map { [$_->reference_genomic_align->dnafrag_end, $_] } @blocks;  

    my $min_start_X  =  $start_blocks[0]->reference_genomic_align->dnafrag_start ;
    my $max_end_X =  $end_blocks[-1]->reference_genomic_align->dnafrag_end; 

    # sort get genomic extent of block ( min start + max. end ) 
#    my $min_start_Y = $blocks[0]->reference_genomic_align->dnafrag_start; 
#    my $max_end_Y = $blocks[0]->reference_genomic_align->dnafrag_end; 
#
#    for my $block ( @blocks ) { 
#      my $rga = $block->reference_genomic_align;  
#      if ( $rga->dnafrag_start < $min_start_Y ) {  
#          $min_start_Y = $rga->dnafrag_start;
#      } 
#      if ( $rga->dnafrag_end > $max_end_Y ) {  
#          $max_end_Y  = $rga->dnafrag_end;
#      }
#     } 
    
    my $nr=0;
    # blocks are sorted by start and should not overlap ... 
    my $A = gettimeofday();
    my $tdiff; 
    my $tkdiff_3; 
    RETAINED_BLOCK: foreach my $ret_block (@retained_blocks) { 
      $nr++;
      #print "Chain $cnt_chain - retained block: $nr / " .scalar(@retained_blocks)." "; 
      my $ret = $ret_block->reference_genomic_align; 
      my $ret_start = $ret->dnafrag_start;
      my $ret_end = $ret->dnafrag_end;
      if ($ret_start <= $max_end_X and $ret_end >= $min_start_X ) { 
        # genomic extent of block overlaps with retained block. check in detail  
         my $time_A = gettimeofday();   
         $tkdiff_3=$time_A - $A ; 
         printf ("Time A: %.2f - time needed to identify overlap. ", $tkdiff_3); 
         print " $nr / " . scalar(@retained_blocks) . " ( how many retained block block have been inspected until overlap found ...)";
         print scalar(@blocks) ." blks vs " . scalar(@retained_blocks ) . "ret.b to compare \n";
         my $overlap  = if_blocks_and_retained_blocks_overlap(\@blocks,\@retained_blocks,$cnt_chain,$nr,scalar(@$chains),scalar(@retained_blocks));
         my $time_B = gettimeofday();   
         $tdiff = $time_B-$time_A;
         printf ("Time A: %.2f - time for inspection of block/retained block", $tdiff );   
         print scalar(@blocks) . " blocks - " . scalar(@retained_blocks). " retained blocks\n"; 
         if ( $overlap == 1 ) { 
           $keep_chain = 0;
           last RETAINED_BLOCK; 
         } else { 
           last RETAINED_BLOCK; 
          #print "good, no overlap so we keep chain \n";
     #     print " no overlap between retained block and genomic extend of block"; # we keep chain  
         }
      }  else {  
     #    print "retained block does not overlap with genomic extend of current block" ; 
      }  
   #   print "\n"; 
    }
   # print "\n"; 
   my $B = gettimeofday(); 
   my $tdiff_2 = $B - $A ; 
   #printf ("Time B: %.2f \n",$tdiff_2 - ( $tdiff + $tkdiff_3)); 
   printf ("TimeAB: %.2f \n",$tdiff_2); 
   

   #
   #
   # 
   
    sub if_blocks_and_retained_blocks_overlap { 
      my ( $b_ref, $r_ref,$cnt_chain,$nr_rt,$cc,$rr ) = @_ ;  
    
     #pre-compute start and end of retained block   
      #my @start_blocks = map { $_->[1] } sort { $a->[0] <=> $b->[0] } map { [$_->reference_genomic_align->dnafrag_start, $_] } @$r_ref;
      #my @end_blocks = map { $_->[1] } sort { $a->[0] <=> $b->[0] } map { [$_->reference_genomic_align->dnafrag_end, $_] } @$r_ref;

     #my $min_start  =  $start_blocks[0]->reference_genomic_align->dnafrag_start ;
     #my $max_end  =  $end_blocks[-1]->reference_genomic_align->dnafrag_end; 
     
     #print "doing deeper checking ......\n"; 
     my $outer_block = 0;   
     my $last_index = 0; 
     BLOCK: foreach my $block (@$b_ref ) { 
      $outer_block++;
      my $inner_block = 0 ; 
      my $qga = $block->reference_genomic_align; 
      # if block and retained block start/end do not overlap... 
#      if ( $qga->dnafrag_start > $max_end  ) {   
#        #                                qga_S ---------------- qga_E 
#        #  min_start -------- max_end  
#        print "$min_start ---- $max_end         <  "  . $qga->dnafrag_start . "     " .$qga->dnafrag_end . "  - skipping\n"; 
#        next BLOCK; 
#      }elsif ($qga->dnafrag_end < $min_start )  {   
#        #     qga_S-----------qga_E
#        #                            min_start-----------max_end 
#        print    $qga->dnafrag_start . "     " .$qga->dnafrag_end . "    <<     $min_start ---- $max_end   skipping\n";
#        next BLOCK; 
#      }else {  
#          print "no skipping\n"; 
#      } 
      # only test retained OTHER_BLOCK in detail if it overlaps with BLOCK 
      my $outer_block_start= $block->reference_genomic_align->dnafrag_start;
      my $outer_block_end  = $block->reference_genomic_align->dnafrag_start;
      my $retained_block_start = $$r_ref[0]->reference_genomic_align->dnafrag_start;
      my $retained_block_end = $$r_ref[-1]->reference_genomic_align->dnafrag_end;
      print "os : $outer_block_start - oe $outer_block_end     rs $retained_block_start  re $retained_block_end\n";  

      if ( $retained_block_end < $outer_block_start ) { 
        # blocks will never overlap; retained block lies left of obs 
        print "SL : re < os : $retained_block_end < $outer_block_start : LEFT blocks will never overlap\n";
        next BLOCK;
      }
      if ( $retained_block_start >  $outer_block_end ) { 
        # rs lies right of obs .
        print "SR : rs > oe : $retained_block_start >  $outer_block_end : RIGHT blocks will never overlap\n";
        next BLOCK;
      } 
      #OTHER_BLOCK: foreach my $oblock (@$r_ref ) { # @retained populated while looping  


      $last_index = binary_search ($r_ref, $outer_block_start-1 ); 

      OTHER_BLOCK: for ( my $i = $last_index; $i<@$r_ref; $i++) { 
        my $oblock = $$r_ref[$i];
        $inner_block++;
        print "C $cnt_chain / $cc  RT $nr_rt / $rr  Outblock: $outer_block / " . scalar(@blocks) . " Inner : $i /  " . scalar( @retained_blocks) . "\t";
        my $oqga = $oblock->reference_genomic_align;
         print $qga->dnafrag_start." ".$qga->dnafrag_end." - i=$i ".$oqga->dnafrag_start." ". $oqga->dnafrag_end."  ( ";  
         print "Oqgas " .$oqga->dnafrag_start." <= qgae ".$qga->dnafrag_end." && Oqgae ".$oqga->dnafrag_end." >= qgas ". $qga->dnafrag_start." ) ?";  
         print "os : $outer_block_start - oe $outer_block_end  - rs $retained_block_start re $retained_block_end ? ";  

        if ($oqga->dnafrag_start <= $qga->dnafrag_end and $oqga->dnafrag_end >= $qga->dnafrag_start) {  
        #  print "               found : $outer_block / " . scalar(@$b_ref ) . " blocks  ;    $inner_block / " . scalar(@$r_ref). " retained block (deepness)\n";
          # block and retained block overlap; we don't keep this chain.  
          print " Y \n";
          return 1 ; 
        } elsif ($oqga->dnafrag_start > $qga->dnafrag_end) {
          $last_index=$i-1; 
          print " N - next retained block()\n"; 
          last OTHER_BLOCK;
        } 
        print " N\n";
      }
    }   
    # no overlap between retained block and normal block. we return 0 as there is no overlap, we will keep the chain.
    #print "all blocks inspected ..\n"; 
    return 0 ;
   } 

#    BLOCK: foreach my $block (@blocks) {
#      my $qga = $block->reference_genomic_align;
#      OTHER_BLOCK: foreach my $oblock (@retained_blocks) { # @retained populated while looping 
#        my $oqga = $oblock->reference_genomic_align;
#        if ($oqga->dnafrag_start <= $qga->dnafrag_end and $oqga->dnafrag_end >= $qga->dnafrag_start) { 
#          # block and retained block overlap - we don't keep the chain 
#          $keep_chain = 0;
#          last BLOCK;
#        } elsif ($oqga->dnafrag_start > $qga->dnafrag_end) {
#          last OTHER_BLOCK;
#        }
#      }
#    }  


    # the following chops the blocks into pieces such that each block
    # lies completely within a sequence-level region (contig). It's rare
    # that this is not the case anyway, but it's best to be sure... 
    
    #   process all blocks 
    #    - compare reference_genomic_align ( $qga dnafrag_start and dnafrag_end ) against all contigs 
    #      
    #   if reference genomic align lies in contig segement take it and process next block 
    #   if ref. genomic is overlapping the contig but not inside
    if ($keep_chain) { 
        #print "keeping chain\n";
        my $A = gettimeofday();
      #   printf ("time A: %.2f\n",$B-$A);
      my (%contigs_of_blocks, @split_blocks);

      my $last_index = 0 ;  
      my $nrb =0;  
      # THIS SEARCH BELOW TAKES THE MOST TIME AS SOME 20.000 * 250.000 entries are compared.  
      MY_BLOCK: foreach my $block (@blocks) { 
        my ($inside_seg, @overlap_segs);  
         $nrb++;
        my $qga = $block->reference_genomic_align;  
        #print "processing block $nrb / " . scalar(@blocks) ." : " .$qga->dnafrag_start."\t".$qga->dnafrag_end ." cmp: ";  
        
        for ( my $i = $last_index ; $i < @query_seq_level_projection ; $i++ ) {  
           my $seg = $query_seq_level_projection[$i]; 
           #print "$cnt_chain block $nrb / " . scalar(@blocks) ." : " .$qga->dnafrag_start."\t".$qga->dnafrag_end ." cmp: i=$i / " . scalar(@query_seq_level_projection) . "\t";   
           #print $seg->from_start."\t".$seg->from_end."\n";

          if ($qga->dnafrag_start >= $seg->from_start and $qga->dnafrag_end    <= $seg->from_end) { 
            # if qga [reference genomic align] falls inside the segement 
            #         QGAs------------QGAe                 BLOCK
            #  segS-------------------------------segE         the segments are the 250.000 contigs 
            $inside_seg = $seg; 
            $last_index=$i-1; 
            last;
          } elsif ($seg->from_start <= $qga->dnafrag_end and $seg->from_end   >= $qga->dnafrag_start) { 
            #                 qga_St ------------------------------ qga_End 
            # qga_St ----------------------- qga_End 
            #          segSt----------------------------------segE       
             
            push @overlap_segs, $seg;
            #print "overlap : " . scalar(@overlap_segs) . "\n"; 
          } elsif ($seg->from_start > $qga->dnafrag_end) {
            # qga_St --------------- qga_End 
            #                                            segSt------------------------segE        
            $last_index=$i-1;
            last;
          } 
        } 
        if (defined $inside_seg) { 
          push @split_blocks, $block; 
          $contigs_of_blocks{$block} = $inside_seg;
        } else {
          my @cut_blocks; 
          foreach my $seg (@overlap_segs) {
            my ($reg_start, $reg_end) = ($qga->dnafrag_start, $qga->dnafrag_end);
            $reg_start = $seg->from_start if $seg->from_start > $reg_start;
            $reg_end   = $seg->from_end   if $seg->from_end   < $reg_end;
             
            my $cut_block = $block->restrict_between_reference_positions($reg_start, $reg_end);
            $cut_block->score($block->score);

            if (defined $cut_block) {
              push @cut_blocks, $cut_block;
              $contigs_of_blocks{$cut_block} = $seg;
            }
          } 
          push @split_blocks, @cut_blocks;
        }
      }  # next block
      my $k1 = gettimeofday();
      my $k1_diff = $k1-$A ; 
      printf ("Time K: %.2f - ( k1 segment - block processing )\n",$k1_diff);



      #print "Changing blocks underneith....\n";
      @blocks = @split_blocks;  
      $last_index =0;
      #print scalar(@split_blocks) . " split blocks "; 

      # only retain blocks that lie on different contigs from all retained blocks so far 
      
      my @diff_contig_blocks;
      my %kept_contigs = reverse %contigs_of_kept_blocks;
      foreach my $block (@blocks) {
        if (not exists $kept_contigs{$contigs_of_blocks{$block}}) {
          push @diff_contig_blocks, $block;
        }
      }

      # calculate what proportion of the overall chain remains; reject if
      # the proportion is less than 50%
      my $kept_len = 0;
      my $total_len = 0; 
      map { $kept_len += $_->reference_genomic_align->dnafrag_end - $_->reference_genomic_align->dnafrag_start + 1; } @diff_contig_blocks;
      map { $total_len += $_->reference_genomic_align->dnafrag_end - $_->reference_genomic_align->dnafrag_start + 1; } @blocks;
      
      if ($kept_len / $total_len > 0.5) { 
        foreach my $bid (keys %contigs_of_blocks) {
          $contigs_of_kept_blocks{$bid} = $contigs_of_blocks{$bid};
        }
        push @net_chains, \@diff_contig_blocks; 
        #print "adding " .scalar(@diff_contig_blocks) . " to result\n"; 
        push @retained_blocks, @diff_contig_blocks; 
        @retained_blocks = sort { $a->reference_genomic_align->dnafrag_start <=> $b->reference_genomic_align->dnafrag_start; } @retained_blocks;
        #print scalar(@retained_blocks) . " retained blocks found .....\n"; 
      }  


      my $B = gettimeofday(); 
      my $kt_diff = $B -$A ;  
      printf ("Time K: %.2f - ( k2 segment )\n",$kt_diff-$k1_diff);
      printf ("Time K: %.2f - (Full time if keeping chain)\n",$kt_diff);
    }else{   
      #print " NOT KEEP CHAIN \n"; 
    }
    my $time_end = gettimeofday();  
    printf ("\nTime Z: %.2f  -  (time for chain)\n\n", $time_end-$time_start); 
    #print  scalar(@blocks ) . " blocks \n"; 
  } # next chain 

  # fetch all genomic_aligns from the result blocks to avoid cacheing issues
  # when storing 
  #print " all chains processed\n"; 
  foreach my $ch (@net_chains) {
    foreach my $bl (@{$ch}) {
      foreach my $al (@{$bl->get_all_GenomicAligns}) {
        $al->dnafrag;
      }
    }
  }
  my $total; 
  print "returning " . scalar(@net_chains) . "  net chains \n" ; 
  for my $c( @net_chains ) {    
      print scalar(@$c) . " blocks\n";
      $total+=scalar(@$c);
  } 
  print "TOTAL :  $total blocks \n"; 
  my $time_e1 = gettimeofday();  
  printf ("run() -Time: %.2f  \n", $time_e1-$time_s1); 
  return \@net_chains;
}



sub binary_search {
    my ($array, $word) = @_;
    my $low = 0;                            # 0
    my $high = @$array - 1;                 # 99

    while ( $low <= $high ) { 
#        print "$low $high\n";
        my $try = int( ($low+$high) / 2 );  # 48 
        print "low $low high $high try $try ( $low+$high/2)\n"; 
#        if ($array->[$try] < $word ) { 
#          $low  = $try+1;
#          next ;
#        } 
#        if ($array->[$try] > $word ) { 
#          $high  = $try-1;
#          next ;
#        } 
        if ( $array->[$try] == $word )    { 
           print "match $try ";
        }
        $low  = $try+1, next if $array->[$try] < $word;  # 
        $high = $try-1, next if $array->[$try] > $word;
        return $try;
    }
    return $high;
} 


#############################

sub input_chains {
  my ($self, $val) = @_;

  if (defined $val) {
    $self->{_query_chains} = $val;
  }

  return $self->{_query_chains};
}

sub query_seq_level_projection {
  my ($self, $val) = @_;

  if (defined $val) {
    $self->{_query_seq_level_bits} = $val;
  }
  return $self->{_query_seq_level_bits};
}



#########################################
# config vars

sub NET_METHOD {
  my ($self, $val) = @_;

  if (defined $val) {
    $self->{_net_type} = $val;
  }

  return $self->{_net_type};
}


sub QUERY_DNAFRAG_ID {
  my ($self,$value) = @_;
  
  if (defined $value) {
    $self->{'_query_dnafrag_id'} = $value;
  }
  return $self->{'_query_dnafrag_id'};

}


sub TARGET_GENOMEDB_ID {
  my ($self,$value) = @_;
  
  if (defined $value) {
    $self->{'_target_genomedb_id'} = $value;
  }
  return $self->{'_target_genomedb_id'};
}




1;
