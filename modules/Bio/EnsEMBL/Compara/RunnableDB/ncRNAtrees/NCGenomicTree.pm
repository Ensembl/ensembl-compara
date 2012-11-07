package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCGenomicTree;

use strict;
use warnings;
use Data::Dumper;
use Time::HiRes qw/time/;
use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable', 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::TreeBest');

sub fetch_input {
    my ($self) = @_;
    my $nc_tree_id = $self->param('gene_tree_id');
    my $nc_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($nc_tree_id);
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


sub run_ncgenomic_tree {
    my ($self, $method) = @_;
    my $cluster = $self->param('nc_tree');
    my $nc_tree_id = $self->param('gene_tree_id');
    my $input_aln = $self->param('aln_input');
    print STDERR "INPUT ALN: $input_aln\n";
    die "$input_aln doesn't exist" unless (-e $input_aln);
    if ($method eq "phyml" && (scalar $cluster->get_all_leaves < 4)) {
        $self->input_job->incomplete(0);
        die ("tree cluster $nc_tree_id has ".(scalar $cluster->get_all_leaves)." proteins - can not build a phyml tree\n");
    }

    my $newick;
    if ($method eq 'nj') {
        $newick = $self->run_treebest_nj($input_aln);
    } elsif ($method eq 'phyml') {
        $newick = $self->run_treebest_phyml($input_aln);
    } else {
        die "unknown method: $method\n";
    }

    $newick =~ s/(\d+\.\d{4})\d+/$1/g; # We round up to only 4 digits
    return if ($newick =~ /^_null_;/);
    my $tag = "pg_it_" . $method;
    $cluster->store_tag($tag, $newick);
}

sub _load_and_dump_alignment {
    my ($self) = @_;

    my $root_id = $self->param('gene_tree_id');
    my $alignment_id = $self->param('alignment_id');
    my $file_root = $self->worker_temp_directory. "nctree_" . $root_id;
    my $aln_file = $file_root . ".aln";
    open my $outaln, ">", "$aln_file" or $self->throw("Error opening $aln_file for writing");

    my $sql_load_alignment = "SELECT member_id, aligned_sequence FROM aligned_sequence WHERE alignment_id = ?";
    my $sth_load_alignment = $self->compara_dba->dbc->prepare($sql_load_alignment);
    print STDERR "SELECT member_id, aligned_sequence FROM aligned_sequence WHERE alignment_id = $alignment_id\n" if ($self->debug);
    $sth_load_alignment->execute($alignment_id);
    my $all_aln_seq_hashref = $sth_load_alignment->fetchall_arrayref({});

    for my $row_hashref (@$all_aln_seq_hashref) {
        my $mem_id = $row_hashref->{member_id};
        my $member = $self->compara_dba->get_MemberAdaptor->fetch_by_dbID($mem_id);
        my $taxid = $member->taxon_id();
        my $aln_seq = $row_hashref->{aligned_sequence};
        $aln_seq =~ s/^N/A/;  # To avoid RAxML failure
        print $outaln ">" . $mem_id. "_" . $taxid . "\n" . $aln_seq . "\n";
    }
    close($outaln);

    return $aln_file;
}

1;
