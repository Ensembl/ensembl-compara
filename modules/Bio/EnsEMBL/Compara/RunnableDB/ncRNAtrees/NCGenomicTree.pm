package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCGenomicTree;

use strict;
use warnings;
use Data::Dumper;
use Time::HiRes qw/time/;
use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my ($self) = @_;
    my $nc_tree_id = $self->param('nc_tree_id');
    my $nc_tree = $self->compara_dba->get_NCTreeAdaptor->fetch_node_by_node_id($nc_tree_id);
    $self->param('nc_tree', $nc_tree);
    my $alignment_id = $self->param('alignment_id');
    print STDERR "ALN INPUT ID: " . $alignment_id . "\n" if ($self->debug);
    my $aln_file = $self->_load_and_dump_alignment();
    if (! defined $aln_file) {
        $self->throw("I can not dump the alignment in $alignment_id");
    }
    $self->param('aln_input',$aln_file);
    $self->throw("need a method") unless (defined $self->param('method'));
    $self->throw("need an alignment output file to build the tree") unless (defined $self->param('aln_input'));
    $self->throw("tree with id $nc_tree_id is undefined") unless (defined $nc_tree);

}

sub run {
    my ($self) = @_;
    $self->run_ncgenomic_tree($self->param('method'));
}

sub write_output {
    my ($self) = @_;
}

sub run_ncgenomic_tree {
    my ($self, $method) = @_;
    my $cluster = $self->param('nc_tree');
    my $nc_tree_id = $self->param('nc_tree_id');
    my $input_aln = $self->param('aln_input');
    print STDERR "INPUT ALN: $input_aln\n";
    die "$input_aln doesn't exist" unless (-e $input_aln);
    if ($method eq "phyml" && (scalar $cluster->get_all_leaves < 4)) {
        $self->input_job->incomplete(0);
        die ("tree cluster $nc_tree_id has ".(scalar $cluster->get_all_leaves)." proteins - can not build a phyml tree\n");
    }
    my $njtree_phyml_executable = $self->param('treebest_exe') || "/nfs/users/nfs_a/avilella/src/treesoft/trunk/treebest/treebest";
    # Defining a species_tree
    # Option 1 is species_tree_string in nc_tree_tag, which then doesn't require tracking files around
    # Option 2 is species_tree_file which should still work for compatibility
    my $sql1 = "select value from nc_tree_tag where tag = 'species_tree_string'";
    my $sth1 = $self->dbc->prepare($sql1);
    $sth1->execute;
    my $species_tree_string = $sth1->fetchrow_hashref;
    $sth1->finish;
    my $eval_species_tree;
    eval {
        $eval_species_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($species_tree_string->{value});
        my @leaves = @{$eval_species_tree->get_all_leaves};
    };
    $self->throw("Can't find species tree\n") if ($@);
    my $spfilename = $self->worker_temp_directory . "spec_tax.nh";
    open my $sptree_fh, ">$spfilename" or die $!;
    print $sptree_fh $species_tree_string->{value};
    close $sptree_fh;
    my $newick_file = $input_aln . ".treebest.$method.nh";
    $self->param('newick_file', $newick_file);
    my $treebest_err_file = $self->worker_temp_directory . "treebest.err";
    my $cmd = $njtree_phyml_executable;
    $cmd .= " $method";
    $cmd .= " -Snf " if ($method eq 'phyml');
    $cmd .= " -s " if ($method eq 'nj');
    $cmd .= $spfilename;
    $cmd .= " " . $input_aln;
    $cmd .= " 2> ". $treebest_err_file;
    $cmd .= " > " . $newick_file;

    print STDERR "$cmd\n" if ($self->debug);
    my $worker_temp_directory = $self->worker_temp_directory;
    $DB::single=1; $DB::single && 1; # To avoid warnings about $DB::single used only once
    $self->compara_dba->dbc->disconnect_when_inactive(0);

    ## FIXME! -- I am not sure that $cmd will return errors. It will never dataflows!
    unless (system("cd $worker_temp_directory; $cmd") == 0) {
        print STDERR "We have a problem running treebest -- Inspecting $treebest_err_file\n";
        open my $treebest_err_fh, "<", $treebest_err_file or die $!;
        while (<$treebest_err_fh>) {
            chomp;
            if (/low memory/) {
                $self->dataflow_output_id (
                                           {
                                            'nc_tree_id' => $self->param('nc_tree_id'),
                                            'method' => $self->param('method'),
                                            'alignement_id' => $self->param('alignment_id'),
                                           }, -1
                                          );
                $self->input_job->incomplete(0);
                die "error running treebest $method: $!\n -- Signaling MEMLIMIT";
            }
        }
        print "$cmd\n";
        $self->throw("error running treebest $method: $!\n");
    }
    $self->compara_dba->dbc->disconnect_when_inactive(1);
    $self->store_newick_into_protein_tree_tag_string($method)
}

sub store_newick_into_protein_tree_tag_string {
    my ($self, $method) = @_;

  my $newick_file =  $self->param('newick_file');
  my $newick = '';
  print STDERR "load from file $newick_file\n" if($self->debug);
  open (FH, $newick_file) or $self->throw("Couldnt open newick file [$newick_file]");
  while(<FH>) {
    chomp $_;
    $newick .= $_;
  }
  close(FH);
  $newick =~ s/(\d+\.\d{4})\d+/$1/g; # We round up to only 4 digits
  return if ($newick eq '_null_;');
  my $tag = "pg_IT_" . $method;
  $self->param('nc_tree')->store_tag($tag, $newick);
}

sub _load_and_dump_alignment {
    my ($self) = @_;

    my $root_id = $self->param('nc_tree_id');
    my $alignment_id = $self->param('alignment_id');
    my $file_root = $self->worker_temp_directory. "nctree_" . $root_id;
    my $aln_file = $file_root . ".aln";
    open my $outaln, ">", "$aln_file" or $self->throw("Error opening $aln_file for writing");

    my $sql_load_alignment = "SELECT member_id, aligned_sequence FROM aligned_sequence WHERE alignment_id = ?";
    my $sth_load_alignment = $self->dbc->prepare($sql_load_alignment);
    print STDERR "SELECT member_id, aligned_sequence FROM aligned_sequence WHERE alignment_id = $alignment_id\n" if ($self->debug);
    $sth_load_alignment->execute($alignment_id);
    my $all_aln_seq_hashref = $sth_load_alignment->fetchall_arrayref({});

    for my $row_hashref (@$all_aln_seq_hashref) {
        my $mem_id = $row_hashref->{member_id};
        my $member = $self->compara_dba->get_NCTreeAdaptor->fetch_AlignedMember_by_member_id_root_id($mem_id);
        my $taxid = $member->taxon_id();
        my $aln_seq = $row_hashref->{aligned_sequence};
        $aln_seq =~ s/^N/A/;  # To avoid RAxML failure
        print $outaln ">" . $mem_id. "_" . $taxid . "\n" . $aln_seq . "\n";
    }
    close($outaln);

    return $aln_file;
}

1;
