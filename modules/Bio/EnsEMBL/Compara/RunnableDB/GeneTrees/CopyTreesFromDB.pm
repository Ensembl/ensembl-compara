
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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CopyTreesFromDB

=head1 DESCRIPTION

1) Used to copy all the trees from a previous database.

2) It identifies the genes that have been updated, deleted or added.

3) It disavows all the genes that were flagged by FlagUpdateClusters.pm

4) But it wont add any new genes at this point. New genes will be addeed by mafft/raxml

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CopyTreesFromDB;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree');

sub param_defaults {
    return {};
}

sub fetch_input {
    my $self = shift @_;

    if ( $self->param('reuse_db') ) {

        #Get adaptors
        #----------------------------------------------------------------------------------------------------------------------------
        #get compara_dba adaptor
        $self->param( 'compara_dba', $self->compara_dba );

        #get reuse compara_dba adaptor
        $self->param( 'reuse_compara_dba', Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $self->param('reuse_db') ) );

        print Dumper $self->param('compara_dba')       if ( $self->debug );
        print Dumper $self->param('reuse_compara_dba') if ( $self->debug );

        #get reuse tree adaptor
        $self->param( 'reuse_tree_adaptor', $self->param('reuse_compara_dba')->get_GeneTreeAdaptor );

        #get current tree adaptor
        $self->param( 'current_tree_adaptor', $self->param('compara_dba')->get_GeneTreeAdaptor );

        #----------------------------------------------------------------------------------------------------------------------------

        #Get gene_tree
        #----------------------------------------------------------------------------------------------------------------------------
        $self->param( 'current_gene_tree', $self->param('current_tree_adaptor')->fetch_by_dbID( $self->param('gene_tree_id') ) ) || die "update: Could not get current_gene_tree for stable_id\t" . $self->param('stable_id');
        $self->param('current_gene_tree')->preload();
        $self->param( 'stable_id', $self->param('current_gene_tree')->get_value_for_tag('model_name') );

        #----------------------------------------------------------------------------------------------------------------------------

        #Disavow members' parents
        #----------------------------------------------------------------------------------------------------------------------------
        #Get list of members to be updated
        #my $members_2_b_updated = $self->param('current_gene_tree')->get_value_for_tag('updated_genes_list');

        print "Fetching tree for stable ID/root_id: " . $self->param('stable_id') . "/" . $self->param('gene_tree_id') . "\n" if ( $self->debug );

    } ## end if ( $self->param('reuse_db'...))
    else {
        $self->warning("reuse_db hash has not been set, so cannot reuse");
        $self->param( 'reuse_this', 0 );
        return;
    }
} ## end sub fetch_input

sub write_output {
    my $self = shift;

    #Checks if tree needs to be updated:
    if ( ( $self->param('current_gene_tree')->has_tag('needs_update') ) && ( $self->param('current_gene_tree')->get_value_for_tag('needs_update') == 1 ) ) {

        #Get list of updated genes
        my %members_2_b_updated = map { $_ => 1 } split( /,/, $self->param('current_gene_tree')->get_value_for_tag('updated_genes_list') );
        my %members_2_b_added   = map { $_ => 1 } split( /,/, $self->param('current_gene_tree')->get_value_for_tag('added_genes_list') );
        my %members_2_b_deleted = map { $_ => 1 } split( /,/, $self->param('current_gene_tree')->get_value_for_tag('deleted_genes_list') );

        #Get previous tree

        #Escape branch to deal with the trees that brand new.
        if ( !$self->param('reuse_tree_adaptor')->fetch_by_stable_id( $self->param('stable_id') ) ) {
            $self->dataflow_output_id( $self->input_id, $self->param('branch_for_new_tree') );
            $self->input_job->autoflow(0);
            $self->complete_early("This tree is brand new, it didnt exist before. So it needs to go to the cluster_factory.");
        }

        $self->param( 'reuse_gene_tree', $self->param('reuse_tree_adaptor')->fetch_by_stable_id( $self->param('stable_id') ) ) || die "update: Could not get reuse_gene_tree for stable_id" . $self->param('stable_id');
        $self->param('reuse_gene_tree')->preload();
        $self->param( 'reuse_gene_tree_id', $self->param('reuse_gene_tree')->root_id );

        print "Fetching reuse tree: " . $self->param('stable_id') . "/" . $self->param('reuse_gene_tree_id') . "\n" if ( $self->debug );

        #Preparing to disavow members that are tagged to be deleted.
        #Memebers that are new (added), will not be treated here, they will instead just be added by mafft/raxml
        #my $count_number_of_members = scalar( @{ $self->param('reuse_gene_tree')->get_all_leaves } );
        my $all_leaves              = $self->param('reuse_gene_tree')->get_all_leaves;
        my $all_leaves_current_tree = $self->param('current_gene_tree')->get_all_leaves;

        #We need to map the leaves in the new trees and remove the sequences from the species that are not included in the species set.
        #For that we use the piece of logic bellow:
        my @a;
        my @b;
        foreach my $this_leaf (@$all_leaves) {
            push( @a, $this_leaf->name );
        }
        foreach my $this_leaf (@$all_leaves_current_tree) {
            push( @b, $this_leaf->name );
        }

        my %remaining_leaves = map { ( $_, 1 ) } @b;
        my @deleted = grep { !$remaining_leaves{$_} } @a;
        my %del = map { ( $_, 1 ) } @deleted;

        @members_2_b_updated{ keys %del }               = values %del;
        @members_2_b_updated{ keys %members_2_b_added } = values %members_2_b_added;

        print "Removing: " . scalar( keys %members_2_b_updated ) . " out of: " . scalar( @{$all_leaves} ) . "\n" if ( $self->debug );

        #deleted
        #We need to add the leaves to be deleted here, they are not sequences that were removed from the database, hence they are not flaged by FlagUpdateClusters.
        # These are the leaves that need to be disavowed since the current tree has a different species set, potentially producing trees that have fewer leaves.
        $self->param( 'leaves_2_delete', \%del );
        $self->param('current_gene_tree')->store_tag( 'deleted_leaves_list', join( ",", keys( %{ $self->param('leaves_2_delete') } ) ) );

        #Disavow members' parents
        #loop through the list of members, if any found in the 2_b_deleted list, then need to disavow, if not, just copy over
        foreach my $this_leaf (@$all_leaves) {
            my $seq_id = $this_leaf->name;
            if ( $members_2_b_updated{$seq_id} ) {
                $this_leaf->disavow_parent;

                my $new_root_node = $self->param('reuse_gene_tree')->root->minimize_tree;
                $self->param('reuse_gene_tree')->{'_root'} = $new_root_node;
                $self->param('reuse_gene_tree')->print_tree(10);
            }
        }

        #Copy tree to the DB
        my $target_tree = $self->store_alternative_tree( $self->param('reuse_gene_tree')->newick_format( 'ryo', '%{-m}%{"_"-x}:%{d}' ),
                                                         $self->param('output_clusterset_id'),
                                                         $self->param('current_gene_tree'),
                                                         undef, 1 );

    } ## end if ( ( $self->param('current_gene_tree'...)))
    else {
        #Get previous tree
        print "Just copy over trees\n" if ( $self->debug );

        #Escape branch to deal with the trees that brand new.
        if ( !$self->param('reuse_tree_adaptor')->fetch_by_stable_id( $self->param('stable_id') ) ) {
            $self->dataflow_output_id( $self->input_id, $self->param('branch_for_new_tree') );
            $self->input_job->autoflow(0);
            $self->complete_early("This tree is brand new, it didnt exist before. So it needs to go to the cluster_factory.");
        }

        $self->param( 'reuse_gene_tree', $self->param('reuse_tree_adaptor')->fetch_by_stable_id( $self->param('stable_id') ) ) || die "copy over: Could not get reuse_gene_tree for stable_id:\t" . $self->param('stable_id');
        $self->param('reuse_gene_tree')->preload();
        $self->param( 'reuse_gene_tree_id', $self->param('reuse_gene_tree')->root_id );

        #Copy tree to the DB
        my $target_tree = $self->store_alternative_tree( $self->param('reuse_gene_tree')->newick_format( 'ryo', '%{-m}%{"_"-x}:%{d}' ),
                                                         $self->param('output_clusterset_id'),
                                                         $self->param('current_gene_tree'),
                                                         undef, 1 );
    }
} ## end sub write_output

1;
