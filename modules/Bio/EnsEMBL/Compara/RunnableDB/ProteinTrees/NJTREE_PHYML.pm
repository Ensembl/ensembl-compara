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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::NJTREE_PHYML

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take ProteinTree as input
This must already have a multiple alignment run on it. It uses that alignment
as input into the NJTREE PHYML program which then generates a phylogenetic tree

input_id/parameters format eg: "{'gene_tree_id'=>1234}"
    gene_tree_id : use 'id' to fetch a cluster from the ProteinTree

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::NJTREE_PHYML;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::AlignedMemberSet;
use Bio::EnsEMBL::Compara::Utils::Cigars;
use Bio::EnsEMBL::Compara::Utils::Preloader;

use Time::HiRes qw(time gettimeofday tv_interval);
use Data::Dumper;
use File::Glob;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::TreeBest');


sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
            'cdna'              => 1,   # always use cdna for njtree_phyml
            'check_split_genes' => 1,
            'store_tree_support'    => 1,
            'intermediate_prefix'   => 'interm',
            'extra_lk_scale'    => undef,
            'treebest_stderr'   => undef,
            'output_dir'        => undef,
            # To please StoreTree (parameters usually found in GenericRunnable)
            'read_tags'         => 0,

    };
}



sub fetch_input {
    my $self = shift @_;

    $self->param('tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor);

    my $gene_tree_id     = $self->param_required('gene_tree_id');
    my $gene_tree        = $self->param('tree_adaptor')->fetch_by_dbID( $gene_tree_id )
                                        or die "Could not fetch gene_tree with gene_tree_id='$gene_tree_id'";
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences($self->compara_dba->get_SequenceAdaptor, undef, $gene_tree);
    $gene_tree->print_tree(10) if($self->debug);

    $self->param('gene_tree', $gene_tree);
    $self->_load_species_tree_string_from_db();
}


sub run {
    my $self = shift;
    $self->cleanup_worker_temp_directory;
    $self->run_njtree_phyml;
}


sub write_output {
    my $self = shift;

    my @dataflow = ();

    my @ref_support = qw(phyml-nt nj-ds phyml-aa nj-dn nj-mm);

    my $treebest_stored_tree = $self->param('gene_tree');
    if ($self->param('output_clusterset_id') and ($self->param('output_clusterset_id') ne 'default')) {
        #We need to parse_newick_into_tree to be able to unmerge the split_genes.
        $self->parse_newick_into_tree( $self->param('treebest_stdout'), $self->param('gene_tree'), \@ref_support );
        $treebest_stored_tree = $self->store_alternative_tree($self->param('treebest_stdout'), $self->param('output_clusterset_id'), $self->param('gene_tree'), \@ref_support, 1);
    } else {
        #parse the tree into the datastucture:
        if ($self->parse_newick_into_tree( $self->param('treebest_stdout'), $self->param('gene_tree'), \@ref_support )) {
            $self->store_genetree($self->param('gene_tree'));
        } else {
            $treebest_stored_tree = undef;
        }
    }

    if (not $treebest_stored_tree) {
        $self->input_job->transient_error(0);
        $self->throw('The filtered alignment is empty. Cannot build a tree');
    } else {
        push @dataflow, $treebest_stored_tree->root_id;
    }

    $self->param('gene_tree')->store_tag('treebest_runtime_msec', $self->param('treebest_runtime'));

    if ($self->param('treebest_stderr')) {
        foreach my $stderr_line (split /\n/, $self->param('treebest_stderr')) {
            if ($stderr_line =~ / ([\w-]*) \(Loglk,LoglkSpec\) = \((.*),(.*)\)$/) {
                $self->param('gene_tree')->store_tag(sprintf('treebest_%s_lk', $1), $2);
                $self->param('gene_tree')->store_tag(sprintf('treebest_%s_lk_spec', $1), $3);
                $self->param('gene_tree')->store_tag(sprintf('treebest_%s_lk_seq', $1), $2-$3);
            }
        }
    }

    if ($self->param('store_intermediate_trees')) {
        my %relevant_clustersets = map {$_ => 1} @ref_support;
        # First need to delete all the leftover nodes and roots
        foreach my $other_tree (@{$self->param('tree_adaptor')->fetch_all_linked_trees($self->param('gene_tree'))}) {
            warn "what about ", $other_tree->clusterset_id;
            next unless $relevant_clustersets{$other_tree->clusterset_id};
            warn "going to delete ", $other_tree->clusterset_id;
            $other_tree->preload();
            $self->param('tree_adaptor')->delete_tree($other_tree);
            $other_tree->release_tree();
        }
        delete $self->param('gene_tree')->{'_member_array'};   # To make sure we use the freshest data
        foreach my $filename (glob(sprintf('%s/%s.%d.*.nhx', $self->worker_temp_directory, $self->param('intermediate_prefix'), $self->param('gene_tree_id')) )) {
            $filename =~ /\.([^\.]*)\.nhx$/;
            my $clusterset_id = $1;
            next unless $relevant_clustersets{$clusterset_id};
            print STDERR "Found file $filename for clusterset $clusterset_id\n";
            my $newtree = $self->store_alternative_tree($self->_slurp($filename), $clusterset_id, $self->param('gene_tree'), [], 1);
            push @dataflow, $newtree->root_id;
        }
    }

    if ($self->param('store_filtered_align')) {
        my $alnfile_filtered = sprintf('%s/filtalign.fa', $self->worker_temp_directory);
        if (-e $alnfile_filtered) {
            $self->param('default_gene_tree', $self->param('gene_tree'));
            # 3rd argument is set because the coordinates are for the CDNA alignments
            my $removed_columns;
            eval {
                $removed_columns = $self->parse_filtered_align($self->param('input_aln'), $alnfile_filtered, 1);
            };
            if ($@) {
                if ($@ =~ /^Could not match alignments at /) {
                    $self->warning($@);
                } else {
                    die $@;
                }
            } else {
                print "TreeBest's filtered alignment: ", Dumper $removed_columns if ( $self->debug() );
                $self->param('gene_tree')->store_tag('removed_columns', $removed_columns);
            }
        }
    }

    if ($self->param('output_dir')) {
        $self->run_command(sprintf('cd %s; zip -r -9 %s/%d.zip', $self->worker_temp_directory, $self->param('output_dir'), $self->param('gene_tree_id')), { die_on_failure => 1 });
    }

    $self->call_hcs_all_trees();

    # Only dataflows at the end, if everything went fine
    foreach my $root_id (@dataflow) {
        $self->dataflow_output_id({'gene_tree_id' => $root_id}, 2);
    }
}

sub post_cleanup {
  my $self = shift;

  if(my $gene_tree = $self->param('gene_tree')) {
    printf("NJTREE_PHYML::post_cleanup  releasing tree\n") if($self->debug);
    $gene_tree->release_tree;
    $self->param('gene_tree', undef);
  }

  $self->SUPER::post_cleanup if $self->can("SUPER::post_cleanup");
}


##########################################
#
# internal methods
#
##########################################


sub run_njtree_phyml {
    my $self = shift;

    my $gene_tree = $self->param('gene_tree');
    my $newick;

    my $starttime = time()*1000;
    
    $self->param('hidden_genes', [] );
    $self->merge_split_genes($gene_tree) if $self->param('check_split_genes');
    my $genes_for_treebest = scalar(@{$gene_tree->get_all_leaves});

    if ($genes_for_treebest < 2) {

        $self->throw("Cannot build a tree with $genes_for_treebest genes");

    } elsif ($genes_for_treebest == 2) {

        warn "2 leaves only, we only need sdi\n";
        my $gdbid2stn = $self->param('species_tree')->get_genome_db_id_2_node_hash();
        my @goodgenes = map { sprintf('%d_%d', $_->seq_member_id, $gdbid2stn->{$_->genome_db_id}->node_id) } @{$gene_tree->get_all_leaves};
        $newick = $self->run_treebest_sdi_genepair(@goodgenes);
    
    } else {

        my $input_aln = $self->dumpTreeMultipleAlignmentToWorkdir($gene_tree, 'fasta', {-APPEND_SPECIES_TREE_NODE_ID => $self->param('species_tree')->get_genome_db_id_2_node_hash});
        $self->param('input_aln', $input_aln);

        my $extra_lk_scale = $self->param('extra_lk_scale');
        if ((defined $extra_lk_scale) and ($extra_lk_scale < 0)) {
            $extra_lk_scale = -$extra_lk_scale * $gene_tree->get_value_for_tag('aln_num_residues') / $gene_tree->get_value_for_tag('gene_count');
        }
        $newick = $self->run_treebest_best($input_aln, $extra_lk_scale);
    }

    $self->param('treebest_stdout', $newick);
    $self->param('treebest_runtime', time()*1000-$starttime);
}


1;
