=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

=cut

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::SecStructModelTree

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable
  +- Bio::EnsEMBL::Hive::Process

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::SecStructModelTree;

use strict;
use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::RunnableDB::RunCommand', 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree');


=head2 fetch_input

   Title   :   fetch_input
   Usage   :   $self->fetch_input
   Function:   Fetches input data from the database
   Returns :   none
   Args    :   none

=cut

sub fetch_input {
    my $self = shift @_;

    my $nc_tree_id = $self->param_required('gene_tree_id');

    my $nc_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($nc_tree_id) or die "Could not fetch nc_tree with id=$nc_tree_id\n";
    $nc_tree->species_tree->attach_to_genome_dbs();
    $self->param('gene_tree',$nc_tree);

    my $alignment_id = $self->param_required('alignment_id');
    print STDERR "ALN INPUT ID: $alignment_id\n" if ($self->debug());

    my $aln = $self->compara_dba->get_GeneAlignAdaptor->fetch_by_dbID($alignment_id);
    print STDERR scalar (@{$nc_tree->get_all_Members}), "\n";
    $nc_tree->alignment($aln);
    if(my $input_aln = $self->_dumpMultipleAlignmentStructToWorkdir($nc_tree) ) {
        $self->param('input_aln', $input_aln);
    } else {
        die "An input_aln is mandatory";
    }
}

sub run {

    my ($self) = @_;

    my $model = $self->param_required('model');
    my $nc_tree = $self->param('gene_tree');
    my $aln_file = $self->param('input_aln');
    my $struct_file = $self->param_required('struct_aln');
    my $bootstrap_num = $self->param_required('bootstrap_num');
    my $root_id = $nc_tree->root_id;

    my $raxml_tag = $root_id . "." . $self->worker->process_id . ".raxml";
    $self->param('raxml_tag', $raxml_tag);

    my $raxml_exe = $self->require_executable('raxml_exe');

    my $tag = 'ss_it_' . $model;
    if ($self->param('gene_tree')->has_tag($tag)) {
        my $eval_tree;
        # Checks the tree string can be parsed successfully
        eval {
            $eval_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($self->param('gene_tree')->get_value_for_tag($tag));
        };
        if (defined($eval_tree) and !$@) {
            # The secondary structure RAxML tree for this model has been obtained already and the tree can be parsed successfully.
            return;  # We have ended with this model
        }
    }

    # /software/ensembl/compara/raxml/RAxML-7.2.2/raxmlHPC-SSE3
    # -m GTRGAMMA -s nctree_20327.aln -S nctree_20327.struct -A S7D -n nctree_20327.raxml
    my $worker_temp_directory = $self->worker_temp_directory;
    my $cores = $self->param('raxml_number_of_cores');
    my $cmd = $raxml_exe;
    $cmd .= " -T $cores";
    $cmd .= " -m GTRGAMMA";
    $cmd .= " -s $aln_file";
    $cmd .= " -S $struct_file";
    $cmd .= " -A $model";
    $cmd .= " -n $raxml_tag.$model";
    $cmd .= " -p12345";
    $cmd .= " -N ".$bootstrap_num if (defined $bootstrap_num);

    my $command = $self->run_command("cd $worker_temp_directory; $cmd");

    # Inspect output
    if ($command->out =~ /(Empirical base frequency for state number \d+ is equal to zero in DNA data partition)/) {
        # This can happen when there is not one of the nucleotides in one of the DNA data partition (RAxML-7.2.8)
        # RAxML will refuse to run this, we can safely skip this model (the rest of the models for this cluster will also fail).
        $self->input_job->autoflow(0);
        $self->complete_early($1);
    }

    # Inspect error
    my $err_msg = $command->err;
    # Assuming that if RAxML runs without problems, no stderr output will be generated.
    # We are reading STDERR to get if RAxML fails and the error reported.
    # If the error is an assertion error. We report, but no error is raised to msg table.
    if ($err_msg) {
        print STDERR "We have a problem running RAxML -- Inspecting error file\n";
        if ($err_msg =~ /Assertion(.+)failed/) {
            $self->input_job->autoflow(0);
            $self->complete_early("Assertion failed for RAxML: $1\n");
        } else {
            $self->throw("error running raxml\ncd $worker_temp_directory; $cmd\n$err_msg\n");
        }
    }

    print STDERR "RAxML runtime_msec: ", $command->runtime_msec, "\n";

    my $raxml_output = $self->worker_temp_directory . "RAxML_bestTree.$raxml_tag.$model";
    $self->_store_newick_into_protein_tree_tag_string($tag,$raxml_output);
    my $model_runtime = "${model}_runtime_msec";
    $nc_tree->store_tag($model_runtime,$command->runtime_msec);

    return 1;
}


sub cleanup {
    my ($self) = @_;
    my $raxml_tag = $self->param('raxml_tag');
    my $model = $self->param('model');
    my $tmp_regexp = $self->worker_temp_directory."*$raxml_tag.$model.RUN.*";
    my $cmd = $self->run_command("rm -f $tmp_regexp");
    $cmd->run();
    if ($cmd->exit_code) {
        $self->throw($cmd->cmd , " gave exit status ", $cmd->exit_code);
    }
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

  print STDERR "load from file $newick_file\n" if($self->debug);
  my $newick = $self->_slurp($newick_file);
  my $newtree = $self->store_alternative_tree($newick, $tag, $self->param('gene_tree'));

  if (defined($self->param('model'))) {
    my $bootstrap_tag = $self->param('model') . "_bootstrap_num";
    $self->param('gene_tree')->store_tag($bootstrap_tag, $self->param('bootstrap_num'));
  }
}

sub _dumpMultipleAlignmentStructToWorkdir {
    my $self = shift;
    my $tree = shift;

    my $leafcount = scalar(@{$tree->get_all_leaves});
    if($leafcount<4) {
        my $node_id = $tree->root_id;
        $self->input_job->autoflow(0);
        $self->complete_early("tree cluster $node_id has <4 proteins - can not build a raxml tree\n");
    }

    my $file_root = $self->worker_temp_directory. "nctree_". $tree->root_id;
    $file_root    =~ s/\/\//\//g;  # converts any // in path to /

    my $aln_file = $file_root . ".aln";
    print STDERR "ALN FILE IS: $aln_file\n" if ($self->debug());

    open(OUTSEQ, ">$aln_file")
        or $self->throw("Error opening $aln_file for write");

    my $sa = $tree->get_SimpleAlign
        (
         -ID_TYPE => 'MEMBER',
         -APPEND_SPECIES_TREE_NODE_ID => 1,
         -keep_gaps => 1,
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

    my $struct_string = $self->param('gene_tree')->get_tagvalue('ss_cons_filtered');
    # Allowed Characters are "( ) < > [ ] { } " and "."
    $struct_string =~ s/[^\(^\)^\<^\>^\[^\]^\{^\}^\.]/\./g;  ## We should have a "clean" structure now?

    my $struct_file = $file_root . ".struct";
    if ($struct_string =~ /^\.+$/) {
        $self->input_job->autoflow(0);
        $self->complete_early("struct string is $struct_string\n");
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
