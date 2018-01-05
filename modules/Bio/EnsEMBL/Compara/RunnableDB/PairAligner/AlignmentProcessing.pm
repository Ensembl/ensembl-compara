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

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentProcessing

=head1 SYNOPSIS

Abstract base class of AlignmentChains and AlignmentNets

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentProcessing;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Compara::GenomicAlignBlock;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my ($self) = @_;
    
    $self->param('query_DnaFrag_hash', {});
    $self->param('target_DnaFrag_hash', {});
}


sub run{
    my ($self) = @_;

    my $runnable = $self->param('runnable');

    $self->compara_dba->dbc->disconnect_if_idle();    # this one should disconnect only if there are no active kids
    eval {
        $runnable->run;
        1;
    } or do {
        my $msg = $@;
        if($@ =~ /Something went wrong with/s) {   # Add other termination signals here (different for different Runnables)
            # Probably an ongoing MEMLIMIT
            # Let's wait a bit to let LSF kill the worker as it should
            sleep(30);
        }

        # If we're still there, there is something weird going on.
        # Perhaps not a MEMLIMIT, after all. Let's die and hope that
        # next run will be better
        die $@;
    };

    my $converted_chains = $self->convert_output($runnable->output);
    $self->param('chains', $converted_chains);
    rmdir($runnable->workdir) if (defined $runnable->workdir);
}




=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output()
    Function:   Writes contents of $self->output into $self->db
    Returns :   1
    Args    :   None

=cut

sub write_output {
  my($self) = @_;

  foreach my $chain (@{ $self->param('chains') }) {
      $self->_write_output($chain);
    }

  return 1;

}

sub _write_output {
    my ($self, $chain) = @_;
  #
  #Start transaction
  #
  $self->call_within_transaction( sub {
    
        my $group_id;
        
        #store first block
        my $first_block = shift @$chain;
        $self->compara_dba->get_GenomicAlignBlockAdaptor->store($first_block);
        
        #Set the group_id if one doesn't already exist ie for chains, to be the
        #dbID of the first genomic_align_block. For nets,the group_id has already
        #been set and is the same as it's chain.
        unless (defined($first_block->group_id)) {
            $group_id = $first_block->dbID;
            $self->compara_dba->get_GenomicAlignBlockAdaptor->store_group_id($first_block, $group_id);
        }
        
        #store the rest of the genomic_align_blocks
        foreach my $block (@$chain) {
            if (defined $group_id) {
                $block->group_id($group_id);
            }
            $self->compara_dba->get_GenomicAlignBlockAdaptor->store($block);
        }
  } );
}

###########################################
# chain sorting
###########################################
sub sort_chains_by_max_block_score {
  my ($self, $chains) = @_;

  # sort the chains by maximum score
  my @chain_hashes;
  foreach my $chain (@$chains) {
    my $chain_hash = { chain => $chain };
    foreach my $block (@$chain) {
      if (not exists $chain_hash->{qname}) {
        $chain_hash->{qname} = $block->seqname;
        $chain_hash->{tname} = $block->hseqname;
      }
      if (not exists $chain_hash->{score} or
          $block->score > $chain_hash->{score}) {
        $chain_hash->{score} = $block->score;
      }
    }
    push @chain_hashes, $chain_hash;
  }
  
  my @sorted = map { $_->{chain}} sort {
    $b->{score} <=> $a->{score} 
    or $a->{qname} cmp $b->{qname}
    or $a->{tname} cmp $b->{tname}
  } @chain_hashes;

  return \@sorted;
}


###########################################
# feature splitting
###########################################
sub split_feature {
  my ($self, $f, $max_gap) = @_;

  my @split_dafs;
  
  my $need_to_split = 0;

  my @pieces = split(/(\d*[MDI])/, $f->cigar_string);
  foreach my $piece ( @pieces ) {
    next if ($piece !~ /^(\d*)([MDI])$/);
    my $num = ($1 or 1);
    my $type = $2;

    if (($type eq "I" or $type eq "D") and $num >= $max_gap) {
      $need_to_split = 1;
      last;
    }
  }
  
  if ($need_to_split) {
    my (@new_feats);
    foreach my $ug (sort {$a->start <=> $b->start} $f->ungapped_features) {
      if (@new_feats) {
        my ($dist, $hdist);

        my $last_ug = $new_feats[-1]->[-1];

        if ($ug->end < $last_ug->start) {
          # blocks in reverse orienation
          $dist = $last_ug->start - $ug->end - 1;
        } else {
          # blocks in forward orienatation
          $dist = $ug->start - $last_ug->end - 1;
        }
        if ($ug->hend < $last_ug->hstart) {
          # blocks in reverse orienation
          $hdist = $last_ug->hstart - $ug->hend - 1;
        } else {
          # blocks in forward orienatation
          $hdist = $ug->hstart - $last_ug->hend - 1;
        }

        if ($dist >= $max_gap or $hdist >= $max_gap) {
          push @new_feats, [];
        }
      } else {
        push @new_feats, [];
      }
      push @{$new_feats[-1]}, $ug;
    }
    
    foreach my $mini_list (@new_feats) {
      push @split_dafs, Bio::EnsEMBL::DnaDnaAlignFeature->new(-features => $mini_list);
    }

  } else {
    @split_dafs = ($f)
  }  

  return @split_dafs;
}

############################################
# cigar conversion
############################################

sub compara_cigars_from_daf_cigar {
  my ($self, $daf_cigar) = @_;

  my ($q_cigar_line, $t_cigar_line, $align_length);

  my @pieces = split(/(\d*[MDI])/, $daf_cigar);

  my ($q_counter, $t_counter) = (0,0);

  foreach my $piece ( @pieces ) {

    next if ($piece !~ /^(\d*)([MDI])$/);
    
    my $num = ($1 or 1);
    my $type = $2;
    
    if( $type eq "M" ) {
      $q_counter += $num;
      $t_counter += $num;
      
    } elsif( $type eq "D" ) {
      $q_cigar_line .= (($q_counter == 1) ? "" : $q_counter)."M";
      $q_counter = 0;
      $q_cigar_line .= (($num == 1) ? "" : $num)."D";
      $t_counter += $num;
      
    } elsif( $type eq "I" ) {
      $q_counter += $num;
      $t_cigar_line .= (($t_counter == 1) ? "" : $t_counter)."M";
      $t_counter = 0;
      $t_cigar_line .= (($num == 1) ? "" : $num)."D";
    }
    $align_length += $num;
  }

  $q_cigar_line .= (($q_counter == 1) ? "" : $q_counter)."M"
      if $q_counter;
  $t_cigar_line .= (($t_counter == 1) ? "" : $t_counter)."M"
      if $t_counter;
  
  return ($q_cigar_line, $t_cigar_line, $align_length);
}


sub daf_cigar_from_compara_cigars {
  my ($self, $q_cigar, $t_cigar) = @_;

  my (@q_pieces, @t_pieces);
  foreach my $piece (split(/(\d*[MDGI])/, $q_cigar)) {
    next if ($piece !~ /^(\d*)([MDGI])$/);

    my $num = $1; $num = 1 if $num eq "";
    my $type = $2; $type = 'D' if $type ne 'M';

    if ($num > 0) {
      push @q_pieces, { num  => $num,
                        type => $type, 
                      };
    }
  }
  foreach my $piece (split(/(\d*[MDGI])/, $t_cigar)) {
    next if ($piece !~ /^(\d*)([MDGI])$/);
    
    my $num = $1; $num = 1 if $num eq "";
    my $type = $2; $type = 'D' if $type ne 'M';

    if ($num > 0) {
      push @t_pieces, { num  => $num,
                        type => $type,
                      };
    }
  }

  my $daf_cigar = "";

  while(@q_pieces and @t_pieces) {
    # should never be left with a q piece and no target pieces, or vice versa
    my $q = shift @q_pieces;
    my $t = shift @t_pieces;

    if ($q->{num} == $t->{num}) {
      if ($q->{type} eq 'M' and $t->{type} eq 'M') {
        $daf_cigar .= ($q->{num} > 1 ? $q->{num} : "") . 'M';
      } elsif ($q->{type} eq 'M' and $t->{type} eq 'D') {
        $daf_cigar .= ($q->{num} > 1 ? $q->{num} : "") . 'I';
      } elsif ($q->{type} eq 'D' and $t->{type} eq 'M') {
        $daf_cigar .= ($q->{num} > 1 ? $q->{num} : "") . 'D';
      } else {
        # must be a delete in both seqs; warn and ignore
        warn("The following cigars have a simultaneous gap:\n" . 
             $q_cigar . "\n". 
             $t_cigar . "\n");
      }
    } elsif ($q->{num} > $t->{num}) {
      if ($q->{type} ne 'M') {
        warn("The following cigars are strange:\n" . 
             $q_cigar . "\n". 
             $t_cigar . "\n");
      }
      
      if ($t->{type} eq 'M') {
        $daf_cigar .= ($t->{num} > 1 ? $t->{num} : "") . 'M';
      } elsif ($t->{type} eq 'D') {
        $daf_cigar .= ($t->{num} > 1 ? $t->{num} : "") . 'I';
      } 

      unshift @q_pieces, { 
        type => 'M',
        num  => $q->{num} - $t->{num}, 
      };

    } else {
      # $t->{num} > $q->{num}
      if ($t->{type} ne 'M') {
        warn("The following cigars are strange:\n" . 
             $q_cigar . "\n". 
             $t_cigar . "\n");
      }
      
      if ($q->{type} eq 'M') {
        $daf_cigar .= ($q->{num} > 1 ? $q->{num} : "") . 'M';
      } elsif ($q->{type} eq 'D') {
        $daf_cigar .= ($q->{num} > 1 ? $q->{num} : "") . 'D';
      } 
      unshift @t_pieces, { 
        type => 'M',
        num  => $t->{num} - $q->{num},
      };
    } 
  }

  # final sanity checks

  if (@q_pieces or @t_pieces) {
    warn("Left with dangling pieces in the following cigars:\n" .
          $q_cigar . "\n". 
          $t_cigar . "\n");
    return undef;
  }
  
  my $last_type;
  foreach my $piece (split(/(\d*[MDI])/, $daf_cigar)) {
    next if not $piece;
    my ($type) = ($piece =~ /\d*([MDI])/);

    if (defined $last_type and
       (($last_type eq 'I' and $type eq 'D') or
        ($last_type eq 'D' and $type eq 'I'))) {

      warn("Adjacent Insert/Delete in the following cigars:\n" .
           $q_cigar . "\n". 
           $t_cigar . "\n".
           $daf_cigar . "\n");

      return undef;
    }
    $last_type = $type;
  }
  
  return $daf_cigar;
}


sub convert_output {
  my ($self, $chains_of_dafs, $t_visible) = @_; 

  my (@chains_of_blocks);
  
  $t_visible = 1 if (!defined $t_visible);

  foreach my $chain_of_dafs (@$chains_of_dafs) {
    my @chain_of_blocks;

    foreach my $raw_daf (sort {$a->start <=> $b->start} @$chain_of_dafs) {
      my @split_dafs;
      if ($self->param('max_gap')) {
        @split_dafs = $self->split_feature($raw_daf, $self->param('max_gap'));
      } else {
        @split_dafs = ($raw_daf);
      }

      foreach my $daf (@split_dafs) {
        my ($q_cigar, $t_cigar, $al_len) = 
            $self->compara_cigars_from_daf_cigar($daf->cigar_string);
        
        my $q_dnafrag = $self->param('query_DnaFrag_hash')->{$daf->seqname};
        my $t_dnafrag = $self->param('target_DnaFrag_hash')->{$daf->hseqname};
        
        my $out_mlss = $self->param('output_MethodLinkSpeciesSet');

        my $q_genomic_align = Bio::EnsEMBL::Compara::GenomicAlign->new
            (-dnafrag        => $q_dnafrag,
             -dnafrag_start  => $daf->start,
             -dnafrag_end    => $daf->end,
             -dnafrag_strand => $daf->strand,
             -cigar_line     => $q_cigar,
	     -visible        => 1,      #always set to true
             -method_link_species_set => $out_mlss);
  
        my $t_genomic_align = Bio::EnsEMBL::Compara::GenomicAlign->new
            (-dnafrag        => $t_dnafrag,
             -dnafrag_start  => $daf->hstart,
             -dnafrag_end    => $daf->hend,
             -dnafrag_strand => $daf->hstrand,
             -cigar_line     => $t_cigar,
	     -visible        => $t_visible, #will be false for example, self alignments
             -method_link_species_set => $out_mlss);

        my $gen_al_block = Bio::EnsEMBL::Compara::GenomicAlignBlock->new
            (-genomic_align_array     => [$q_genomic_align, $t_genomic_align],
             -score                   => $daf->score,
             -length                  => $al_len,
             -method_link_species_set => $out_mlss,
	     -group_id                => $daf->group_id,
	     -level_id                => $daf->level_id ? $daf->level_id : 1);
        push @chain_of_blocks, $gen_al_block;
      }
    }

    push @chains_of_blocks, \@chain_of_blocks;
  }
    
  return \@chains_of_blocks;
}

sub cleanse_output {
  my ($self, $chains) = @_;

  # need to "cleanse" the of its original database attachments, so 
  # that it is stored as a fresh blocks. This involves touching the
  # object's privates, but more efficent than creating brand-new
  # blocks from scratch
  # NB don't undef group_id - I want to keep the chain group_id for the net.

  foreach my $chain (@{$chains}) {
    foreach my $gab (@{$chain}) {

      $gab->{'adaptor'} = undef;
      $gab->{'dbID'} = undef;
      $gab->{'method_link_species_set_id'} = undef;
      $gab->method_link_species_set($self->param('output_MethodLinkSpeciesSet'));
      foreach my $ga (@{$gab->get_all_GenomicAligns}) {
        $ga->{'adaptor'} = undef;
        $ga->{'dbID'} = undef;
        $ga->{'method_link_species_set_id'} = undef;
        $ga->method_link_species_set($self->param('output_MethodLinkSpeciesSet'));
      }
    }
  }

}


###################################
# redundant alignment deletion

sub delete_alignments {
  my ($self, $mlss, $qy_dnafrag, $tg_dnafrag) = @_;

  my $dbc = $self->compara_dba->dbc;
  my $sql = "SELECT ga1.genomic_align_block_id, ga1.genomic_align_id, ga2.genomic_align_id
      FROM genomic_align ga1, genomic_align ga2
      WHERE ga1.genomic_align_block_id=ga2.genomic_align_block_id
      AND ga1.genomic_align_id != ga2.genomic_align_id
      AND ga1.dnafrag_id = ?
      AND ga1.method_link_species_set_id = ?";
  if (defined $tg_dnafrag) {
    $sql .= " AND ga2.dnafrag_id = ?";
  }


  my $sth = $dbc->prepare($sql);
  if (defined $tg_dnafrag) {
    $sth->execute( $qy_dnafrag->dbID, $mlss->dbID, $tg_dnafrag->dbID);
  } else {
    $sth->execute( $qy_dnafrag->dbID, $mlss->dbID);
  }

  my $nb_gabs = 0;
  my @gabs;
  while (my $aref = $sth->fetchrow_arrayref) {
    my ($gab_id, $ga_id1, $ga_id2) = @$aref;
    push @gabs, [$gab_id, $ga_id1, $ga_id2];
    $nb_gabs++;
  }

  my $sql_gab = "delete from genomic_align_block where genomic_align_block_id in ";
  my $sql_ga = "delete from genomic_align where genomic_align_id in ";

  $self->warning("Deleting $nb_gabs genomic_align_blocks");

  for (my $i=0; $i < scalar @gabs; $i=$i+20000) {
    my (@gab_ids, @ga1_ids, @ga2_ids);
    for (my $j = $i; ($j < scalar @gabs && $j < $i+20000); $j++) {
      push @gab_ids, $gabs[$j][0];
      push @ga1_ids, $gabs[$j][1];
      push @ga2_ids, $gabs[$j][2];
    }
    my $sql_gab_to_exec = $sql_gab . "(" . join(",", @gab_ids) . ")";
    my $sql_ga_to_exec1 = $sql_ga . "(" . join(",", @ga1_ids) . ")";
    my $sql_ga_to_exec2 = $sql_ga . "(" . join(",", @ga2_ids) . ")";

    foreach my $sql ($sql_ga_to_exec1,$sql_ga_to_exec2,$sql_gab_to_exec) {
      my $sth = $dbc->prepare($sql);
      $sth->execute;
      $sth->finish;
    }
  }
}


###################################

sub output{
    my ($self, $output) = @_;
    if(!$self->param('output')){
	$self->param('output',[]);
    }
    if($output){
	my $this_output = $self->param('output');
	if(ref($output) ne 'ARRAY'){
	    throw('Must pass RunnableDB:output an array ref not a '.$output);
	}
	push(@{$this_output}, @$output);
	$self->param('output', $this_output);
    }
    return $self->param('output');
}

1;
