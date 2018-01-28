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



=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::EPOanchors::TrimAnchorAlign

=cut

=head1 SYNOPSIS

parameters
{input_analysis_id=> ?,method_link_species_set_id=> ?,test_method_link_species_set_id=> ?, genome_db_ids => [?],}

=cut

=head1 DESCRIPTION

Finds a good splitting point within the anchors. Leave the anchors as a 2bp long region.

- fetch_input
- run
- write_output

=cut

=head1 CONTACT

http://lists.ensembl.org/mailman/listinfo/dev

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::EPOanchors::TrimAnchorAlign;

use strict;
use warnings;

use Data::Dumper;
use Bio::EnsEMBL::Utils::Exception qw(throw);

use base('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
  my ($self) = @_;

  if (!$self->param('anchor_id')) {
    return 0;
  }
   $self->param('fasta_files',[]);
   $self->param('anchor_aligns',[]);
  my $anchor_align_adaptor = $self->compara_dba()->get_AnchorAlignAdaptor();
  ## This method returns a hash at the moment, not the objects
#   print "Fetching AnchorAligns for Anchor ", $self->param('anchor_id'), " and MLSS ", $self->{'input_method_link_species_set_id'}, "\n";
  my $anchor_aligns = $anchor_align_adaptor->fetch_all_by_anchor_id_and_mlss_id(
      $self->param('anchor_id'), $self->param('input_method_link_species_set_id') );
  die "Cannot find any anchor_align with anchor_id = ". $self->param('anchor_id').
    " and method_link_species_set_id = ". $self->param('input_method_link_species_set_id')
      if (!$anchor_aligns and !scalar(@$anchor_aligns));
  $self->param('anchor_aligns', $anchor_aligns);
  $self->compara_dba()->dbc->disconnect_if_idle();
  $self->_dump_fasta();

  return 1;
}

sub run {
  my $self = shift;
  
  # if ( $self->debug ) {
  #   my $personal_debug_dir = "/homes/carlac/gpfs_nobackup/epo_migration_testing/pt2/";
  #   foreach my $f ( @{ $self->param('fasta_files') } ) {
  #     my $this_file = $f;
  #     $this_file =~ s/\/tmp\//$personal_debug_dir/;
  #     print " --- Copying $f\t->\t$this_file\n";
  #     system("cp $f $this_file");
  #   }
  # }
  
  my @ortheus_cmd = ($self->param('ortheus_c_exe'));
  push @ortheus_cmd, '-a', @{$self->param_required('fasta_files')};
  push @ortheus_cmd, '-b', $self->param_required('tree_string');
  push @ortheus_cmd, '-h'; # output leaves only

  my $cmd = $self->run_command(\@ortheus_cmd, { 'use_bash_errexit' => 0 });
  if ($cmd->exit_code == 137 or $cmd->exit_code == 265) {
      # OOM Killer in action
      # Let's first wait to check whether the worker itself is going to be killed
      sleep(30);
      $self->dataflow_output_id(undef, -1);
      $self->complete_early($self->param('ortheus_c_exe').' was killed because it was using too much memory.');
  } elsif ($cmd->exit_code) {
      die sprintf("Could not run %s, got %s\nSTDOUT %s\nSTDERR %s\n", $self->param('ortheus_c_exe'), $cmd->exit_code, $cmd->out, $cmd->err);
  }

  my $trim_position = $self->get_best_trimming_position($cmd->out);
  $self->param('trimmed_anchor_aligns', $self->get_trimmed_anchor_aligns($trim_position));
  return 1;
}

sub write_output {
  my ($self) = @_;

  my $anchor_align_adaptor = $self->compara_dba()->get_AnchorAlignAdaptor();
  foreach my $this_trimmed_anchor_align (@{$self->param('trimmed_anchor_aligns')}) {
    $anchor_align_adaptor->store($this_trimmed_anchor_align);
  }

  return 1;
}


=head2 _dump_fasta

  Arg [1]    : -none-
  Example    : $self->_dump_fasta();
  Description: Dumps FASTA files in the order given by the tree
               string (needed by Pecan). Resulting file names are
               stored using the fasta_files getter/setter
  Returntype : 1
  Exception  :
  Warning    :

=cut

sub _dump_fasta {
  my $self = shift;
  my $all_anchor_aligns = $self->param('anchor_aligns');
  my $tree_str = "(";

  if ( scalar @$all_anchor_aligns < 2 ){
      $self->input_job->autoflow(0);
      $self->complete_early( "Not enough sequences in current anchor - omitting" );
  }

  $self->iterate_by_dbc($all_anchor_aligns,
      sub {my $anchor_align = shift; return $anchor_align->dnafrag->genome_db->db_adaptor->dbc;},
      sub {my $anchor_align = shift;

    my $anchor_align_id = $anchor_align->dbID;
    $tree_str .= "aa$anchor_align_id:0.1,";
    my $file = $self->worker_temp_directory . "/seq" . $anchor_align_id . ".fa";

    my $header = join("", ">AnchorAlign", $anchor_align_id, "|", $anchor_align->dnafrag->name, ".",
        $anchor_align->dnafrag_start, "-", $anchor_align->dnafrag_end, ":",
        $anchor_align->dnafrag_strand);
    my $seq = $anchor_align->seq;
    if ($seq =~ /[^ACTGactgNnXx]/) {
      print STDERR "AnchorAlign $anchor_align_id contains at least one non-ACTGactgNnXx character. These have been replaced by N's\n";
      $seq =~ s/[^ACTGactgNnXx]/N/g;
    }
    $seq =~ s/(.{80})/$1\n/g;
    chomp $seq;

    $self->_spurt($file, "$header\n$seq\n");

    push @{$self->param('fasta_files')}, $file;

  } );

  substr($tree_str, -1, 1, ");");
  $self->param('tree_string', $tree_str);

  return 1;
}

sub get_best_trimming_position {
  my ($self, $msa_string) = @_;
  my $num_of_leaves = 1;

  ################################
  # Parse the multiple alignment
  ################################
  my @lines = split("\n", $msa_string);
  my $anchor_align_id;
  my $seqs;
  my $this_seq;
  foreach my $this_line (@lines) {
    if ($this_line =~ /score/) {
    } elsif ($this_line =~ /^>aa(\d+)$/) {
      $seqs->{$anchor_align_id} = $this_seq if ($anchor_align_id);
      $anchor_align_id = $1;
      $this_seq = "";
      $num_of_leaves++;
    } else {
      $this_seq .= $this_line;
    }
  }
  $seqs->{$anchor_align_id} = $this_seq;
  $self->param('aligned_sequences', $seqs);

  my $ideal_score = 4 * $num_of_leaves;

  #####################################
  # consensus seq, gaps, conservation
  #####################################
  my @gaps;
  my @consensus;
  my @conservation;
  foreach my $this_seq (values %$seqs) {
    my @seq = split("", $this_seq);
    for (my $i = 0; $i < @seq; $i++) {
      if ($seq[$i] eq "-") {
        $gaps[$i]++;
      } elsif ($seq[$i] =~ /[ACTG]/) {
        $consensus[$i]->{$seq[$i]}++;
      }
    }
  }
  for (my $i=0; $i<@consensus; $i++) {
    my $cons_hash_ref = $consensus[$i];
    my $max = 0;
    my $consensus_nucleotide;
    while (my ($nucleotide, $this_count) = each %$cons_hash_ref) {
      if ($this_count > $max) {
        $max = $this_count;
        $consensus_nucleotide = $nucleotide;
      }
    }
    push(@conservation, $max);
    $consensus[$i] = $consensus_nucleotide;
  }

  ####################################################
  # Score each position according to previous values
  ####################################################
  my @final_scores;
  for (my $i = 0; $i < @consensus - 3; $i++) {
    my @these_bases = @consensus[$i..($i+3)];
    my @these_gaps = @gaps[$i..($i+3)];
    my @these_scores = @conservation[$i..($i+3)];
    my $total_score = 0;
    # Same as max score - 1 * $num_mismatches
    for (my $j=0; $j<4; $j++) {
      $total_score += $these_scores[$j];
    }
    # 3 points for every gap
    for (my $j=0; $j<4; $j++) {
      $total_score -= 3 * ($these_gaps[$j] || 0);
    }
    my $all_bases;
    for (my $j=0; $j<4; $j++) {
      $all_bases->{$these_bases[$j]}++;
    }
    if ($these_bases[0] eq $these_bases[2] and
      # Avoid repetitive sequence
        $these_bases[1] eq $these_bases[3]) {
      $total_score -= $num_of_leaves;
      if ($these_bases[0] eq $these_bases[1]) {
        $total_score -= $num_of_leaves;
      }
    } elsif (scalar(keys %$all_bases) == 2) {
      # simple sequence (only 2 diff nucleotides in 4 bp)
      $total_score -= $num_of_leaves/2;
    } elsif (scalar(keys %$all_bases) == 4) {
      # Give an extra point to runs of all 4 diff nucleotides
      $total_score += 1;
    }
    push(@final_scores, $total_score);
#     print join(" : ", @these_bases, @these_gaps,@these_scores, $total_score), "\n";
  }

  my $max_score = 0;
  my $best_position = 0;
  for (my $i = 0; $i < @final_scores; $i++) {
    if ($final_scores[$i] > $max_score) {
      $max_score = $final_scores[$i];
      $best_position = $i+2;
    }
  }

  warn "Cannot find a good position" if ($best_position == 0 or $max_score < 0.8 * $ideal_score);

  return $best_position;
}

sub get_trimmed_anchor_aligns {
  my ($self, $best_position) = @_;
  my $trimmed_anchor_aligns;

  my $aligned_sequences = $self->param('aligned_sequences');
# #   while (my ($align_anchor_id, $aligned_sequence) = each %$aligned_sequences) {
# #     print substr($aligned_sequence, 0, $best_position), " ** ", substr($aligned_sequence, $best_position),
# #         " :: $align_anchor_id\n";
# #   }
  my $all_anchor_aligns = $self->param('anchor_aligns');
  foreach my $this_anchor_align (@$all_anchor_aligns) {
    my $this_anchor_align_id = $this_anchor_align->dbID;
    my $this_aligned_sequence = $aligned_sequences->{$this_anchor_align_id};
# #     print substr($this_aligned_sequence, 0, ($best_position -1)), " ** ",
# #         substr($this_aligned_sequence, $best_position-1, 2) , " ** ",
# #         substr($this_aligned_sequence, ($best_position + 1)),
# #         " ++ $this_anchor_align_id\n";

    my $seq_before = substr($this_aligned_sequence, 0, $best_position);
    my $seq_after = substr($this_aligned_sequence, $best_position);
    my $start = $this_anchor_align->dnafrag_start;
    my $end = $this_anchor_align->dnafrag_end;


    my ($count_before) = $seq_before =~ tr/ACTGactgNn/ACTGactgNn/;
    my ($count_after) = $seq_after =~ tr/ACTGactgNn/ACTGactgNn/;

# print "SEQ_BEF: $seq_before $count_before\n";
# print "SEQ_AFT: $seq_after $count_after\n";



    if ($count_before + $count_after != $end - $start + 1) {
      $self->input_job->transient_error(0);
      die "Wrong length $count_before * $count_after * $start * $end * $seq_before * $count_before * $seq_after * $count_after +";
    }
    if ($this_anchor_align->dnafrag_strand == 1) {
      $start += $count_before - 1;
      $end -= $count_after - 1;
    } elsif ($this_anchor_align->dnafrag_strand == -1) {
      $start += $count_after - 1;
      $end -= $count_before - 1;
    } else {
      die "Wrong strand: ".$this_anchor_align->dnafrag_strand;
    }
    # Check we get a 2bp long anchor_align
    if ($end - $start + 1 != 2) {
      die "Wrong length $start $end";
    }
    my $new_anchor_align;
    %$new_anchor_align = %$this_anchor_align;
    bless $new_anchor_align, ref($this_anchor_align);
    delete($new_anchor_align->{'_seq'});
    delete($new_anchor_align->{'dbID'});
    $new_anchor_align->dnafrag_start($start);
    $new_anchor_align->dnafrag_end($end);
    $new_anchor_align->method_link_species_set_id($self->param('output_method_link_species_set_id'));
    push(@$trimmed_anchor_aligns, $new_anchor_align);
  }

  return $trimmed_anchor_aligns;
}

1;

