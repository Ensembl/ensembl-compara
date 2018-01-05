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
 - #tag_XYZ#: the value of the tag "XYZ" of the gene-tree

By default, the standard output of the job is captured and is expected
to be a Newick/NHX tree. This is overriden by any of the parameters:
 - output_file: file to read instead of the standard output
 - read_tags: if 1, the runnable will call a get_tags() method that must be
              implemented in the derived class and return a hash of tag/values
              to be stored on the gene-tree.

Other parameters:
 - check_split_genes: whether we want to group the split genes in fake gene entries
 - minimum_genes: minimum number of genes on which to run the command (generates a #2 event if the condition is not met)
 - maximum_genes: maximum number of genes on which to run the command (generates a #3 event if the condition is not met)
 - cmd_max_runtime: maximum runtime (in seconds) of the command (generates a #-2 event if the command takes too long)
 - runtime_tree_tag: gene-tree tag to store the runtime of the command
 - cdna: 1 if the alignment file contains the CDS sequences (otherwise: the protein sequences)
 - remove_columns: 1 if the alignment has to be filtered (assumes that there is a "removed_columns" tag)
 - ryo_species_tree: Roll-Your-Own format string for the species-tree
 - ryo_gene_tree: Roll-Your-Own format string for the gene-tree (NB: taxon_ids are in fact species_tree_node_ids !)
 - species_tree_label: the label od the species-tree that should be used for this command
 - input_clusterset_id: alternative clusterset_id for the input gene tree
 - run_treebest_sdi: do we have to pass the output tree through "treebest sdi"
 - reroot_with_sdi: should "treebest sdi" also reroot the tree
 - output_clusterset_id: alternative clusterset_id to store the result gene tree
 - aln_format: (default: "fasta"). In which format the alignment should be dumped
 - aln_clusterset_id: clusterset_id of the tree that provides the alignment. Default is undef, which means the tree that is used for input in the runnable

Branch events:
 - #1: autoflow on success
 - #2: cluster too small
 - #3: cluster too large
 - #-1: memory limit (JAVA programs)
 - #-2: runtime limit (using the "cmd_max_runtime" parameter)

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GenericRunnable;

use strict;
use warnings;

use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::TreeBest');


sub param_defaults {
    return {
        'cdna'              => 0,
        'aln_format'        => 'fasta',
        'map_long_seq_names'=> undef,
        'remove_columns'    => 0,
        'check_split_genes' => 1,
        'read_tags'         => 0,
        'ryo_species_tree'  => '%{o}',
        'ryo_gene_tree'     => '%{-m}%{"_"-x}:%{d}',

        'species_tree_label'        => undef,
        'input_clusterset_id'       => undef,
        'output_clusterset_id'      => undef,

        'minimum_genes'     => 0,
        'maximum_genes'     => 1e9,
        'cmd_max_runtime'   => undef,
        'do_hcs'            => 1,

        'run_treebest_sdi'  => 0,
        'reroot_with_sdi'   => 0,
    };
}


sub fetch_input {
    my $self = shift @_;

    if (defined $self->param('escape_branch') and $self->input_job->retry_count >= ($self->input_job->analysis->max_retry_count // $self->db->hive_pipeline->hive_default_max_retry_count)) {
        $self->dataflow_output_id(undef, $self->param('escape_branch'));
        $self->input_job->autoflow(0);
        $self->complete_early(sprintf("The job is being tried for the %dth time: escaping to branch #%d\n", $self->input_job->retry_count, $self->param('escape_branch')));
    }

    $self->param('tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor);

    my $gene_tree_id     = $self->param_required('gene_tree_id');
    my $gene_tree        = $self->param('tree_adaptor')->fetch_by_dbID( $gene_tree_id ) or die "Could not fetch gene_tree with gene_tree_id='$gene_tree_id'";
    $self->param('default_gene_tree', $gene_tree);

    die "Cannot read tags from TreeBest's output: set run_treebest_sdi or read_tags to 0" if $self->param('run_treebest_sdi') and $self->param('read_tags');

    if ($self->param('input_clusterset_id') and $self->param('input_clusterset_id') ne 'default') {
        print STDERR "getting the tree '".$self->param('input_clusterset_id')."'\n";
        my $selected_tree = $gene_tree->alternative_trees->{$self->param('input_clusterset_id')};

        #In case we are using a non default input_clusterset_id, we need to use the same gene_tree_id label.
        #If we dont set this to the alternative root_id, it will cause a discrepancy between the file names.
        #   some will have the ref_root_id and others will have the alternative root_id 
        #   but we should store the ref_tree to be used by the healthchecks
        $self->param('ref_gene_tree_id', $self->param('gene_tree_id'));
        $self->param('gene_tree_id', $selected_tree->root->node_id);

        die sprintf('Cannot find a "%s" tree for tree_id=%d', $self->param('input_clusterset_id'), $self->param('gene_tree_id')) unless $selected_tree;
        $selected_tree->add_tag('removed_columns', $gene_tree->get_value_for_tag('removed_columns')) if $gene_tree->has_tag('removed_columns');
        $gene_tree = $selected_tree;
    }
    $self->param('gene_tree', $gene_tree);

    $self->param('mlss_id',   $gene_tree->method_link_species_set_id);

    $gene_tree->print_tree(10) if($self->debug);

    # default parameters
    $self->param('split_genes',   {}  );
    $self->param('hidden_genes',   []  );
    $self->param('newick_output',  undef );
}


sub run {
    my $self = shift;
    $self->cleanup_worker_temp_directory;
    $self->run_generic_command;
}


sub write_output {
    my $self = shift;

    if ($self->param('read_tags')) {
        my $target_tree = $self->param('default_gene_tree');
        if ($self->param('output_clusterset_id') and $self->param('output_clusterset_id') ne 'default') {
            $target_tree = $self->param('default_gene_tree')->alternative_trees->{$self->param('output_clusterset_id')};
            die sprintf('Cannot find a "%s" tree for tree_id=%d', $self->param('output_clusterset_id'), $self->param('gene_tree_id')) unless $target_tree;
        }
        my $tags = $self->get_tags();
        while ( my ($tag, $value) = each %$tags ) {
            $target_tree->store_tag($tag, $value);
        }

    } else {

        my $target_tree;
        delete $self->param('default_gene_tree')->{'_member_array'};   # To make sure we use the freshest data

        if ($self->param('output_clusterset_id') and $self->param('output_clusterset_id') ne 'default') {
            #We need to parse_newick_into_tree to be able to unmerge the split_genes.
            print "Using: " . $self->param('output_clusterset_id') . " clusterset\n" if($self->debug) ;

            $self->parse_newick_into_tree( $self->param('newick_output'), $self->param('default_gene_tree'), [] );
            $target_tree = $self->store_alternative_tree($self->param('newick_output'), $self->param('output_clusterset_id'), $self->param('default_gene_tree'), [], 1) || die "Could not store ". $self->param('output_clusterset_id') . " tree.\n";
        } else {
            print "Using: default clusterset\n" if($self->debug);
            $target_tree = $self->param('default_gene_tree');
            $self->parse_newick_into_tree($self->param('newick_output'), $target_tree, []);
            $self->store_genetree($target_tree);
        }

        # check that the tree is binary
        foreach my $node (@{$target_tree->get_all_nodes}) {
            next if $node->is_leaf;
            die "The tree should be binary" if scalar(@{$node->children}) != 2;
        }
    }
    $self->param('default_gene_tree')->store_tag($self->param('runtime_tree_tag'), $self->param('runtime_msec')) if $self->param('runtime_tree_tag');
}

sub post_healthcheck {
    my $self = shift;
    $self->call_hcs_all_trees() if $self->param('do_hcs');
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
    # Then, we have to run the detection of split genes as it modifies the alignment and the tree *in place*

    $self->param('species_tree_file', $self->get_species_tree_file());
    $self->merge_split_genes($gene_tree) if $self->param('check_split_genes');

    # The alignment can come from yet another tree
    my $aln_tree;
    if ($self->param('aln_clusterset_id')) {
        if ($self->param('aln_clusterset_id') eq 'default') {
            $aln_tree = $self->param('default_gene_tree');
        } else {
            $aln_tree = $self->param('default_gene_tree')->alternative_trees->{$self->param('aln_clusterset_id')};
            die sprintf('Cannot find a "%s" tree for tree_id=%d', $self->param('aln_clusterset_id'), $self->param('gene_tree_id')) unless $aln_tree;
        }
    } else {
        $aln_tree = $gene_tree;
    }

    if (($self->param('aln_format') eq 'phylip') && (!defined($self->param('map_long_seq_names'))) ){
        $self->param('map_long_seq_names', 1);
    }

    my $map_long_seq_names;
    if ($self->param('map_long_seq_names')){
        $map_long_seq_names = {};
    }

    my $input_aln = $self->dumpTreeMultipleAlignmentToWorkdir($aln_tree, $self->param('aln_format'), {-APPEND_SPECIES_TREE_NODE_ID => $self->param('species_tree')->get_genome_db_id_2_node_hash}, $map_long_seq_names) || die "Could not fetch alignment for ($aln_tree)";
    $self->param('alignment_file', $input_aln);
    $self->param('gene_tree_file', $self->get_gene_tree_file($gene_tree->root,$map_long_seq_names));

    my $number_actual_genes = scalar(@{$gene_tree->get_all_leaves});
    if ($number_actual_genes < $self->param('minimum_genes')) {
        $self->dataflow_output_id(undef, 2);
        $self->input_job->autoflow(0);
        $self->complete_early("There are only $number_actual_genes genes in this tree. Not running the command.\n");
    }
    if ($number_actual_genes > $self->param('maximum_genes')) {
        $self->dataflow_output_id(undef, 3);
        $self->input_job->autoflow(0);
        $self->complete_early("There are too many genes ($number_actual_genes) in this tree. Not running the command.\n");
    }

    foreach my $tag ($gene_tree->get_all_tags()) {
        $self->param("tag_$tag", $gene_tree->get_value_for_tag($tag));
    }

    my $cmd = sprintf('cd %s; %s', $self->worker_temp_directory, $self->param_required('cmd'));
    my $run_cmd = $self->run_command($cmd, { timeout => $self->param('cmd_max_runtime') } );
    if ($run_cmd->exit_code) {
        if ($run_cmd->exit_code == -2) {
            $self->dataflow_output_id(undef, -2);
            $self->input_job->autoflow(0);
            $self->complete_early(sprintf("The command is taking more than %d seconds to complete .\n", $self->param('cmd_max_runtime')));
        } elsif ($run_cmd->err =~ /Exception in thread ".*" java.lang.OutOfMemoryError: Java heap space at/) {
            $self->dataflow_output_id(undef, -1);
            $self->input_job->autoflow(0);
            $self->complete_early("Java heap space is out of memory.\n");
        }
        $self->throw( sprintf( "'%s' resulted in an error code=%d\nstderr is: %s\nstdout is %s", $run_cmd->cmd, $run_cmd->exit_code, $run_cmd->err, $run_cmd->out) );
    }
    $self->param('runtime_msec', $run_cmd->runtime_msec);
    $self->param('cmd_out',      $run_cmd->out);

    $self->param('output_file', $self->worker_temp_directory.'/'.$self->param('output_file')) if $self->param('output_file');

    if ($self->param('binarize')){
        print "Binarizing tree is active\n" if($self->debug);

        # 1 - parse_newick into genetree-structure
        my $newick_multifurcated = $self->_slurp($self->param('output_file'));
        my $multifurcated_tree_root = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick_multifurcated, "Bio::EnsEMBL::Compara::GeneTreeNode");

        #List of multifurcations given a tree.
        #In order to avoid changing parts of the tree that are not in the multifurcations, we have local MRCAs.
        #e.g.:
        #   multifurcations[0] = (child_1,child2,child3)
        #   multifurcations[1] = (child_7,child8,child9)
        #------------------------------------------------
        my $multifurcations = $multifurcated_tree_root->find_multifurcations;

        #IMPORTANT:
        #----------------------------------------------------------------------------------------------------------------------------
        # Binarization methods have not been tested with nested multifurcations. At this point we only have "leaves" multifurcations.
        #----------------------------------------------------------------------------------------------------------------------------

        #If there are no multifurcations in this array it means that the tree is already binary
        #So no need to keep going
        if (scalar(@{$multifurcations}) > 0) {

            #fetch species tree
            my $species_tree = $self->param('species_tree');

            #------------------
            # MRCA binarization
            #------------------
            print "multifurcated_tree_root before MRCA binarization:\n" if ($self->debug);
            $multifurcated_tree_root->print_tree(10) if ($self->debug);

            # 2 - binarize (MRCA) that structure
            $multifurcated_tree_root->binarize_flat_tree_with_species_tree($species_tree, $multifurcations);
            $multifurcated_tree_root->minimize_tree();

            print "multifurcated_tree_root after MRCA binarization:\n" if ($self->debug);
            $multifurcated_tree_root->print_tree(10) if ($self->debug);

            #After trying to do a MRCA binarization we check again for any left multifurcations to be resolved randomly.
            foreach my $node (@{$multifurcated_tree_root->get_all_nodes}) {
                next if $node->is_leaf;

                #-------------------------------
                # Random binarization, per node.
                #-------------------------------
                if (scalar(@{$node->children}) > 2) {
                    print "Tree is still not binary\n" if($self->debug);

                    # 3 - binarize (random) 
                    print "Performing random binarization on node: $node\n";
                    $node->random_binarize_node();

                    #Note the different ryo.
                    #At this point there is no information on taxon_id. If we try -x it will fail
                    #print "MULTI:".$multifurcated_tree_root->newick_format('ryo', '%{-n}:%{d}')."\n" if($self->debug > 1);
                    #print "BIN:".$binTree_root->newick_format('ryo', '%{-n}:%{d}')."\n" if($self->debug > 1);

                    $multifurcated_tree_root->minimize_tree();
                    $multifurcated_tree_root->print_tree(10) if($self->debug);
                }
            }
        }

        # 4 - print structure to input_file
        # ovewrite the output_file with the binirized tree
        my $newick = $multifurcated_tree_root->newick_format('ryo', '%{-n}:%{d}');
        $self->_spurt($self->param('output_file'), $newick);
    }

    unless ($self->param('read_tags')) {
        my $output = $self->param('output_file') ? $self->_slurp($self->param('output_file')) : $run_cmd->out;
        if ($self->param('run_treebest_sdi')) {
            print "Re-rooting the tree with 'treebest sdi'\n" if($self->debug);

            if (defined $map_long_seq_names){
                #we need to re-map to the lond indentidiers
                foreach my $tmp_seq ( keys( %$map_long_seq_names ) ) {
                    my $fix_seq = $map_long_seq_names->{$tmp_seq}{'seq'};
                    my $fix_suf = $map_long_seq_names->{$tmp_seq}{'suf'};

                    my $fix_seq_name = "$fix_seq\_$fix_suf";

                    #Replace only whole words:
                    $output =~ s/\b$tmp_seq\b/$fix_seq_name/;
                }
            }

            $output = $self->run_treebest_sdi($output, $self->param('reroot_with_sdi'));
        }
		unless($output){
            sleep 60;
            die "The Newick output is empty\n";
		}
        $self->param('newick_output', $output);
    }
}


sub get_gene_tree_file {
    my $self                    = shift;
    my $gene_tree_root          = shift;
    my $map_long_seq_names      = shift;

    # horrible hack: we replace taxon_id with species_tree_node_id
    my $gdbid2stn = $self->param('species_tree')->get_genome_db_id_2_node_hash();
    foreach my $leaf (@{$gene_tree_root->get_all_leaves}) {
        $leaf->taxon_id($gdbid2stn->{$leaf->genome_db_id}->node_id);
    }

    my $gene_tree_file = sprintf('gene_tree_%d.nhx', $gene_tree_root->node_id);

    my $newick = $gene_tree_root->newick_format('ryo', $self->param('ryo_gene_tree'));

    if ($map_long_seq_names){
        #we need to re-map to the small indentidiers
        foreach my $tmp_seq ( keys( %{$map_long_seq_names} ) ) {
            my $fix_seq = $map_long_seq_names->{$tmp_seq}->{'seq'};
            my $fix_suf = $map_long_seq_names->{$tmp_seq}->{'suf'};

            my $fix_seq_name = "$fix_seq\_$fix_suf";

            #Replace only whole words:
            $newick =~ s/\b$fix_seq_name\b/$tmp_seq/;
        }
    }

    return $self->_write_temp_tree_file($gene_tree_file, $newick);
}

sub _load_species_tree_string_from_db {
    my ($self) = @_;
    my $species_tree = $self->param('gene_tree')->method_link_species_set->species_tree($self->param('species_tree_label') || 'default');
    $self->param('species_tree', $species_tree);
    return $species_tree->root->newick_format('ryo', $self->param('ryo_species_tree'));
}



sub get_tags {
    die "get_tags() must be implemented by the derived module\n";
}


1;
