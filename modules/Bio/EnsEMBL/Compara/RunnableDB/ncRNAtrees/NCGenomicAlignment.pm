=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCGenomicAlignment;

use strict;
use warnings;
use Data::Dumper;
use Time::HiRes qw /time/;

use Bio::EnsEMBL::Compara::AlignedMemberSet;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Compara::Utils::Preloader;
use Bio::EnsEMBL::Utils::Sequence qw(reverse_comp);
use Bio::EnsEMBL::Compara::Utils::Cigars qw(cigar_from_alignment_string);

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree');

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'mafft_mode'        => '--auto',
    };
}

# We should receive:
# gene_tree_id
sub fetch_input {
    my ($self) = @_;
    my $nc_tree_id = $self->param('gene_tree_id');
    my $nc_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($nc_tree_id);
    $self->param('gene_tree', $nc_tree);
    $self->throw("tree with id $nc_tree_id is undefined") unless (defined $nc_tree);
    $self->cleanup_worker_temp_directory;
    $self->param('input_fasta', $self->dump_sequences_to_workdir($nc_tree));

    # Autovivification
    $self->param("method_treefile", {});
}

sub run {
    my ($self) = @_;
    my $nc_tree_id = $self->param('gene_tree_id');
    if ($self->param('single_peptide_tree')) {
        $self->input_job->autoflow(0);
        $self->complete_early("single peptide tree\n");
    }

    if ($self->param('tag_gene_count') > 1000) { ## Too much
        $self->input_job->autoflow(0);
        $self->complete_early(sprintf("family %d has too many members (%s). No genomic alignments will be computed\n", $nc_tree_id, $self->param('tag_gene_count')));
    }

    if ($self->param('tag_residue_count') > 150000) {  ## Likely to take too long
        $self->run_mafft;
        # We put the alignment into the db
        $self->store_fasta_alignment('mafft');
        $self->param('gene_align_id', $self->param('alignment_id'));
        $self->call_one_hc('unpaired_alignment');

        $self->dataflow_output_id (
                                   {
                                    'gene_tree_id' => $self->param('gene_tree_id'),
                                    'fastTreeTag' => "ftga_it_nj",
                                    'raxmlLightTag' => "ftga_it_ml",
                                    'alignment_id' => $self->param('alignment_id'),
                                   },3
                                  );
        $self->input_job->autoflow(0);
        $self->complete_early(sprintf("Family too big for normal branch (%s bps) -- Only FastTrees will be generated\n", $self->param('tag_residue_count')));
    }
    if (($self->param('tag_residue_count') > 40000) && !$self->param('inhugemem')) { ## Big family -- queue in hugemem
        $self->dataflow_output_id(undef, -1);
        # Should we die here? Nothing more to do in the Runnable?
        $self->input_job->autoflow(0);
        $self->complete_early(sprintf("Re-scheduled in hugemem queue (%s bps)\n", $self->param('tag_residue_count')));

    }

    if ($self->param('tag_gene_count') < 4) { # RAxML would fail for families with < 4 members
        $self->run_prank;
    } else {
        $self->run_mafft;
        $self->fasta2phylip;
        $self->run_RAxML;
        $self->run_prank;
    }
    return;
}

sub write_output {
    my ($self) = @_;
    $self->store_fasta_alignment('prank');
    $self->param('gene_align_id', $self->param('alignment_id'));
    $self->call_one_hc('unpaired_alignment');
    for my $method (qw/phyml nj/) {
        $self->dataflow_output_id (
                                   {
                                    'gene_tree_id'   => $self->param('gene_tree_id'),
                                    'method'       => $method,
                                    'alignment_id' => $self->param('alignment_id'),
                                   }, 2
                                  );
    }
}

sub dump_sequences_to_workdir {
    my ($self,$cluster,$no_flanking) = @_;
    my $fastafile = $self->worker_temp_directory . "/cluster_" . $cluster->root_id . ".fasta";

    my $member_list = $cluster->get_all_leaves;
    $self->param('tag_gene_count', scalar (@{$member_list}) );
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_DnaFrags($cluster->adaptor->db->get_DnaFragAdaptor, $member_list);

    if (scalar @{$member_list} < 2) {
        $self->param('single_peptide_tree', 1);
        return 1;
    }
    open (my $outseq_fh, '>', $fastafile) or $self->throw("Error opening $fastafile for writing: $!");

    my $residues = 0;
    my $count = 0;
    $cluster->adaptor->db->get_GenomeDBAdaptor->dump_dir_location($self->param_required('genome_dumps_dir'));
    my $max_length = 0;
    my %boundaries_by_member;
    my $transcript_edits_found = 0;
    my $members_lacking_exon_boundaries = 0;
    foreach my $member (@{$member_list}) {
        my $gene_member = $member->gene_member;
        $self->throw("Error fetching gene_member") unless (defined $gene_member) ;

        my $seq;
        if ($no_flanking) {
            $seq = $member->sequence();
        } else {
            my $locus = $gene_member->expand_Locus('500%');
            $seq = $locus->get_sequence();

            $transcript_edits_found = 1 if $member->has_transcript_edits;

            unless ($transcript_edits_found) {
                my $exon_boundaries = $member->adaptor->db->get_SeqMemberAdaptor->fetch_exon_boundaries_by_SeqMember($member);

                $members_lacking_exon_boundaries = 1 if scalar(@{$exon_boundaries}) == 0;

                unless ($members_lacking_exon_boundaries) {
                    my $locus_boundaries = [$locus->dnafrag_start, $locus->dnafrag_end, $locus->dnafrag_strand];
                    $boundaries_by_member{$member->seq_member_id} = {
                        'locus' => $locus_boundaries,
                        'exons' => $exon_boundaries,
                    };
                }
            }
        }

        $max_length = length($seq) if length($seq) > $max_length;
        $residues += length($seq);
        $seq =~ s/(.{72})/$1\n/g;
        chomp $seq;
        $count++;
        print STDERR $member->stable_id. "\n" if ($self->debug);
        print $outseq_fh ">" . $member->seq_member_id . "\n$seq\n";
        print STDERR "sequences $count\n" if ($count % 50 == 0);
    }
    close $outseq_fh;

    if ($max_length >= 1_000_000) {
        $self->param('no_flanking', 1);
        $cluster->print_sequences_to_file($fastafile, -FORMAT => 'fasta');
        $residues = 0;
        $residues += length($_->sequence) for @$member_list;
    }

    my $store_unflanked_alignment = !(
        $no_flanking
        || $self->param('no_flanking')
        || $transcript_edits_found
        || $members_lacking_exon_boundaries
    );
    $self->param('boundaries_by_member', \%boundaries_by_member) if ($store_unflanked_alignment);
    $self->param('store_unflanked_alignment', $store_unflanked_alignment);

    $self->param('tag_residue_count', $residues);

    return $fastafile;
}


sub run_mafft {
    my ($self) = @_;

#    return if ($self->param('too_few_sequences') == 1); # return? die? $self->throw?
    my $nc_tree_id = $self->param('gene_tree_id');
    my $input_fasta = $self->param('input_fasta');
    my $mafft_output = $self->worker_temp_directory . "/mafft_".$nc_tree_id . ".msa";
    $self->param('mafft_output',$mafft_output);

    my $mafft_exe      = $self->require_executable('mafft_exe');
    my $raxml_number_of_cores = $self->param('raxml_number_of_cores');

    my $cmd = "$mafft_exe --auto --thread $raxml_number_of_cores --threadtb 0 $input_fasta > $mafft_output";
    print STDERR "Running mafft\n$cmd\n" if ($self->debug);
    print STDERR "mafft_output has been set to " . $self->param('mafft_output') . "\n" if ($self->debug);

    my $command = $self->run_command($cmd, { timeout => $self->param('cmd_max_runtime') } );
    if ($command->exit_code) {
        print STDERR "We have a problem running Mafft -- Inspecting error\n";

        if ($command->exit_code == -2) {
            # Even Mafft takes ages. Give up ... !
            $self->input_job->autoflow(0);
            $self->complete_early(sprintf("Timeout reached, Mafft analysis will most likely not finish. Giving up on this family.\n"));
        }

        $command->die_with_log;
    }
}

sub run_RAxML {
    my ($self) = @_;

    my $nc_tree_id = $self->param('gene_tree_id');
    my $aln_file = $self->param('phylip_output');
    return unless (defined $aln_file);

    my $raxml_outdir = $self->worker_temp_directory;
    my $raxml_outfile = "raxml_${nc_tree_id}.raxml";
    my $raxml_output = $raxml_outdir."/$raxml_outfile";

    $self->param('raxml_output',"$raxml_outdir/RAxML_bestTree.$raxml_outfile");

    my $bootstrap_num = 10;  ## Should be soft-coded?
    my $raxml_number_of_cores = $self->param('raxml_number_of_cores');
    
    $self->raxml_exe_decision();
    my $raxml_exe = $self->require_executable('raxml_exe');

    my $cmd = $raxml_exe;
    $cmd .= " -p 12345";
    $cmd .= " -T $raxml_number_of_cores";
    $cmd .= " -m GTRGAMMA";
    $cmd .= " -s $aln_file";
    $cmd .= " -N $bootstrap_num";
    $cmd .= " -n $raxml_outfile";

    my $command = $self->run_command("cd $raxml_outdir; $cmd", { timeout => $self->param('cmd_max_runtime') } );
    if ($command->exit_code) {
        print STDERR "We have a problem running RAxML -- Inspecting error\n";
        # memory problem?
        if ($command->err =~ /malloc_aligned/) {
            $self->dataflow_output_id(undef, -1);
            $self->input_job->autoflow(0);
            $self->complete_early("RAXML ERROR: Problem allocating memory. Re-scheduled with more memory");
        }

        if ($command->exit_code == -2) {
            $self->store_fasta_alignment('mafft');
            $self->dataflow_output_id (
                {
                    'gene_tree_id'  => $self->param('gene_tree_id'),
                    'fastTreeTag'   => "ftga_it_nj",
                    'raxmlLightTag' => "ftga_it_ml",
                    'alignment_id'  => $self->param('alignment_id'),
                }, 3 #branch 3 (fast_trees)
            );
            $self->input_job->autoflow(0);
            $self->complete_early(sprintf("Timeout reached, RAxML analysis will most likelly not finish. Data-flowing to 'fast_trees'.\n"));
        }

        $command->die_with_log;
    }

    return
}

sub _get_bootstraps {
    my ($self,$bootstrap_msec, $bootstrap_num) = @_;

    my $ideal_msec = 30000; # 5 minutes
    my $time_per_sample = $bootstrap_msec / $bootstrap_num;
    my $ideal_bootstrap_num = $ideal_msec / $time_per_sample;
    if ($ideal_bootstrap_num < 5) {
        $self->param('bootstrap_num',1);
    } elsif ($ideal_bootstrap_num < 10) {
        $self->param('bootstrap_num',10);
    } elsif ($ideal_bootstrap_num > 100) {
        $self->param('bootstrap_num',100)
    } else {
        $self->param('bootstrap_num',int ($ideal_bootstrap_num));
    }
    return
}

sub run_prank {
    my ($self) = @_;

    my $nc_tree_id = $self->param('gene_tree_id');
    my $input_fasta = $self->param('input_fasta');
    my $tree_file = $self->param('raxml_output');
#    $self->throw("$tree_file does not exist\n") unless (-e $tree_file);

    ## FIXME -- The alignment has to be passed to NCGenomicTree. We have several options:
    # 1.- Store the alignments in the database
    # 2.- Store the alignments in a shared filesystem (i.e. lustre)
    # 3.- Pass it in memory as a string (but it may surpass the input_id text limit!)
    # For now, we will be using #1
    my $prank_output = $self->worker_temp_directory . "/prank_${nc_tree_id}.prank";

    my $prank_exe = $self->require_executable('prank_exe');

    my $cmd = $prank_exe;
    # /software/ensembl/compara/prank/090707/src/prank -once -f=Fasta -o=/tmp/worker.904/cluster_17438.mfa -d=/tmp/worker.904/cluster_17438.fast -t=/tmp/worker.904/cluster17438/RAxML.tree
    $cmd .= " -once -f=Fasta";
    $cmd .= " -t=$tree_file" if (defined $tree_file);
    $cmd .= " -o=$prank_output";
    $cmd .= " -d=$input_fasta";

    #$self->run_command($cmd, { die_on_failure => 1, timeout => $self->param('cmd_max_runtime') } );

    my $command = $self->run_command($cmd, { timeout => $self->param('cmd_max_runtime') } );
    if ($command->exit_code) {
        print STDERR "We have a problem running PRANK\n";
        if ($command->exit_code == -2) {
            $self->store_fasta_alignment('mafft');
            $self->dataflow_output_id (
                {
                    'gene_tree_id'  => $self->param('gene_tree_id'),
                    'fastTreeTag'   => "ftga_it_nj",
                    'raxmlLightTag' => "ftga_it_ml",
                    'alignment_id'  => $self->param('alignment_id'),
                }, 3 #branch 3 (fast_trees)
            );
            $self->input_job->autoflow(0);
            $self->complete_early(sprintf("Timeout reached, Prank will most likely not finish. Data-flowing to 'fast_trees'.\n"));
        }
        $command->die_with_log;
    }

    # prank renames the output by adding ".2.fas" => .1.fas" because it doesn't need to make the tree
    print STDERR "Prank output : ${prank_output}.best.fas\n" if ($self->debug);
    $self->param('prank_output',"${prank_output}.best.fas");
    return;
}

sub fasta2phylip {
    my ($self) = @_;
#    return 1 if ($self->param('too_few_sequences') == 1); # This has been checked before
    my $fasta_in = $self->param('mafft_output');
    my $nc_tree_id = $self->param('gene_tree_id');
    my $phylip_out = $self->worker_temp_directory . "/mafft_${nc_tree_id}.phylip";
    my %seqs;
    open my $msa, "<", $fasta_in or $self->throw("I can not open the prank msa file $fasta_in : $!\n");
    my ($header,$seq);
    while (<$msa>) {
        chomp;
        if (/^>/) {
            $seqs{$header} = $seq if (defined $header);
            $header = substr($_,1);
            $seq = "";
            next;
        }
        $seq .= $_;
    }
    $seqs{$header} = $seq;

    close($msa);

    my $nseqs = scalar(keys %seqs);
    my $length = length($seqs{$header});

    open my $phy, ">", $phylip_out or $self->throw("I can not open the phylip output file $phylip_out : $!\n");
    print $phy "$nseqs $length\n";
    for my $h (keys %seqs) {
        printf $phy ("%-9.9s ",$h);
        $seqs{$h} =~ s/^-/A/;
        print $phy $seqs{$h}, "\n";
    }
    close($phy);
    $self->param('phylip_output',$phylip_out);
}

sub store_fasta_alignment {
    my ($self, $aln_method) = @_;

    my $nc_tree_id = $self->param('gene_tree_id');
    my $aln_file = $self->param("${aln_method}_output");

    my $aln = $self->param('gene_tree')->deep_copy();
    bless $aln, 'Bio::EnsEMBL::Compara::AlignedMemberSet';
    $aln->aln_method($aln_method);
    if ($self->param('no_flanking')) {
        $aln->load_cigars_from_file($aln_file, -format => 'fasta');
    } else {
        $aln->seq_type('seq_with_flanking');
        $aln->load_cigars_from_file($aln_file, -format => 'fasta', -import_seq => 1);

        my $sequence_adaptor = $self->compara_dba->get_SequenceAdaptor;
        foreach my $member (@{$aln->get_all_Members}) {
            $sequence_adaptor->store_other_sequence($member, $member->sequence, 'seq_with_flanking');
        }
    }

    $aln->dbID( $self->param('gene_tree')->get_value_for_tag('genomic_alignment_gene_align_id') );
    $self->compara_dba->get_GeneAlignAdaptor->store($aln);
    $self->param('alignment_id', $aln->dbID);
    $self->param('gene_tree')->store_tag('genomic_alignment_gene_align_id', $aln->dbID);

    if ($self->param('store_unflanked_alignment')) {
        $self->store_unflanked_alignment($self->param('gene_tree'), $aln);
    }

    return;
}

sub store_unflanked_alignment {
    my ($self, $nc_tree, $aln) = @_;

    my $boundaries_by_member = $self->param('boundaries_by_member');

    my $flanked_sa = $aln->get_SimpleAlign(-ID_TYPE => 'MEMBER');
    while (my ($member_id, $member_boundaries) = each %{$boundaries_by_member}) {
        my ($locus_dnafrag_start, $locus_dnafrag_end, $locus_dnafrag_strand) = @{$member_boundaries->{'locus'}};

        my $flanked_sa_seq = $flanked_sa->get_seq_by_id($member_id);

        # This will ultimately be an alignment sequence with nonexonic regions masked, though to keep things
        # simpler we start with a fully masked sequence and then insert the aligned sequence for each exon.
        my $masked_align_seq = '-' x $flanked_sa->length;

        my @exon_boundaries_wrt_align;
        foreach my $exon (@{$member_boundaries->{'exons'}}) {
            my ($exon_dnafrag_start, $exon_dnafrag_end) = @{$exon};

            my $exon_start_wrt_locus;
            my $exon_end_wrt_locus;
            if ($locus_dnafrag_strand == 1) {
                $exon_start_wrt_locus = $exon_dnafrag_start - $locus_dnafrag_start + 1;
                $exon_end_wrt_locus = $exon_dnafrag_end - $locus_dnafrag_start + 1;
            } else {
                $exon_start_wrt_locus = $locus_dnafrag_end - $exon_dnafrag_end  + 1;
                $exon_end_wrt_locus = $locus_dnafrag_end - $exon_dnafrag_start + 1;
            }

            my $exon_start_wrt_align = $flanked_sa->column_from_residue_number($member_id, $exon_start_wrt_locus);
            my $exon_end_wrt_align = $flanked_sa->column_from_residue_number($member_id, $exon_end_wrt_locus);
            my $exon_offset_wrt_align = $exon_start_wrt_align - 1;
            my $exon_length_wrt_align = $exon_end_wrt_align - $exon_start_wrt_align + 1;
            my $extracted_exon_align_seq = substr($flanked_sa_seq->seq, $exon_offset_wrt_align, $exon_length_wrt_align);
            substr($masked_align_seq, $exon_offset_wrt_align, $exon_length_wrt_align, $extracted_exon_align_seq);
        }

        $flanked_sa_seq->seq($masked_align_seq);
    }

    # Removing all-gap columns should filter out most masked nonexonic sequence, and leave
    # us with an alignment in which every column contains sequence from at least one exon.
    my $unflanked_sa = $flanked_sa->remove_gaps(undef, 1);

    my $unflanked_aln = $nc_tree->deep_copy();
    bless $unflanked_aln, 'Bio::EnsEMBL::Compara::AlignedMemberSet';
    $unflanked_aln->aln_method('unflanked_' . $aln->aln_method());
    $unflanked_aln->aln_length($unflanked_sa->length);
    $unflanked_aln->seq_type(undef);

    foreach my $member (@{$unflanked_aln->get_all_Members()}) {
        my $unflanked_sa_seq = $unflanked_sa->get_seq_by_id($member->dbID)->seq;
        my $cigar = Bio::EnsEMBL::Compara::Utils::Cigars::cigar_from_alignment_string($unflanked_sa_seq);
        $member->cigar_line($cigar);
    }

    if ($self->debug) {
        my $member_adaptor = $self->compara_dba->get_SeqMemberAdaptor();
        foreach my $member (@{$unflanked_aln->get_all_Members()}) {
            my $gapped_sa_seq = uc($unflanked_sa->get_seq_by_id($member->dbID)->seq);
            my $ungapped_sa_seq = $gapped_sa_seq =~ s/-//gr;
            my $seq_member = $member_adaptor->fetch_by_dbID($member->dbID);
            if ($ungapped_sa_seq ne $seq_member->sequence) {
                $self->die_no_retry(
                    sprintf(
                        "sequence mismatch for member %d - member sequence '%s' vs ungapped alignment sequence '%s'",
                        $member->dbID,
                        $seq_member->sequence,
                        $ungapped_sa_seq,
                    )
                );
            }
        }
    }

    $unflanked_aln->dbID( $nc_tree->get_value_for_tag('unflanked_alignment_gene_align_id') );
    $self->compara_dba->get_GeneAlignAdaptor->store($unflanked_aln);
    $nc_tree->store_tag('unflanked_alignment_gene_align_id', $unflanked_aln->dbID);
    $nc_tree->store_tag('unflanked_alignment_length', $unflanked_sa->length);
    $nc_tree->store_tag('unflanked_alignment_num_residues', $unflanked_sa->num_residues);
    $nc_tree->store_tag('unflanked_alignment_percent_identity', $unflanked_sa->average_percentage_identity);
}

1;
