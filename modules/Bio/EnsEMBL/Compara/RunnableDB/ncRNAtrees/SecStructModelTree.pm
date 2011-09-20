=head1 LICENSE

  Copyright (c) 1999-2010 The European Bioinformatics Institute and
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

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::SecStructModelTree

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable
  +- Bio::EnsEMBL::Hive::Process

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::SecStructModelTree;

use strict;
use Time::HiRes qw(time);                          # Needed *
use Bio::EnsEMBL::Compara::Graph::NewickParser;    # Needed *
use IPC::Open3;
use File::Spec;
use Symbol qw/gensym/;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input

   Title   :   fetch_input
   Usage   :   $self->fetch_input
   Function:   Fetches input data from the database
   Returns :   none
   Args    :   none

=cut

sub fetch_input {
    my $self = shift @_;

    $self->input_job->transient_error(0);
    my $nc_tree_id = $self->param('nc_tree_id') or $self->throw("An 'nc_tree_id' is mandatory");  # Better to have a nc_tree instead?
    $self->input_job->transient_error(1);

    my $nc_tree = $self->compara_dba->get_NCTreeAdaptor->fetch_node_by_node_id($nc_tree_id) or die "Could not fetch nc_tree with id=$nc_tree_id\n";
    $self->param('nc_tree',$nc_tree);

    if(my $input_aln = $self->_dumpMultipleAlignmentStructToWorkdir($nc_tree) ) {
        $self->param('input_aln', $input_aln);
    } else {
        die "An input_aln is mandatory";
    }
}

sub run {

    my ($self) = @_;

    my $model = $self->param('model') or die "A model is mandatory";
    my $nc_tree = $self->param('nc_tree');
    my $aln_file = $self->param('input_aln');
    my $struct_file = $self->param('struct_aln') or die "An struct_aln is mandatory";
    my $bootstrap_num = $self->param('bootstrap_num') or die "A boostrap_num is mandatory";
    my $root_id = $nc_tree->node_id;

    my $raxml_tag = $root_id . "." . $self->worker->process_id . ".raxml";

    my $raxml_exe = $self->param('raxml_exe')
        or die "'raxml_exe' is an obligatory parameter";

    die "Cannot execute '$raxml_exe'" unless(-x $raxml_exe);

    my $tag = 'ss_IT_' . $model;
    my $sql1 = "select value from nc_tree_tag where node_id=$root_id and tag='$tag'";
    my $sth1 = $self->dbc->prepare($sql1);
    $sth1->execute;
    my $raxml_tree_string = $sth1->fetchrow_hashref;
    $sth1->finish;
    if ($raxml_tree_string->{value}) {
        my $eval_tree;
        # Checks the tree string can be parsed successfully
        eval {
            $eval_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($raxml_tree_string->{value});
        };
        if (defined($eval_tree) and !$@) {
            # The secondary structure RAxML tree for this model has been obtained already and the tree can be parsed successfully.
            return;  # We have ended with this model
        }
    }

    # /software/ensembl/compara/raxml/RAxML-7.2.2/raxmlHPC-SSE3
    # -m GTRGAMMA -s nctree_20327.aln -S nctree_20327.struct -A S7D -n nctree_20327.raxml
    my $worker_temp_directory = $self->worker_temp_directory;
    my $cmd = $raxml_exe;
    $cmd .= " -T 2";
    $cmd .= " -m GTRGAMMA";
    $cmd .= " -s $aln_file";
    $cmd .= " -S $struct_file";
    $cmd .= " -A $model";
    $cmd .= " -n $raxml_tag.$model";
    $cmd .= " -N ".$bootstrap_num if (defined $bootstrap_num);
#    $cmd .= " 2> $raxml_err_file";
#     my $error_file = $worker_temp_directory."/RAxML_bestTree.$raxml_tag.$model.err";
#     $cmd .= ">& $error_file";


    $self->compara_dba->dbc->disconnect_when_inactive(1);
    my $starttime = time()*1000;
    print STDERR "$cmd\n" if ($self->debug);
#    unless(system("cd $worker_temp_directory; $cmd") == 0) {
    # Assuming that if RAxML runs without problems, no stderr output will be generated.
    # We are reading STDERR to get if RAxML fails and the error reported.
    # If the error is an assertion error. We report, but no error is raised to msg table.
    open (NULL, ">", File::Spec->devnull);
    my $pid = open3(gensym, ">&NULL", \*PH, "cd $worker_temp_directory; $cmd");
    my $err_msg = "";
    while (<PH>) {
        $err_msg .= $_;
    }
    if ($err_msg ne "") {
        print STDERR "We have a problem running RAxML -- Inspecting error file\n";
        if ($err_msg =~ /Assertion(.+)failed/) {
            my $assertion_failed = $1;
            $self->input_job->incomplete(0);
            die "Assertion failed for RAxML: $assertion_failed\n";
        } else {
            $self->throw("error running raxml\ncd $worker_temp_directory; $cmd\n$err_msg\n");
        }
    }
    my $runtime_msec = int(time()*1000-$starttime);
    $self->compara_dba->dbc->disconnect_when_inactive(0);

    my $raxml_output = $self->worker_temp_directory . "RAxML_bestTree.$raxml_tag.$model";
    $self->_store_newick_into_protein_tree_tag_string($tag,$raxml_output);
    my $model_runtime = "${model}_runtime_msec";
    $nc_tree->store_tag($model_runtime,$runtime_msec);

    #Unlink run files
    my $temp_regexp = $worker_temp_directory."*$raxml_tag.$model.RUN.*";
    system ("rm -f $temp_regexp");
    return 1;
}

sub write_output {
    my $self= shift @_;
}


##########################################
#
# internal methods
#
##########################################

sub _store_newick_into_protein_tree_tag_string {

  my $self = shift;
  my $tag = shift;
  my $newick_file = shift;

  my $newick = '';
#  print("load from file $newick_file\n") if($self->debug);
  open (FH, $newick_file) or $self->throw("Couldnt open newick file [$newick_file]");
  while(<FH>) {
    chomp $_;
    $newick .= $_;
  }
  close(FH);
  $newick =~ s/(\d+\.\d{4})\d+/$1/g; # We round up to only 4 digits

  $self->param('nc_tree')->store_tag($tag, $newick);
  if (defined($self->param('model'))) {
    my $bootstrap_tag = $self->param('model') . "_bootstrap_num";
    $self->param('nc_tree')->store_tag($bootstrap_tag, $self->param('bootstrap_num'));
  }
}

sub _dumpMultipleAlignmentStructToWorkdir {
    my $self = shift;
    my $tree = shift;

    my $leafcount = scalar(@{$tree->get_all_leaves});
    if($leafcount<4) {
        my $node_id = $tree->node_id;
        $self->input_job->incomplete(0);
        die ("tree cluster $node_id has <4 proteins - can not build a raxml tree\n");
    }

    my $file_root = $self->worker_temp_directory. "nctree_". $tree->node_id;
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

  # Phylip header
    print OUTSEQ $sa->no_sequences, " ", $sa->length, "\n";
    # Phylip body
    my $count = 0;
    foreach my $aln_seq ($sa->each_seq) {
        print OUTSEQ $aln_seq->display_id, "\n";
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

    my $struct_string = $self->param('nc_tree')->get_tagvalue('ss_cons');
    # Allowed Characters are "( ) < > [ ] { } " and "."
    $struct_string =~ s/[^\(^\)^\<^\>^\[^\]^\{^\}^\.]/\./g;
    my $struct_file = $file_root . ".struct";
    if ($struct_string =~ /^\.+$/) {
#        $self->input_job->transient_error(0);
        $self->input_job->incomplete(0);
        die "struct string is $struct_string\n";
    } else {
        open(STRUCT, ">$struct_file")
            or $self->throw("Error opening $struct_file for write");
        print STRUCT "$struct_string\n";
        close STRUCT;
    }
    $self->param('input_aln', $aln_file);
    $self->param('struct_aln', $struct_file);
    return $aln_file;
}

1;
