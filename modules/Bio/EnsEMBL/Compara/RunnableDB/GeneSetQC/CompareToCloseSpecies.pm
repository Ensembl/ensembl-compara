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

Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::CompareToCloseSpecies

=head1 DESCRIPTION

This runnable compares a given species against others (the first of the
latter is called "reference").  It splits a gene-tree into sub-trees that
are specific to the clade defines by these species.  It then reports the
genes that each species has, and the branch length of the tested species vs
the reference species.

=head1 SYNOPSIS

standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::CompareToCloseSpecies \
 -compara_db mysql://server/mm14_protein_trees_82

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneSetQC::CompareToCloseSpecies;

use strict;
use warnings;

use List::Util qw(sum);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'gene_tree_id'  => undef,
    };
}


sub fetch_input {
    my $self = shift @_;

    my $genome_db_id = $self->param_required('genome_db_id');
    my $cmp_genome_db_ids = $self->param_required('cmp_genome_db_ids');

    my $tree_mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_all_by_method_link_type('PROTEIN_TREES')->[0];
    my $species_tree = $tree_mlss->species_tree;
    
    my $lca_node = $species_tree->find_lca_of_GenomeDBs( [$genome_db_id, @$cmp_genome_db_ids] );
    my %subtree_nodes = map {$_->node_id => 1} @{$lca_node->get_all_nodes};
    $self->param('subtree_nodes', \%subtree_nodes);
    my %genome_db_ids = map {$_->genome_db_id => 1} @{$lca_node->get_all_leaves};
    $self->param('genome_db_ids', \%genome_db_ids);

    if ($self->debug) {
        warn "Last common ancestor: ", $lca_node->node_name, "\n";
        warn scalar(keys %subtree_nodes), " nodes / ", scalar(keys %genome_db_ids), " species in total under the LCA\n";
        warn "Using GenomeDBs", join(", ", @$cmp_genome_db_ids), " for comparison\n";
    }
}

sub run {
    my $self = shift @_;
    my $alltrees;
    if ($self->param('gene_tree_id')) {
        $alltrees = [$self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($self->param('gene_tree_id'))]; 
    } else {
        $alltrees = $self->compara_dba->get_GeneTreeAdaptor->fetch_all(-clusterset_id => 'default', -tree_type => 'tree', -member_type => 'protein');
    }

    warn scalar(@$alltrees), " trees to process\n" if $self->debug;
    my $n = 1;
    foreach my $tree (@$alltrees) {
        warn $n++, " root_id=", $tree->root_id, "\n" if $self->debug;
        my $s = $self->_process($tree);
        $tree->release_tree();
    }
       
}

sub _process {
    my ($self, $tree) = @_;
    my $subtrees = $self->_rec_get_sub_trees($tree->root);
    foreach my $subtree (@{$subtrees}) {
        $self->analyze_number_copies($subtree);
    }
}


sub _rec_get_sub_trees {
    my ($self, $node) = @_;
    if ($node->is_leaf) {
        if ($self->param('genome_db_ids')->{$node->genome_db_id}) {
            return [$node];
        } else {
            return [];
        }
    } elsif ($self->param('subtree_nodes')->{$node->_species_tree_node_id}) {
        return [$node];
    } else {
        my @res = ();
        push @res, @{$self->_rec_get_sub_trees($_)} for @{$node->children};
        return \@res;
    }
}

sub analyze_number_copies {
    my ($self, $node) = @_;

    my $genome_db_id = $self->param('genome_db_id');
    my @relevant_gdb_ids = ($self->param('genome_db_id'), @{$self->param('cmp_genome_db_ids')});
    my @other_gdb_ids = @{$self->param('cmp_genome_db_ids')};
    my $ref_gdb_id = shift @other_gdb_ids;

    my %genes_per_species = (map {$_ => []} @relevant_gdb_ids);
    my %sample_gene = ();
    foreach my $leaf (@{$node->get_all_leaves}) {
        push @{$genes_per_species{$leaf->genome_db_id}}, $leaf->stable_id;
        $sample_gene{$leaf->genome_db_id} = $leaf;
    }
    my %counts = map {$_ => scalar(@{$genes_per_species{$_}})} @relevant_gdb_ids;
    #warn Dumper \%genes_per_species;
    my $n_other_species = scalar(grep {$counts{$_}} @other_gdb_ids);
    my $n_genes_in_other_species = sum(map {$counts{$_}} @other_gdb_ids);
    my %strs = map {$_ => join(',', @{$genes_per_species{$_}})} @relevant_gdb_ids;

    printf("GENE_COUNT\t%d\t%d\t%d\t%d\t%s\t%s\t%s\n",
        $counts{$genome_db_id}, $counts{$ref_gdb_id}, $n_genes_in_other_species, $n_other_species,
        $strs{$genome_db_id} || 'NULL', $strs{$ref_gdb_id} || 'NULL',
        join(',', grep {$_} (map {$strs{$_}} @other_gdb_ids)) || 'NULL',
    );

    printf("BRANCH_LENGTH\t%s\t%f\t%s\t%f\n", $sample_gene{$genome_db_id}->stable_id, $sample_gene{$genome_db_id}->distance_to_parent, $sample_gene{$ref_gdb_id}->stable_id, $sample_gene{$ref_gdb_id}->distance_to_parent) if $counts{$ref_gdb_id} == 1 and $counts{$genome_db_id} == 1;

}


1;
