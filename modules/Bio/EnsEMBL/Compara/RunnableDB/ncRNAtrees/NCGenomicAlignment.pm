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

package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCGenomicAlignment;

use strict;
use warnings;
use Data::Dumper;
use Time::HiRes qw /time/;

use Bio::EnsEMBL::Compara::AlignedMemberSet;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Utils::Sequence qw(reverse_comp);

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree');

# We should receive:
# gene_tree_id
sub fetch_input {
    my ($self) = @_;
    my $nc_tree_id = $self->param('gene_tree_id');
    my $nc_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($nc_tree_id);
    $self->param('gene_tree', $nc_tree);
    $self->throw("tree with id $nc_tree_id is undefined") unless (defined $nc_tree);
    $self->param('input_fasta', $self->dump_sequences_to_workdir($nc_tree));

    $self->param('aln_seq_type', "seq_with_flanking");

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
                                    'aln_seq_type' => $self->param('aln_seq_type'),
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
    my ($self,$cluster) = @_;
    my $fastafile = $self->worker_temp_directory . "/cluster_" . $cluster->root_id . ".fasta";

    my $member_list = $cluster->get_all_leaves;
    $self->param('tag_gene_count', scalar (@{$member_list}) );

    open (OUTSEQ, ">$fastafile") or $self->throw("Error opening $fastafile for writing: $!");
    if (scalar @{$member_list} < 2) {
        $self->param('single_peptide_tree', 1);
        return 1;
    }

    my $residues = 0;
    my $count = 0;
    foreach my $member (@{$member_list}) {
      $member->genome_db->db_adaptor->dbc->prevent_disconnect( sub {
        my $gene_member = $member->gene_member;
        $self->throw("Error fetching gene_member") unless (defined $gene_member) ;
        my $gene = $gene_member -> get_Gene;
        $self->throw("Error fetching gene") unless (defined $gene);
        my $slice = $gene->slice->adaptor->fetch_by_Feature($gene, '500%');
        $self->throw("Error fetching slice") unless (defined $slice);
        my $seq = $slice->seq;
        # fetch_by_Feature returns always the + strand
        if ($gene->strand() < 0) {
            reverse_comp(\$seq);
        }
        $residues += length($seq);
        $seq =~ s/(.{72})/$1\n/g;
        chomp $seq;
        $count++;
        print STDERR $member->stable_id. "\n" if ($self->debug);
        print OUTSEQ ">" . $member->seq_member_id . "\n$seq\n";
        print STDERR "sequences $count\n" if ($count % 50 == 0);
      } );
    }
    close OUTSEQ;

    if(scalar (@{$member_list}) <= 1) {
        $self->update_single_peptide_tree($cluster);
        $self->param('single_peptide_tree', 1);
    }

    $self->param('tag_residue_count', $residues);

    return $fastafile;
}

sub update_single_peptide_tree {
    my ($self, $tree) = @_;

    foreach my $member (@{$tree->get_all_leaves}) {
        next unless($member->isa('Bio::EnsEMBL::Compara::GeneTreeMember'));
        next unless($member->sequence);
        $member->cigar_line(length($member->sequence)."M");
        $self->compara_dba->get_GeneTreeNodeAdaptor->store_node($member);
        printf("single_pepide_tree %s : %s\n", $member->stable_id, $member->cigar_line) if($self->debug);
    }
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

    my $cmd = "$mafft_exe --auto --thread $raxml_number_of_cores $input_fasta > $mafft_output";
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

        die "MAFFT ERROR: ", $command->err, "\n";
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
                    'aln_seq_type'  => $self->param('aln_seq_type'),
                }, 3 #branch 3 (fast_trees)
            );
            $self->input_job->autoflow(0);
            $self->complete_early(sprintf("Timeout reached, RAxML analysis will most likelly not finish. Data-flowing to 'fast_trees'.\n"));
        }

        die "RAXML ERROR: ", $command->err, "\n";
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
                    'aln_seq_type'  => $self->param('aln_seq_type'),
                }, 3 #branch 3 (fast_trees)
            );
            $self->input_job->autoflow(0);
            $self->complete_early(sprintf("Timeout reached, Prank will most likely not finish. Data-flowing to 'fast_trees'.\n"));
        }
        die "PRANK ERROR: ", $command->err, "\n";
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
    my $aln_seq_type = $self->param('aln_seq_type');

    my $aln = $self->param('gene_tree')->deep_copy();
    bless $aln, 'Bio::EnsEMBL::Compara::AlignedMemberSet';
    $aln->seq_type($aln_seq_type);
    $aln->aln_method($aln_method);
    $aln->load_cigars_from_file($aln_file, -format => 'fasta', -import_seq => 1);

    my $sequence_adaptor = $self->compara_dba->get_SequenceAdaptor;
    foreach my $member (@{$aln->get_all_Members}) {
        $sequence_adaptor->store_other_sequence($member, $member->sequence, 'seq_with_flanking');
    }

    $aln->dbID( $self->param('gene_tree')->get_value_for_tag('genomic_alignment_gene_align_id') );
    $self->compara_dba->get_GeneAlignAdaptor->store($aln);
    $self->param('alignment_id', $aln->dbID);
    $self->param('gene_tree')->store_tag('genomic_alignment_gene_align_id', $aln->dbID);
    return;
}

1;
