=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=cut

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCFastTrees

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $ncfasttree = Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCFastTrees->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$ncfasttree->fetch_input(); #reads from DB
$ncfasttree->run();
$ncfasttree->output();
$ncfasttree->write_output(); #writes to DB

=head1 DESCRIPTION

This RunnableDB builds fast phylogenetic trees using RAxML-Light and FastTree2. It is useful in cases where the alignments are too big to build the usual RAxML trees in PrepareSecStructModels and SecStructModelTree.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable
  +- Bio::EnsEMBL::Hive::Process

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCFastTrees;

use strict;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

=head2 fetch_input

    Title    : fetch_input
    Usage    : $self->fetch_input
    Function : Fetches input data from the database+
    Returns  : none
    Args     : none

=cut

sub fetch_input {
    my ($self) = @_;

    $self->input_job->transient_error(0);
    my $nc_tree_id = $self->param('nc_tree_id') || die "'nc_tree_id' is an obligatory parameter\n";
    $self->input_job->transient_error(1);

    my $nc_tree = $self->compara_dba->get_NCTreeAdaptor->fetch_node_by_node_id($nc_tree_id) or $self->throw("Couldn't fetch nc_tree with id $nc_tree_id\n");
    $self->param('nc_tree', $nc_tree);

    if (my $alignment_id = $self->param('alignment_id')) {
        $self->_load_and_dump_alignment();
        # $self->param('aln_fasta') and/or $self->param('aln_file') are now set
#        $self->param('input_aln', $self->_load_and_dump_alignment());
        return;
    }
    if (my $input_aln = $self->_dumpMultipleAlignmentStructToWorkdir($nc_tree) ) {
        $self->param('input_aln', $input_aln);
    } else {
        die "I can't write input alignment to disc";
    }
}

=head2 run

    Title     : run
    Usage     : $self->run
    Function  : runs something
    Returns   : none
    Args      : none

=cut

sub run {
    my ($self) = @_;

    $self->_run_fasttree;
    $self->_run_parsimonator;
    $self->_run_raxml_light;
}

=head2 write_output

    Title     : write_output
    Usage     : $self->write_output
    Function  : stores something
    Returns   : none
    Args      : none

=cut

sub write_output {
    my ($self) = @_;

}


##########################################
#
# internal methods
#
##########################################

sub _run_fasttree {
    my $self = shift;
    my $aln_file;
    if (defined ($self->param('aln_fasta'))) {
        $aln_file = $self->param('aln_fasta');
    } else {
        $aln_file = $self->param('input_aln');
    }
#    my $aln_file = $self->param('input_aln');
    return unless (defined($aln_file));

    my $root_id = $self->param('nc_tree')->node_id;
    my $fasttree_tag = $root_id . ".". $self->worker->process_id . ".fasttree";

    my $fasttree_exe = $self->param('fasttree_exe')
        or die "'fasttree_exe' is an obligatory parameter";

    die "Cannot execute '$fasttree_exe'" unless(-x $fasttree_exe);

    my $fasttree_output = $self->worker_temp_directory . "FastTree.$fasttree_tag";
    my $tag = defined $self->param('fastTreeTag') ? $self->param('fastTreeTag') : 'ft_IT_nj';
#    my $tag = 'ft_IT_nj';
    my $cmd = $fasttree_exe;
    $cmd .= " -nt -quiet -nopr";
    $cmd .= " $aln_file";
    $cmd .= " > $fasttree_output";

    print STDERR "$cmd\n" if ($self->debug);
    $self->compara_dba->dbc->disconnect_when_inactive(1);
    unless(system("$cmd") == 0) {
        $self->throw("error running FastTree\n$cmd\n");
    }
    $self->compara_dba->dbc->disconnect_when_inactive(0);

    $self->_store_newick_into_nc_tree_tag_string($tag, $fasttree_output);

    return 1;
}

sub _run_parsimonator {
    my ($self) = @_;
    my $aln_file = $self->param('input_aln');
    my $worker_temp_directory = $self->worker_temp_directory;
    die "$aln_file is not defined" unless (defined($aln_file));
#    return unless(defined($aln_file));

    my $root_id = $self->param('nc_tree')->node_id;
    my $parsimonator_tag = $root_id . "." . $self->worker->process_id . ".parsimonator";

    my $parsimonator_exe = $self->param('parsimonator_exe')
        or die "'parsimonator_exe' is an obligatory parameter";

    die "Cannot execute '$parsimonator_exe'" unless(-x $parsimonator_exe);

    my $cmd = $parsimonator_exe;
    $cmd .= " -s $aln_file";
    $cmd .= " -n $parsimonator_tag";
    $cmd .= " -p 12345";

    print STDERR "$cmd\n" if ($self->debug);
    $self->compara_dba->dbc->disconnect_when_inactive(1);
    unless(system("cd $worker_temp_directory; $cmd") == 0) {
        $self->throw("error running parsimonator\ncd $worker_temp_directory; $cmd\n");
    }
    $self->compara_dba->dbc->disconnect_when_inactive(0);

    my $parsimonator_output = $worker_temp_directory . "/RAxML_parsimonyTree.${parsimonator_tag}.0";
    $self->param('parsimony_tree_file', $parsimonator_output);

    return;
}

sub _run_raxml_light {
    my ($self) = @_;
    my $aln_file = $self->param('input_aln');
    my $parsimony_tree = $self->param('parsimony_tree_file');
    my $worker_temp_directory = $self->worker_temp_directory;
    my $root_id = $self->param('nc_tree')->node_id;

    my $raxmlight_tag = $root_id . "." . $self->worker->process_id . ".raxmlight";

    my $raxmlLight_exe = $self->param('raxmlLight_exe')
        or die "'raxmlLight_exe' is an obligatory parameter";

    die "Cannot execute '$raxmlLight_exe'" unless(-x $raxmlLight_exe);

    my $tag = defined $self->param('raxmlLightTag') ? $self->param('raxmlLightTag') : 'ft_IT_ml';
#    my $tag = 'ft_IT_ml';
    my $cmd = $raxmlLight_exe;
    $cmd .= " -m GTRGAMMA";
    $cmd .= " -s $aln_file";
    $cmd .= " -t $parsimony_tree";
    $cmd .= " -n $raxmlight_tag";

    $self->compara_dba->dbc->disconnect_when_inactive(1);
    unless(system("cd $worker_temp_directory; $cmd") == 0) {
        $self->throw("error running raxmlLight\ncd $worker_temp_directory; $cmd\n");
    }
    $self->compara_dba->dbc->disconnect_when_inactive(0);

    my $raxmlight_output = $worker_temp_directory . "/RAxML_result.${raxmlight_tag}";
    $self->_store_newick_into_nc_tree_tag_string($tag, $raxmlight_output);

    # Unlink run files
    my $temp_regexp = $self->worker_temp_directory;
    unlink <*$raxmlight_tag*>;

    return
}

sub _dumpMultipleAlignmentStructToWorkdir {
    my ($self, $tree) = @_;

  my $root_id = $tree->node_id;
  my $leafcount = scalar(@{$tree->get_all_leaves});
  if($leafcount<4) {
      $self->input_job->incomplete(0);
      $self->throw("tree cluster $root_id has <4 proteins - can not build a raxml tree\n");
  }

  my $file_root = $self->worker_temp_directory. "nctree_". $root_id;
  $file_root    =~ s/\/\//\//g;  # converts any // in path to /

  my $aln_file = $file_root . ".aln";
#   if($self->debug) {
#     printf("dumpMultipleAlignmentStructToWorkdir : %d members\n", $leafcount);
#     print("aln_file = '$aln_file'\n");
#   }

  open(OUTSEQ, ">$aln_file")
    or $self->throw("Error opening $aln_file for write");

  # Using append_taxon_id will give nice seqnames_taxonids needed for
  # njtree species_tree matching
  my %sa_params = ($self->param('use_genomedb_id')) ?	('-APPEND_GENOMEDB_ID', 1) : ('-APPEND_TAXON_ID', 1);

  my $sa = $tree->get_SimpleAlign
    (
     -id_type => 'MEMBER',
     %sa_params,
    );
  $sa->set_displayname_flat(1);

    # Aln in fasta format (if needed)
    if ($sa->length() >= 5000) {
        # For FastTree it is better to give the alignment in fasta format
        my $aln_fasta = $file_root . ".fa";
        open my $aln_fasta_fh, ">" , $aln_fasta or $self->throw("Error opening $aln_fasta for writing");
        for my $aln_seq ($sa->each_seq) {
            my $header = $aln_seq->display_id;
            my $seq = $aln_seq->seq;
            print $aln_fasta_fh ">$header\n$seq\n";
        }
        close($aln_fasta_fh);
        $self->param('aln_fasta',$aln_fasta);
    }


  # Phylip header
  print OUTSEQ $sa->no_sequences, " ", $sa->length, "\n";

  $self->param('tag_residue_count', $sa->no_sequences * $sa->length);
  # Phylip body
  my $count = 0;
  foreach my $aln_seq ($sa->each_seq) {
    print OUTSEQ $aln_seq->display_id, " ";
    my $seq = $aln_seq->seq;

    # Here we do a trick for all Ns sequences by changing the first
    # nucleotide to an A so that raxml can at least do the tree for
    # the rest of the sequences, instead of giving an error
    if ($seq =~ /N+/) { $seq =~ s/^N/A/; }

    print OUTSEQ "$seq\n";
    $count++;
    print STDERR "sequences $count\n" if ($count % 50 == 0);
  }
  close OUTSEQ;

  return $aln_file;
}

sub _store_newick_into_nc_tree_tag_string {
  my $self = shift;
  my $tag = shift;
  my $newick_file = shift;

  my $newick = '';
  print("load from file $newick_file\n") if($self->debug);
  open (FH, $newick_file) or $self->throw("Couldnt open newick file [$newick_file]");
  while(<FH>) {
    chomp $_;
    $newick .= $_;
  }
  close(FH);
  $newick =~ s/(\d+\.\d{4})\d+/$1/g; # We round up to only 4 digits

  $self->param('nc_tree')->tree->store_tag($tag, $newick);
  if (defined($self->param('model'))) {
    my $bootstrap_tag = $self->param('model') . "_bootstrap_num";
    $self->param('nc_tree')->tree->store_tag($bootstrap_tag, $self->param('bootstrap_num'));
  }
}

sub _load_and_dump_alignment {
    my ($self) = @_;

    my $root_id = $self->param('nc_tree_id');
    my $alignment_id = $self->param('alignment_id');
    my $file_root = $self->worker_temp_directory. "nctree_" . $root_id;
    my $aln_file = $file_root . ".aln";
    open my $outaln, ">", "$aln_file" or $self->throw("Error opening $aln_file for writing");

#    my $sql_load_alignment = "SELECT member_id, aligned_sequence FROM aligned_sequence WHERE alignment_id = $alignment_id";
    my $sql_load_alignment = "SELECT member_id, aligned_sequence FROM aligned_sequence WHERE alignment_id = ?";
    my $sth_load_alignment = $self->dbc->prepare($sql_load_alignment);
    print STDERR "SELECT member_id, aligned_sequence FROM aligned_sequence WHERE alignment_id = $alignment_id\n" if ($self->debug);
    $sth_load_alignment->execute($alignment_id);
    my $all_aln_seq_hashref = $sth_load_alignment->fetchall_arrayref({});

    my $seqLen = length($all_aln_seq_hashref->[0]->{aligned_sequence});
    if ($seqLen >= 5000) {
        # It is better to feed FastTree with aln in fasta format
        my $aln_fasta = $file_root . ".fa";
        open my $aln_fasta_fh, ">", $aln_fasta or $self->throw("Error opening $aln_fasta for writing");
        for my $row_hashref (@$all_aln_seq_hashref) {
            my $mem_id = $row_hashref->{member_id};
            my $member = $self->compara_dba->get_NCTreeAdaptor->fetch_AlignedMember_by_member_id_root_id($mem_id);
            my $taxid = $member->taxon_id();
            my $aln_seq = $row_hashref->{aligned_sequence};
            print $aln_fasta_fh ">" . $mem_id . "_" . $taxid . "\n";
            print $aln_fasta_fh $aln_seq . "\n";
        }
        close ($aln_fasta_fh);
        $self->param('aln_fasta', $aln_fasta);
    }

    print $outaln scalar(@$all_aln_seq_hashref), " ", $seqLen, "\n";
    for my $row_hashref (@$all_aln_seq_hashref) {
        my $mem_id = $row_hashref->{member_id};
        my $member = $self->compara_dba->get_NCTreeAdaptor->fetch_AlignedMember_by_member_id_root_id($mem_id);
        my $taxid = $member->taxon_id();
        my $aln_seq = $row_hashref->{aligned_sequence};
        print STDERR "$mem_id\t" if ($self->debug);
        print STDERR substr($aln_seq, 0, 60), "...\n" if ($self->debug);
        $aln_seq =~ s/^N/A/;  # To avoid RAxML failure
        print $outaln $mem_id, "_", $taxid, " ", $aln_seq, "\n";
    }
    close($outaln);

    $self->param('input_aln', $aln_file);
    return;
}


1;

