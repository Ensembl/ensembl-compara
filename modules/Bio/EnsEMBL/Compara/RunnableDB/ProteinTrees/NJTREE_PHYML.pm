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

use Bio::EnsEMBL::Compara::AlignedMemberSet;
use Bio::EnsEMBL::Compara::Utils::Cigars;

use Time::HiRes qw(time gettimeofday tv_interval);
use Data::Dumper;
use File::Glob;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::TreeBest', 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree');


sub param_defaults {
    return {
            'cdna'              => 1,   # always use cdna for njtree_phyml
            'check_split_genes' => 1,
            'store_tree_support'    => 1,
            'intermediate_prefix'   => 'interm',
            'do_transactions'   => 1,
            'extra_lk_scale'    => undef,
            'treebest_stderr'   => undef,
    };
}


sub fetch_input {
    my $self = shift @_;

    $self->param('tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor);

    my $gene_tree_id     = $self->param_required('gene_tree_id');
    my $gene_tree        = $self->param('tree_adaptor')->fetch_by_dbID( $gene_tree_id )
                                        or die "Could not fetch gene_tree with gene_tree_id='$gene_tree_id'";
    $gene_tree->preload();
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

    my @ref_support = qw(phyml_nt nj_ds phyml_aa nj_dn nj_mm);

    my $treebest_stored_tree = $self->param('gene_tree');
    if ($self->param('output_clusterset_id') and ($self->param('output_clusterset_id') ne 'default')) {
        $treebest_stored_tree = $self->store_alternative_tree($self->param('treebest_stdout'), $self->param('output_clusterset_id'), $self->param('gene_tree'), \@ref_support);
    } else {
        #parse the tree into the datastucture:
        if ($self->parse_newick_into_tree( $self->param('treebest_stdout'), $self->param('gene_tree') )) {
            $self->store_genetree($self->param('gene_tree'), \@ref_support);
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
        foreach my $filename (glob(sprintf('%s/%s.*.nhx', $self->worker_temp_directory, $self->param('intermediate_prefix')) )) {
            $filename =~ /\.([^\.]*)\.nhx$/;
            my $clusterset_id = $1;
            next if $clusterset_id eq 'mmerge';
            next if $clusterset_id eq 'phyml';
            print STDERR "Found file $filename for clusterset $clusterset_id\n";
            my $newtree = $self->store_alternative_tree($self->_slurp($filename), $clusterset_id, $self->param('gene_tree'));
            push @dataflow, $newtree->root_id;
        }
    }

    if ($self->param('store_filtered_align')) {
        my $alnfile_filtered = sprintf('%s/filtalign.fa', $self->worker_temp_directory);
        if (-e $alnfile_filtered) {
            $self->param('default_gene_tree', $self->param('gene_tree'));
            my $removed_columns = $self->parse_filtered_align($self->param('input_aln'), $alnfile_filtered, 0, 1);
            print Dumper $removed_columns if ( $self->debug() );
            $self->param('gene_tree')->store_tag('removed_columns', $removed_columns);
        }
    }

    if (defined $self->param('output_dir')) {
        system(sprintf('cd %s; zip -r -9 %s/%d.zip', $self->worker_temp_directory, $self->param('output_dir'), $self->param('gene_tree_id')));
    }

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
    
    foreach my $member (@{$gene_tree->get_all_Members}) {
        $member->{_tmp_name} = sprintf('%d_%d', $member->seq_member_id, $member->genome_db->species_tree_node_id);
    }

    if (scalar(@{$gene_tree->get_all_Members}) == 2) {

        warn "Number of elements: 2 leaves, N/A split genes\n";
        my @goodgenes = map {$_->{_tmp_name}} @{$gene_tree->get_all_Members};
        $newick = $self->run_treebest_sdi_genepair(@goodgenes);
    
    } else {

        my $input_aln = $self->dumpTreeMultipleAlignmentToWorkdir($gene_tree);
        $self->param('input_aln', $input_aln);
        
        warn sprintf("Number of elements: %d leaves, %d split genes\n", scalar(@{$gene_tree->get_all_Members}), scalar(keys %{$self->param('split_genes')}));

        my $genes_for_treebest = scalar(@{$gene_tree->get_all_Members}) - scalar(keys %{$self->param('split_genes')});
        $self->throw("Cannot build a tree with $genes_for_treebest genes (exclud. split genes)") if $genes_for_treebest < 2;

        if ($genes_for_treebest == 2) {

            my @goodgenes = grep {not exists $self->param('split_genes')->{$_}} (map {$_->{_tmp_name}} @{$gene_tree->get_all_Members});
            $newick = $self->run_treebest_sdi_genepair(@goodgenes);

        } else {

            my $extra_lk_scale = $self->param('extra_lk_scale');
            if ((defined $extra_lk_scale) and ($extra_lk_scale < 0)) {
                $extra_lk_scale = -$extra_lk_scale * $gene_tree->get_value_for_tag('aln_num_residues') / $gene_tree->get_value_for_tag('gene_count');
            }
            $newick = $self->run_treebest_best($input_aln, $extra_lk_scale);
        }
    }

    $self->param('treebest_stdout', $newick);
    $self->param('treebest_runtime', time()*1000-$starttime);
}


1;
