package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCGenomicAlignment;

use strict;
use warnings;
use Data::Dumper;
use Time::HiRes qw /time/;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Utils::Sequence qw(reverse_comp);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

# We should receive:
# nc_tree_id
sub fetch_input {
    my ($self) = @_;
    my $nc_tree_id = $self->param('nc_tree_id');
    my $nc_tree = $self->compara_dba->get_NCTreeAdaptor->fetch_node_by_node_id($nc_tree_id);
    $self->throw("tree with id $nc_tree_id is undefined") unless (defined $nc_tree);
    $self->param('nc_tree', $nc_tree);
    $self->param('input_fasta', $self->dump_sequences_to_workdir($nc_tree));

    # Autovivification
    $self->param("method_treefile", {});
}

sub run {
    my ($self) = @_;
    my $nc_tree_id = $self->param('nc_tree_id');
    if ($self->param('single_peptide_tree')) {
        $self->input_job->incomplete(0);
        die "single peptide tree\n";
    }

    if ($self->param('tag_gene_count') > 1000) { ## Too much
        $self->input_job->incomplete(0);
        my $tag_gene_count = $self->param('tag_gene_count');
        die "family $nc_tree_id has too many member ($tag_gene_count). No genomic alignments will be computed\n";
    }

    if ($self->param('tag_residue_count') > 150000) {  ## Likely to take too long
        $self->run_mafft;
        # We put the alignment into the db
        $self->store_fasta_alignment('mafft_output');

        $self->dataflow_output_id (
                                   {
                                    'nc_tree_id' => $self->param('nc_tree_id'),
                                    'fastTreeTag' => "ftga_IT_nj",
                                    'raxmlLightTag' => "ftga_IT_ml",
                                    'alignment_id' => $self->param('alignment_id'),
                                   },3
                                  );

        $self->input_job->incomplete(0);
        my $tag_residue_count = $self->param('tag_residue_count');
        die "Family too big for normal branch ($tag_residue_count bps) -- Only FastTrees will be generated\n";
    }
    if (($self->param('tag_residue_count') > 40000) && $self->param('inhugemem') != 1) { ## Big family -- queue in hugemem
        $self->dataflow_output_id (
                                   {
                                    'nc_tree_id' => $self->param('nc_tree_id'),
                                    'alignment_id' => $self->param('alignment_id'),
                                    'inhugemem' => 1,
                                   }, -1
                                  );
        # Should we die here? Nothing more to do in the Runnable?
        my $tag_residue_count = $self->param('tag_residue_count');
        $self->input_job->incomplete(0);
        die "Re-scheduled in hugemem queue ($tag_residue_count bps)\n";
    } else {
        $self->run_mafft;
        $self->fasta2phylip;
        ## FIXME -- RAxML will fail for families with < 4 members.
        $self->run_RAxML;
        $self->run_prank;
#    $self->run_ncgenomic_tree('phyml');
#    $self->run_ncgenomic_tree('nj'); # Useful for 3-membered trees
    }
}

sub write_output {
    my ($self) = @_;
#     if ($self->param("MEMLIMIT")) { ## We had a problem in RAxML -- re-schedule in hugemem
#         $self->dataflow_output_id (
#                                    {
#                                     'nc_tree_id' => $self->param('nc_tree_id')
#                                    }, -1
#                                   );
#     } else {
        for my $method (qw/phyml nj/) {
            $self->dataflow_output_id (
                                       {
                                        'nc_tree_id'   => $self->param('nc_tree_id'),
                                        'method'       => $method,
                                        'alignment_id' => $self->param('alignment_id'),
                                       }, 2
                                      );
        }
#    }
}

sub dump_sequences_to_workdir {
    my ($self,$cluster) = @_;
    my $fastafile = $self->worker_temp_directory . "cluster_" . $cluster->node_id . ".fasta";

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
        my $gene_member = $member->gene_member;
        $self->throw("Error fetching gene member") unless (defined $gene_member) ;
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
        print OUTSEQ ">" . $member->member_id . "\n$seq\n";
        print STDERR "sequences $count\n" if ($count % 50 == 0);
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
        $self->compara_dba->get_NCTreeAdaptor->store($member);
        printf("single_pepide_tree %s : %s\n", $member->stable_id, $member->cigar_line) if($self->debug);
    }
}

sub run_mafft {
    my ($self) = @_;

#    return if ($self->param('too_few_sequences') == 1); # return? die? $self->throw?
    my $nc_tree_id = $self->param('nc_tree_id');
    my $input_fasta = $self->param('input_fasta');
    my $mafft_output = $self->worker_temp_directory . "/mafft_".$nc_tree_id . ".msa";
    $self->param('mafft_output',$mafft_output);

    my $mafft_exe      = $self->param('mafft_exe')
        or die "'mafft_exe' is an obligatory parameter";

    die "Cannot execute '$mafft_exe'" unless(-x $mafft_exe);

    my $mafft_binaries = $self->param('mafft_binaries')
        or die "'mafft_binaries' is an obligatory parameter";

    $ENV{MAFFT_BINARIES} = $mafft_binaries;

    my $cmd = "$mafft_exe --auto $input_fasta > $mafft_output";
    print STDERR "Running mafft\n$cmd\n" if ($self->debug);
    print STDERR "mafft_output has been set to " . $self->param('mafft_output') . "\n" if ($self->debug);
    $self->compara_dba->dbc->disconnect_when_inactive(0);
    unless ((my $err = system($cmd)) == 0) {
        $self->throw("problem running command $cmd: $err\n");
    }
    $self->compara_dba->dbc->disconnect_when_inactive(1);
}

sub run_RAxML {
    my ($self) = @_;

#    return if ($self->param('too_few_sequences') == 1);  # return? die? $self->throw? This has been checked before
    my $nc_tree_id = $self->param('nc_tree_id');
    my $aln_file = $self->param('phylip_output');
    return unless (defined $aln_file);

    my $raxml_outdir = $self->worker_temp_directory;
    my $raxml_outfile = "raxml_${nc_tree_id}.raxml";
    my $raxml_output = $raxml_outdir."/$raxml_outfile";

    $self->param('raxml_output',"$raxml_outdir/RAxML_bestTree.$raxml_outfile");

    my $raxml_exe = $self->param('raxml_exe')
        or die "'raxml_exe' is an obligatory parameter";

    die "Cannot execute '$raxml_exe'" unless(-x $raxml_exe);

    my $bootstrap_num = 10;  ## Should be soft-coded?
    my $raxml_err_file = $self->worker_temp_directory . "raxml.err";
    my $cmd = $raxml_exe;
    $cmd .= " -T 2";
    $cmd .= " -m GTRGAMMA";
    $cmd .= " -s $aln_file";
    $cmd .= " -N $bootstrap_num";
    $cmd .= " -n $raxml_outfile";
    $cmd .= " 2> $raxml_err_file";
    $self->compara_dba->dbc->disconnect_when_inactive(1);
#    my $bootstrap_starttime = time() * 1000;

    print STDERR "$cmd\n" if ($self->debug);
    unless (system("cd $raxml_outdir; $cmd") == 0) {
        # memory problem?
        print STDERR "We have a problem running RAxML -- Inspecting $raxml_err_file\n";
        open my $raxml_err_fh, "<", $raxml_err_file or die $!;
        while (<$raxml_err_fh>) {
            chomp;
            if (/malloc_aligned/) {
                $self->dataflow_output_id (
                                           {
                                            'nc_tree_id' => $self->param('nc_tree_id'),
                                           }, -1
                                          );
                $self->input_job->incomplete(0);
                die "RAXML ERROR: $_";
            }
        }
        close($raxml_err_fh);
    }

    $self->compara_dba->dbc->disconnect_when_inactive(0);
#    my $boostrap_msec = int(time() * 1000-$bootstrap_starttime);
#    $self->_get_bootstraps($bootstrap_msec,$bootstrap_num);  # Don't needed -- we don't run the second RAxML for now
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

#    return if ($self->param('too_few_sequences') == 1);  # return? die? $self->throw? This has been checked before
    my $nc_tree_id = $self->param('nc_tree_id');
    my $input_fasta = $self->param('input_fasta');
    my $tree_file = $self->param('raxml_output');
#    return unless (defined $tree_file);
    $self->throw("$tree_file does not exist\n") unless (-e $tree_file);

    ## FIXME -- The alignment has to be passed to NCGenomicTree. We have several options:
    # 1.- Store the alignments in the database
    # 2.- Store the alignments in a shared filesystem (i.e. lustre)
    # 3.- Pass it in memory as a string.
    # For now, we will be using #1
    my $prank_output = $self->worker_temp_directory . "/prank_${nc_tree_id}.prank";
#    my $prank_output = "/lustre/scratch103/ensembl/mp12/ncRNA_pipeline/prank_${nc_tree_id}.prank";

    my $prank_exe = $self->param('prank_exe')
        or die "'prank_exe' is an obligatory parameter";

    die "Cannot execute '$prank_exe'" unless(-x $prank_exe);

    my $cmd = $prank_exe;
    # /software/ensembl/compara/prank/090707/src/prank -noxml -notree -f=Fasta -o=/tmp/worker.904/cluster_17438.mfa -d=/tmp/worker.904/cluster_17438.fast -t=/tmp/worker.904/cluster17438/RAxML.tree
    $cmd .= " -noxml -notree -once -f=Fasta";
    $cmd .= " -t=$tree_file";
    $cmd .= " -o=$prank_output";
    $cmd .= " -d=$input_fasta";
    $self->compara_dba->dbc->disconnect_when_inactive(1);
    print("$cmd\n") if($self->debug);
    unless ((my $err = system ($cmd)) == 0) {
        $self->throw("problem running prank $cmd: $err\n");
    }

    # prank renames the output by adding ".2.fas" => .1.fas" because it doesn't need to make the tree
    print STDERR "Prank output : ${prank_output}.1.fas\n" if ($self->debug);
    $self->param('prank_output',"${prank_output}.1.fas");
    $self->store_fasta_alignment("prank_output");
}

sub fasta2phylip {
    my ($self) = @_;
#    return 1 if ($self->param('too_few_sequences') == 1); # This has been checked before
    my $fasta_in = $self->param('mafft_output');
    my $nc_tree_id = $self->param('nc_tree_id');
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

    if ($nseqs < 4) {
#        $self->param('too_few_sequences',1);
        $self->input_job->incomplete(0);
        die "Too few sequences (< 4), we can not compute RAxML tree";
    }

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
    my ($self, $param) = @_;

    my $nc_tree_id = $self->param('nc_tree_id');
    my $uniq_alignment_id = "$param" . "_" . $self->input_job->dbID ;
    my $aln_file = $self->param($param);

    # Insert a new alignment in the DB
    my $sql_new_alignment = "INSERT IGNORE INTO alignment (alignment_id, compara_table, compara_key) VALUES (?, 'ncrna', ?)";
    print STDERR "$sql_new_alignment\n" if ($self->debug);
    my $sth_new_alignment = $self->dbc->prepare($sql_new_alignment);
    $sth_new_alignment->execute($uniq_alignment_id, $nc_tree_id);
    $sth_new_alignment->finish();

    # read the alignment back from file
    print "Reading alignment fasta file $aln_file\n" if ($self->debug());
    open my $aln_fh, "<", $aln_file or die "I can't open $aln_file for reading\n";
    my $aln_header;
    my $aln_seq;
    my $sql_new_alnseq = "INSERT INTO aligned_sequence (alignment_id, aligned_length, member_id, aligned_sequence) VALUES (?,?,?,?)";
    my $sth_new_alnseq = $self->dbc->prepare($sql_new_alnseq);
    while (<$aln_fh>) {
        chomp;
        if (/^>/) {
            if (! defined ($aln_header)) {
                ($aln_header) = $_ =~ />(.+)/;
                next;
            }
            my $l = length($aln_seq);
            print STDERR "INSERT INTO aligned_sequence (alignment_id, aligned_length, member_id, aligned_sequence) VALUES ($uniq_alignment_id, $l, $aln_header, $aln_seq)\n";
            $sth_new_alnseq->execute($uniq_alignment_id, $l, $aln_header, $aln_seq);
            ($aln_header) = $_ =~ />(.+)/;
            $aln_seq = "";
        } else {
            $aln_seq .= $_;
        }
    }
    my $l = length($aln_seq);
    $sth_new_alnseq->execute($uniq_alignment_id, $l, $aln_header, $aln_seq);
    $sth_new_alnseq->finish();

    $self->param('alignment_id', $uniq_alignment_id);
    return;
}

1;
