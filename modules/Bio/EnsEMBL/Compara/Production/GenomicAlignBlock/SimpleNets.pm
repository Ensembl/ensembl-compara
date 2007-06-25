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
    my @seq_level_bits = @{$qy_dnafrag->slice->project('seqlevel')};
    $self->query_seq_level_projection(\@seq_level_bits);
  }
  throw("Could not fetch DnaFrag with dbID " . $self->QUERY_DNAFRAG_ID )
      if not defined $qy_dnafrag;

  my $tg_gdb;
  if ($self->TARGET_GENOMEDB_ID) {
    $tg_gdb = $gdba->fetch_by_dbID($self->TARGET_GENOMEDB_ID);
  }
  throw("Could not fetch GenomeDB with dbID " . $self->TARGET_GENOMEDB_ID)
      if not defined $tg_gdb;

  my $mlss = $mlssa->fetch_by_method_link_type_GenomeDBs($self->INPUT_METHOD_LINK_TYPE,
                                                         [$qy_dnafrag->genome_db, $tg_gdb]);


  throw("No MethodLinkSpeciesSet for " . $self->INPUT_METHOD_LINK_TYPE)
      if not defined $mlss;

  my $out_mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
  $out_mlss->method_link_type($self->OUTPUT_METHOD_LINK_TYPE);
  $out_mlss->species_set($mlss->species_set);
  $mlssa->store($out_mlss);

  ######## needed for output####################
  $self->output_MethodLinkSpeciesSet($out_mlss);

  if ($self->input_job->retry_count > 0) {
    print STDERR "Deleting alignments as it is a rerun\n";
    $self->delete_alignments($out_mlss,
                             $qy_dnafrag);
  }

  my $gabs = $gaba->fetch_all_by_MethodLinkSpeciesSet_DnaFrag($mlss,
                                                              $qy_dnafrag);

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

  # sort the blocks within each chain

  foreach my $group_id (keys %chains) {
    $chains{$group_id}->{blocks} = [sort {
      $a->reference_genomic_align->dnafrag_start <=> $b->reference_genomic_align->dnafrag_start;
    } @{$chains{$group_id}->{blocks}}];
  }

  # now sort the chains by score. Ties are resolved by target and location
  # to make the sort deterministic
  my @chains;
  foreach my $group_id (sort { $chains{$b}->{score} <=> $chains{$a}->{score} or
                               $chains{$a}->{target_name} cmp $chains{$b}->{target_name} or
                               $chains{$a}->{target_pos} <=> $chains{$b}->{target_pos} or
                               $chains{$a}->{query_pos} <=> $chains{$b}->{query_pos}                               
                             } keys %chains) {
    push @chains, $chains{$group_id}->{blocks};    
  }


  $self->input_chains(\@chains);

}


sub run {
  my ($self) = @_;

  my $output;

  if ($self->NET_METHOD) {
    no strict 'refs';

    my $method = $self->NET_METHOD;
    $output = $self->$method;
  } else {
    $output = $self->ContigAwareNet();
  }
 
  $self->cleanse_output($output);
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

  # assumption 1: chains are sorted from "best" to "worst"
  # assumption 2: each chain is sorted from start to end in query (ref) sequence

  my (@net_chains, @retained_blocks, %contigs_of_kept_blocks);

  foreach my $c (@$chains) {
    
    my @blocks = @$c;

    my $keep_chain = 1;
    BLOCK: foreach my $block (@blocks) {
      my $qga = $block->reference_genomic_align;
      #my ($tga) = @{$block->get_all_non_reference_genomic_aligns};

      OTHER_BLOCK: foreach my $oblock (@retained_blocks) {
        my $oqga = $oblock->reference_genomic_align;
        #my ($otga) = @{$ob->get_all_non_reference_genomic_aligns};

        if ($oqga->dnafrag_start <= $qga->dnafrag_end and 
            $oqga->dnafrag_end >= $qga->dnafrag_start) {
          $keep_chain = 0;
          last BLOCK;
        } elsif ($oqga->dnafrag_start > $qga->dnafrag_end) {
          last OTHER_BLOCK;
        }
      }
    }
    if ($keep_chain) {
      my (%contigs_of_blocks, @split_blocks);

      # the following chops the blocks into pieces such that each block
      # lies completely within a sequence-level region (contig). It's rare
      # that this is not the case anyway, but it's best to be sure...

      foreach my $block (@blocks) {
        my ($inside_seg, @overlap_segs);

        my $qga = $block->reference_genomic_align;

        foreach my $seg (@{$self->query_seq_level_projection}) {
          if ($qga->dnafrag_start >= $seg->from_start and
              $qga->dnafrag_end    <= $seg->from_end) {
            $inside_seg = $seg;
            last;
          } elsif ($seg->from_start <= $qga->dnafrag_end and
              $seg->from_end   >= $qga->dnafrag_start) {
            push @overlap_segs, $seg;
          } elsif ($seg->from_start > $qga->dnafrag_end) {
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

            my $cut_block = $block->restrict_between_reference_positions($reg_start,
                                                                         $reg_end);
            $cut_block->score($block->score);

            if (defined $cut_block) {
              push @cut_blocks, $cut_block;
              $contigs_of_blocks{$cut_block} = $seg;
            }
          }
          push @split_blocks, @cut_blocks;
        }
      }
      @blocks = @split_blocks;

      # only retain blocks that lie on different contigs from all retained 
      # blocks so far
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
      map { 
        $kept_len += $_->reference_genomic_align->dnafrag_end - $_->reference_genomic_align->dnafrag_start + 1;
      } @diff_contig_blocks;
      map { 
        $total_len += $_->reference_genomic_align->dnafrag_end - $_->reference_genomic_align->dnafrag_start + 1;
      } @blocks;

      if ($kept_len / $total_len > 0.5) {
        foreach my $bid (keys %contigs_of_blocks) {
          $contigs_of_kept_blocks{$bid} = $contigs_of_blocks{$bid};
        }
        push @net_chains, \@diff_contig_blocks;
        push @retained_blocks, @diff_contig_blocks;
        @retained_blocks = sort { 
          $a->reference_genomic_align->dnafrag_start <=> $b->reference_genomic_align->dnafrag_start; 
        } @retained_blocks;
      }
    }
  }

  # fetch all genomic_aligns from the result blocks to avoid cacheing issues
  # when storing
  foreach my $ch (@net_chains) {
    foreach my $bl (@{$ch}) {
      foreach my $al (@{$bl->get_all_GenomicAligns}) {
        $al->dnafrag;
      }
    }
  }


  return \@net_chains;
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
