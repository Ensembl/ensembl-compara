=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GenericRunnable

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take a gene tree as input,
run any arbitrary command on it, and store the result back.

The Runnable requires
 - gene_tree_id: the root_id of the gene tree on which to run the command
 - cmd: the command to run

The command has to be defined using the following parameters:
 - #gene_tree_file#: current gene tree
 - #species_tree_file#: the reference species tree
 - #alignment_file#: the alignment file
 - #tag:XYZ#: the value of the tag "XYZ" of the gene-tree

By default, the standard output of the job is captured and is expected
to be a Newick/NHX tree. This is overriden by any of the parameters:
 - output_file: file to read instead of the standard output
 - read_tags: if 1, the output is parsed as lines of "key: value" that
              are stored as tags. Otherwise, it is assumed to be a tree

Other parameters:
 - check_split_genes: whether we want to group the split genes in fake gene entries
 - minimum_genes: minimum number of genes on which to run the command
 - maximum_genes: maximum number of genes on which to run the command
 - runtime_tree_tag: gene-tree tag to store the runtime of the command
 - cdna: 1 if the alignment file contains the CDS sequences (otherwise: the protein sequences)
 - remove_columns: 1 if the alignment has to be filtered (assumes that there is a "removed_columns" tag)
 - ryo_species_tree: Roll-Your-Own format string for the species-tree
 - species_tree_label: the label od the species-tree that should be used for this command
 - input_clusterset_id: alternative clusterset_id for the input gene tree
 - run_treebest_sdi: do we have to pass the output tree through "treebest sdi"
 - reroot_with_sdi: should "treebest sdi" also reroot the tree
 - output_clusterset_id: alternative clusterset_id to store the result gene tree

Branch events:
 - #1: autoflow on success
 - #2: cluster too small
 - #3: cluster too large

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GenericRunnable;

use strict;
use warnings;

use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::RunCommand', 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree', 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::TreeBest');


sub param_defaults {
    return {
        'cdna'              => 0,
        'remove_columns'    => 0,
        'check_split_genes' => 1,
        'read_tags'         => 0,
        'do_transactions'   => 1,
        'ryo_species_tree'  => '%{o}',

        'species_tree_label'        => undef,
        'input_clusterset_id'       => undef,
        'output_clusterset_id'      => undef,

        'minimum_genes'     => 0,
        'maximum_genes'     => 1e9,

        'run_treebest_sdi'  => 0,
        'reroot_with_sdi'   => 0,
    };
}


sub fetch_input {
    my $self = shift @_;

    if (defined $self->param('escape_branch') and $self->input_job->retry_count >= $self->input_job->analysis->max_retry_count) {
        $self->dataflow_output_id($self->input_id, $self->param('escape_branch'));
        $self->input_job->incomplete(0);
        die sprintf("The job is being tried for the %dth time: escaping to branch #%d\n", $self->input_job->retry_count, $self->param('escape_branch'));
    }

    $self->param('tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor);

    my $gene_tree_id     = $self->param_required('gene_tree_id');
    my $gene_tree        = $self->param('tree_adaptor')->fetch_by_dbID( $gene_tree_id ) or die "Could not fetch gene_tree with gene_tree_id='$gene_tree_id'";
    $self->param('default_gene_tree', $gene_tree);

    die "Cannot read tags from TreeBest's output: set run_treebest_sdi or read_tags to 0" if $self->param('run_treebest_sdi') and $self->param('read_tags');

    if ($self->param('input_clusterset_id') and $self->param('input_clusterset_id') ne 'default') {
        print STDERR "getting the tree '".$self->param('input_clusterset_id')."'\n";
        my $other_trees = $self->param('tree_adaptor')->fetch_all_linked_trees($gene_tree);
        my ($selected_tree) = grep {$_->clusterset_id eq $self->param('input_clusterset_id')} @$other_trees;
        die sprintf('Cannot find a "%s" tree for tree_id=%d', $self->param('input_clusterset_id'), $self->param('gene_tree_id')) unless $selected_tree;
        $gene_tree = $selected_tree;
    }
    $self->param('gene_tree', $gene_tree);

    $self->param('mlss_id',   $gene_tree->method_link_species_set_id);

    $gene_tree->preload();
    $gene_tree->print_tree(10) if($self->debug);

    # default parameters
    $self->param('split_genes',   {}  );
    $self->param('cmd_output',  undef );
}


sub run {
    my $self = shift;
    $self->cleanup_worker_temp_directory;
    $self->run_generic_command;
}


sub write_output {
    my $self = shift;

    my $cmd_output = $self->param('cmd_output');
    return unless $cmd_output;

    my $target_tree = $self->param('gene_tree');

    if ($self->param('read_tags')) {
        $self->store_tags($target_tree, $self->get_tags($cmd_output));

    } else {
        if ($self->param('output_clusterset_id') and $self->param('output_clusterset_id') ne 'default') {
            $target_tree = $self->store_alternative_tree($cmd_output, $self->param('output_clusterset_id'), $target_tree);
        } else {
            $target_tree = $self->param('default_gene_tree');
            $self->parse_newick_into_tree($cmd_output, $target_tree);
            $self->store_genetree($target_tree, []);
        }

        # check that the tree is binary
        foreach my $node (@{$target_tree->get_all_nodes}) {
            next if $node->is_leaf;
            die "The tree should be binary\n" if scalar(@{$node->children}) != 2;
        }
    }
    $target_tree->store_tag($self->param('runtime_tree_tag'), $self->param('runtime_msec')) if $self->input_job->param_exists('runtime_tree_tag');
    $target_tree->release_tree();
}


sub post_cleanup {
    my $self = shift;

    $self->param('gene_tree')->release_tree() if $self->param('gene_tree');
    $self->SUPER::post_cleanup if $self->can("SUPER::post_cleanup");
}


##########################################
#
# internal methods
#
##########################################


sub run_generic_command {
    my $self = shift;

    my $gene_tree = $self->param('gene_tree');
    my $newick;

    # The order is very important !
    # First, we need to load the species tree to attach the stn_ids tags to the genome_dbs / the gene-tree leaves
    # Then, we have to dump the alignment (that does the detection of split genes)
    # And finally, we're good to dump the tree

    $self->param('species_tree_file', $self->get_species_tree_file());

    # This is needed for check_split_genes and parse_filtered_align
    foreach my $member (@{$gene_tree->get_all_Members}) {
        $member->{_tmp_name} = sprintf('%d_%d', $member->seq_member_id, $member->genome_db->species_tree_node_id);
    }

    my $input_aln = $self->dumpTreeMultipleAlignmentToWorkdir($gene_tree) || die "Could not fetch alignment for ($gene_tree)";
    $self->param('alignment_file', $input_aln);

    $self->param('gene_tree_file', $self->get_gene_tree_file($gene_tree));

    warn sprintf("Number of elements: %d leaves, %d split genes\n", scalar(@{$gene_tree->get_all_Members}), scalar(keys %{$self->param('split_genes')}));

    my $number_actual_genes = scalar(@{$gene_tree->get_all_Members}) - scalar(keys %{$self->param('split_genes')});

    if ($number_actual_genes < $self->param('minimum_genes')) {
        $self->dataflow_output_id($self->input_id, 2);
        $self->input_job->incomplete(0);
        die "There are only $number_actual_genes genes in this tree. Not running the command.\n";
    }
    if ($number_actual_genes > $self->param('maximum_genes')) {
        $self->dataflow_output_id($self->input_id, 3);
        $self->input_job->incomplete(0);
        die "There are too many genes ($number_actual_genes) in this tree. Not running the command.\n";
    }

    foreach my $tag ($gene_tree->get_all_tags()) {
        $self->param("tag:$tag", $gene_tree->get_value_for_tag($tag));
    }

    my $cmd = sprintf('cd %s; %s', $self->worker_temp_directory, $self->param_required('cmd'));
    my $run_cmd = $self->run_command($cmd);
    if ($run_cmd->exit_code) {
        if ($run_cmd->err =~ /Exception in thread ".*" java.lang.OutOfMemoryError: Java heap space at/) {
            $self->dataflow_output_id( $self->input_id, -1 );
            $self->input_job->incomplete(0);
            die "Java heap space is out of memory.\n";
        }
        die sprintf("'%s' resulted in an error code=%d\nstderr is: %s\nstdout is: %s\n", $run_cmd->cmd, $run_cmd->exit_code, $run_cmd->err, $run_cmd->out);
    }
    $self->param('runtime_msec', $run_cmd->runtime_msec);

    $self->param('output_file', $self->worker_temp_directory.'/'.$self->param('output_file')) if $self->param('output_file');
    my $output = $self->param('output_file') ? $self->_slurp($self->param('output_file')) : $run_cmd->out;
    print "Re-root with sdi=".$self->param('reroot_with_sdi')."\n" if($self->debug);
    $output = $self->run_treebest_sdi($output, $self->param('reroot_with_sdi')) if $self->param('run_treebest_sdi');
    $self->param('cmd_output', $output);
}


sub get_gene_tree_file {
    my ($self, $gene_tree) = @_;

    my $split_genes = $self->param('split_genes');
    # horrible hack: we replace taxon_id with species_tree_node_id
    foreach my $leaf (@{$gene_tree->root->get_all_leaves}) {
        $leaf->taxon_id($leaf->genome_db->species_tree_node_id);

        if (exists $split_genes->{$leaf->{_tmp_name}}) {
            # Remove the split genes and all the parents that are left without members
            my $node = $leaf->parent;
            $leaf->disavow_parent();
            while ($node->get_child_count() == 0) {
                my $parent = $node->parent;
                $node->disavow_parent();
                $node = $parent;
            }
        }
    }
    $gene_tree->{'_root'} = $gene_tree->root->minimize_tree if keys %$split_genes;

    my $gene_tree_file = sprintf('gene_tree_%d.nhx', $gene_tree->root_id);
    open( my $genetree, '>', $self->worker_temp_directory."/".$gene_tree_file) or die "Could not open '$gene_tree_file' for writing : $!";
    print $genetree $gene_tree->newick_format('ryo','%{-m}%{"_"-x}:%{d}');
    close $genetree;

    return $gene_tree_file;
}

sub _load_species_tree_string_from_db {
    my ($self) = @_;
    my $species_tree = $self->param('gene_tree')->species_tree($self->param('species_tree_label') || 'default');
    $species_tree->attach_to_genome_dbs();
    $self->param('species_tree_string', $species_tree->root->newick_format('ryo', $self->param('ryo_species_tree')));
}



sub get_tags {
    my ($self, $output) = @_;

    my %tags = ();
    foreach my $line (split /\n/, $output) {
        chomp $line;
        if ($line =~ /([^:]*):(.*)/) {
            $tags{$1} = $2;
        }
    }
    return \%tags;
}


sub store_tags {
    my ($self, $gene_tree, $tags) = @_;
    while ( my ($tag, $value) = each %$tags ) {
        $gene_tree->store_tag($tag, $value);
    }
}




1;
