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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::NJTREE_PHYML

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take ProteinTree as input
This must already have a multiple alignment run on it. It uses that alignment
as input into the NJTREE PHYML program which then generates a phylogenetic tree

input_id/parameters format eg: "{'gene_tree_id'=>1234}"
    gene_tree_id : use 'id' to fetch a cluster from the ProteinTree

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::NJTREE_PHYML;

use strict;

use Time::HiRes qw(time gettimeofday tv_interval);
use Data::Dumper;
use File::Glob;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree', 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::TreeBest');


sub param_defaults {
    return {
            'cdna'              => 1,   # always use cdna for njtree_phyml
		'check_split_genes' => 1,
            'store_tree_support'    => 1,
            'intermediate_prefix'   => 'interm',
    };
}


sub fetch_input {
    my $self = shift @_;

    $self->param('tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor);

    my $protein_tree_id     = $self->param('gene_tree_id') or die "'gene_tree_id' is an obligatory parameter";
    my $protein_tree        = $self->param('tree_adaptor')->fetch_by_dbID( $protein_tree_id )
                                        or die "Could not fetch protein_tree with gene_tree_id='$protein_tree_id'";
    $protein_tree->preload();
    $protein_tree->print_tree(10) if($self->debug);

    $self->param('protein_tree', $protein_tree);

}


sub run {
    my $self = shift;
    $self->cleanup_worker_temp_directory;
    $self->run_njtree_phyml;
}


sub write_output {
    my $self = shift;

    $self->store_genetree($self->param('protein_tree'));

    if ($self->param('store_intermediate_trees')) {
        foreach my $filename (glob(sprintf('%s/%s.*.nhx', $self->worker_temp_directory, $self->param('intermediate_prefix')) )) {
            $filename =~ /\.([^\.]*)\.nhx$/;
            my $clusterset_id = $1;
            next if $clusterset_id eq 'mmerge';
            next if $clusterset_id eq 'phyml';
            $self->store_intermediate_tree($filename, $clusterset_id);
        }
    }

    if ($self->param('store_filtered_align')) {
        my $filename = sprintf('%s/filtalign.fa', $self->worker_temp_directory);
        $self->store_filtered_align($filename) if (-e $filename);
    }

    if (defined $self->param('output_dir')) {
        system(sprintf('cd %s; zip -r -9 %s/%d.zip', $self->worker_temp_directory, $self->param('output_dir'), $self->param('gene_tree_id')));
    }
}

sub post_cleanup {
  my $self = shift;

  if(my $protein_tree = $self->param('protein_tree')) {
    printf("NJTREE_PHYML::post_cleanup  releasing tree\n") if($self->debug);
    $protein_tree->release_tree;
    $self->param('protein_tree', undef);
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

    my $protein_tree = $self->param('protein_tree');
    my $newick;

    my $starttime = time()*1000;
    

    if (scalar(@{$protein_tree->root->get_all_leaves}) == 2) {

        warn "Number of elements: 2 leaves, N/A split genes\n";
        my @goodgenes = map {sprintf("%d_%d", $_->member_id, $self->param('use_genomedb_id') ? $_->genome_db_id : $_->taxon_id)} @{$protein_tree->root->get_all_leaves};
        $newick = $self->run_treebest_sdi_genepair(@goodgenes);
    
    } else {

        my $input_aln = $self->dumpTreeMultipleAlignmentToWorkdir ( $protein_tree->root );
        
        warn sprintf("Number of elements: %d leaves, %d split genes\n", scalar(@{$protein_tree->root->get_all_leaves}), scalar(keys %{$self->param('split_genes')}));

        my $genes_for_treebest = scalar(@{$protein_tree->root->get_all_leaves}) - scalar(keys %{$self->param('split_genes')});
        $self->throw("Cannot build a tree with $genes_for_treebest genes (exclud. split genes)") if $genes_for_treebest < 2;

        if ($genes_for_treebest == 2) {

            my @goodgenes = grep {not exists $self->param('split_genes')->{$_}} (map {sprintf("%d_%d", $_->member_id, $self->param('use_genomedb_id') ? $_->genome_db_id : $_->taxon_id)} @{$protein_tree->root->get_all_leaves});
            $newick = $self->run_treebest_sdi_genepair(@goodgenes);

        } else {

            $newick = $self->run_treebest_best($input_aln);
        }
    }

    #parse the tree into the datastucture:
    unless ($self->parse_newick_into_tree( $newick, $self->param('protein_tree') )) {
        $self->input_job->transient_error(0);
        $self->throw('The filtered alignment is empty. Cannot build a tree');
    }

    $protein_tree->store_tag('NJTREE_PHYML_runtime_msec', time()*1000-$starttime);
}


sub store_intermediate_tree {
    my ($self, $filename, $clusterset_id) = @_;
    print STDERR "Found file $filename for clusterset $clusterset_id\n";
    my $clusterset = $self->param('tree_adaptor')->fetch_all(-tree_type => 'clusterset', -clusterset_id => $clusterset_id)->[0];
    if (not defined $clusterset) {
        $self->warning("The clusterset_id '$clusterset_id' is not defined. Cannot store the alternative tree");
        return;
    }
    my $newtree = $self->fetch_or_create_other_tree($clusterset, $self->param('protein_tree'));
    $self->parse_newick_into_tree($self->_slurp($filename), $newtree);
    $self->store_genetree($newtree);
    $self->dataflow_output_id({'gene_tree_id' => $newtree->root_id}, 2);
    $newtree->release_tree;
}


sub store_filtered_align {
    my ($self, $filename) = @_;
    print STDERR "Found filtered alignment: $filename\n";
    my $alignio = Bio::AlignIO->new(-file => $filename, -format => 'fasta');
    my $aln = $alignio->next_aln or die "Bio::AlignIO could not get next_aln() from file '$filename'";

    #place all members in a hash on their member name
    my %member_hash;
    foreach my $member (@{$self->param('protein_tree')->get_all_Members}) {
        $member_hash{$member->member_id} = $member;
    }

    # Storing the alignment as tags
    $self->param('protein_tree')->store_tag('filtered_alignment_length', $aln->length()/3);
    foreach my $seq ($aln->each_seq) {
        $seq->display_id =~ /(\d+)\_\d+/;
        $member_hash{$1}->store_tag('filtered_alignment', $seq->seq());
    }
}


1;
