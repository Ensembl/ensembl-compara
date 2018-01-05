
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

        #Get adaptors
        #----------------------------------------------------------------------------------------------------------------------------
        #get compara_dba adaptor
        $self->param( 'compara_dba', $self->compara_dba );

        #get reuse compara_dba adaptor
        $self->param( 'reuse_compara_dba', $self->get_cached_compara_dba('reuse_db') );

        #print Dumper $self->param('compara_dba')       if ( $self->debug );
        #print Dumper $self->param('reuse_compara_dba') if ( $self->debug );

        #get reuse tree adaptor
        $self->param( 'reuse_tree_adaptor', $self->param('reuse_compara_dba')->get_GeneTreeAdaptor ) || die "Could not get GeneTreeAdaptor for: reuse_tree_adaptor";

        #get current tree adaptor
        $self->param( 'current_tree_adaptor', $self->param('compara_dba')->get_GeneTreeAdaptor ) || die "Could not get GeneTreeAdaptor for: current_tree_adaptor";

        #----------------------------------------------------------------------------------------------------------------------------

        #Get gene_tree
        #----------------------------------------------------------------------------------------------------------------------------
        $self->param( 'current_gene_tree', $self->param('current_tree_adaptor')->fetch_by_dbID( $self->param('gene_tree_id') ) ) ||
          die "update: Could not get current_gene_tree for stable_id\t" . $self->param('stable_id');
        $self->param( 'stable_id', $self->param('current_gene_tree')->get_value_for_tag('model_name') ) || die "Could not get value_for_tag: model_name";

        #----------------------------------------------------------------------------------------------------------------------------

        #Is tree marked as 'new_build'? If so we need to dataflow it to alignment_entry_point. (Tree has changed too much)
        if ( ( $self->param('current_gene_tree')->has_tag('new_build') ) && ( $self->param('current_gene_tree')->get_value_for_tag('new_build') == 1 ) ) {
            $self->dataflow_output_id( undef, $self->param('branch_for_new_tree') );
            $self->input_job->autoflow(0);
            $self->complete_early("Tree is marked as new_build, hence it shoud go to the cluster_factory.");
        }

        #Does tree need update?
        if ( ( $self->param('current_gene_tree')->has_tag('needs_update') ) && ( $self->param('current_gene_tree')->get_value_for_tag('needs_update') == 1 ) ) {

            print "Tree: " . $self->param('stable_id') . ":" . $self->param('gene_tree_id') . " needs to be updated.\n" if ( $self->debug );

            #If can't fetch previous tree:
            #Escape branch to deal with the trees that brand new (New HMMs).
            if ( !$self->param('reuse_tree_adaptor')->fetch_by_stable_id( $self->param('stable_id') ) ) {
                $self->dataflow_output_id( undef, $self->param('branch_for_new_tree') );
                $self->input_job->autoflow(0);
                $self->complete_early("HMM model is brand new so tree is brand new, it didnt exist before. It needs to go to the cluster_factory.");
            }

            #Get previous tree
            $self->param( 'reuse_gene_tree', $self->param('reuse_tree_adaptor')->fetch_by_stable_id( $self->param('stable_id') ) ) ||
              die "update: Could not get reuse_gene_tree for stable_id" . $self->param('stable_id');
            $self->param( 'all_leaves', $self->param('reuse_gene_tree')->get_all_leaves ) || die "Could not get_all_leaves for: reuse_gene_tree";

            print "Fetching reuse tree: " . $self->param('stable_id') . "/" . $self->param('reuse_gene_tree')->root_id . "\n" if ( $self->debug );

            #Fetch all leaves from the current tree
            $self->param( 'all_leaves_current_tree', $self->param('current_gene_tree')->get_all_leaves ) || die "Could not get_all_leaves for: current_gene_tree";

            my %updated_and_added_members_count;
            $self->param( 'updated_and_added_members_count', \%updated_and_added_members_count );

            #Get list of updated genes

            my $updated_genes_list = $self->param('current_gene_tree')->get_value_for_tag( 'updated_genes_list', '' );
            my %members_2_b_updated = map { $_ => 1 } split( /,/, $updated_genes_list );
            %updated_and_added_members_count = map { $_ => 1 } split( /,/, $updated_genes_list );

            #Get list of genes to add
            my $added_genes_list = $self->param('current_gene_tree')->get_value_for_tag( 'added_genes_list', '' );
            my %members_2_b_added = map { $_ => 1 } split( /,/, $added_genes_list );
            $self->param( 'members_2_b_added', \%members_2_b_added );
            %updated_and_added_members_count = map { $_ => 1 } split( /,/, $added_genes_list );

            #Get list of genes to remove
            my $deleted_genes_list = $self->param('current_gene_tree')->get_value_for_tag( 'deleted_genes_list', '' );
            my %members_2_b_deleted = map { $_ => 1 } split( /,/, $deleted_genes_list );
            $self->param( 'members_2_b_deleted', \%members_2_b_deleted );

            #Load changed members into count
            %updated_and_added_members_count = map { $_ => 1 } split( /,/, $updated_genes_list );
            %updated_and_added_members_count = map { $_ => 1 } split( /,/, $added_genes_list );

            #List of members that were either added, updated or removed
            my %members_2_b_changed;
            $self->param( 'members_2_b_changed', \%members_2_b_changed );

            #List of members that were added or updated
            my %members_2_b_added_updated;
            $self->param( 'members_2_b_added_updated', \%members_2_b_added_updated );

            foreach my $deleted_member ( keys(%members_2_b_deleted) ) {
                $members_2_b_changed{$deleted_member} = 1;
            }
            foreach my $added_member ( keys(%members_2_b_added) ) {
                $members_2_b_changed{$added_member}       = 1;
                $members_2_b_added_updated{$added_member} = 1;
            }
            foreach my $updated_member ( keys(%members_2_b_updated) ) {
                $members_2_b_changed{$updated_member}       = 1;
                $members_2_b_added_updated{$updated_member} = 1;
            }

        } ## end if ( ( $self->param('current_gene_tree'...)))
        elsif ( ( $self->param('current_gene_tree')->has_tag('only_needs_deleting') ) && ( $self->param('current_gene_tree')->get_value_for_tag('only_needs_deleting') == 1 ) ) {

            #List of members that were either added, updated or removed
            my %members_2_b_changed;
            $self->param( 'members_2_b_changed', \%members_2_b_changed );

            #Get list of genes to remove
            my $deleted_genes_list = $self->param('current_gene_tree')->get_value_for_tag( 'deleted_genes_list', '' );
            my %members_2_b_deleted = map { $_ => 1 } split( /,/, $deleted_genes_list );
            $self->param( 'members_2_b_deleted', \%members_2_b_deleted );

            foreach my $deleted_member ( keys(%members_2_b_deleted) ) {
                $members_2_b_changed{$deleted_member} = 1;
            }

        }
} ## end sub fetch_input

sub write_output {
    my $self = shift;

    #Checks if tree needs to be updated:
    if ( ( $self->param('current_gene_tree')->has_tag('needs_update') ) && ( $self->param('current_gene_tree')->get_value_for_tag('needs_update') == 1 ) ) {

        print "disavow 1\n" if ( $self->debug );
        $self->_disavow_unused_members( $self->param('members_2_b_changed') );

        #------------------------------------------------------------------------------------
        #If all leaves are deleted we need to:
        #	Construct newick with leftovers (new members that will be added)
        #		It must follow the pattern seq_member_id _ taxon_id
        #------------------------------------------------------------------------------------
        if ( scalar( keys %{ $self->param('members_2_b_added_updated') } ) >= scalar( @{ $self->param('all_leaves_current_tree') } ) ) {
            print "All leaves were deleted we need to construct newick with leftovers (with new members that will be added).\n" if ( $self->debug );
            my $scrap_newick = "(";
            foreach my $this_leaf ( @{ $self->param('all_leaves_current_tree') } ) {
                $scrap_newick .= $this_leaf->dbID . "_" . $this_leaf->taxon_id . ":0,";
            }
            my $seq_member_adaptor = $self->compara_dba->get_SeqMemberAdaptor || die "Could not get SeqMemberAdaptor";
            my @add;
            foreach my $add ( keys( %{ $self->param('members_2_b_added') } ) ) {
                my $seq_member = $seq_member_adaptor->fetch_by_stable_id($add);
                push( @add, $seq_member->dbID . "_" . $seq_member->taxon_id . ":0" );
            }
            my $addstr = join( ',', @add );
            $scrap_newick .= $addstr . ");";

            print $scrap_newick. "\n" if ( $self->debug );

            my $target_tree = $self->store_alternative_tree( $scrap_newick, $self->param('output_clusterset_id'), $self->param('current_gene_tree'), undef, 1 );

            $self->dataflow_output_id( undef, $self->param('branch_for_wiped_out_trees') );
            $self->input_job->autoflow(0);
            $self->complete_early("All the previous leaves were removed, the tree is now treated as brand new. So it needs to go to the cluster_factory.");
        }
        else {

            #If the number of new genes plus the added genes is >= 20% of the total number of leaves in the reused tree.
            # we should compute the whole alignment/tree again.
            if ( ( scalar( keys %{ $self->param('updated_and_added_members_count') } )/scalar( @{ $self->param('all_leaves_current_tree') } ) ) >=
                 $self->param('update_threshold_trees') ) {
                my $percentage =
                  scalar( keys %{ $self->param('updated_and_added_members_count') } ) . " / " .
                  scalar( @{ $self->param('all_leaves_current_tree') } ) . " = " .
                  scalar( keys %{ $self->param('updated_and_added_members_count') } )/scalar( @{ $self->param('all_leaves_current_tree') } );
                $self->dataflow_output_id( undef, $self->param('branch_for_update_threshold_trees') );
                $self->input_job->autoflow(0);
                $self->complete_early( "The number of new genes plus the added genes is >= 10% ($percentage) of the total number of leaves in the reused tree. So it needs to go to the cluster_factory." );
            }
            else {
                my $percentage =
                  scalar( keys %{ $self->param('updated_and_added_members_count') } ) . " / " .
                  scalar( @{ $self->param('all_leaves_current_tree') } ) . " = " .
                  scalar( keys %{ $self->param('updated_and_added_members_count') } )/scalar( @{ $self->param('all_leaves_current_tree') } );
                print "Deletion of members was OK, now storing the tree.\n" if ( $self->debug );

                #Remapping leaves.
                $self->_remap_leaves( $self->param( 'all_leaves' ) );

                #Copy tree to the DB
                my $target_tree = $self->store_alternative_tree( $self->param('reuse_gene_tree')->newick_format( 'ryo', '%{-m}%{"_"-x}:%{d}' ),
                                                                 $self->param('output_clusterset_id'),
                                                                 $self->param('current_gene_tree'),
                                                                 undef, 1 );
            }
        } ## end else [ if ( scalar( keys %{ $self...}))]

    } ## end if ( ( $self->param('current_gene_tree'...)))

    #all trees from this point on, there is no need for alignment/tree inference
    else{
        $self->param( 'reuse_gene_tree', $self->param('reuse_tree_adaptor')->fetch_by_stable_id( $self->param('stable_id') ) ) || die "update: Could not get reuse_gene_tree for stable_id" . $self->param('stable_id');
        $self->param( 'all_leaves', $self->param('reuse_gene_tree')->get_all_leaves ) || die "Could not get_all_leaves for: reuse_gene_tree";

        if ( $self->param('current_gene_tree')->get_value_for_tag( 'only_needs_deleting' ) ) {
            print "Tree only needs prunning (only_needs_deleting).\n" if ( $self->debug );
            print "disavow 2\n" if ( $self->debug );
            $self->_disavow_unused_members( $self->param('members_2_b_changed') );
        }
        else{
            print "Tree has not changed at all. Just copy over.\n" if ( $self->debug );
        }

        #Remapping leaves.
        $self->_remap_leaves( $self->param( 'all_leaves' ) );
        #Also copy the tree under the copy clusterset_id, in order to keep track of things, and to make sure CopyAlignmentsFromDB.pm works OK.
        my $target_tree = $self->store_alternative_tree( $self->param('reuse_gene_tree')->newick_format( 'ryo', '%{-m}%{"_"-x}:%{d}' ),
                                                      $self->param('output_clusterset_id'),
                                                      $self->param('current_gene_tree'),
                                                      undef, 1 );
    }
} ## end sub write_output

##########################################
#
# internal methods
#
##########################################

# This function is used to remap the old seq_member_ids in the re_used tree with the new ones used in the current_tree.
# This is necessary for the cases where a species have been updated (gene-set || assembly), this means that the seq_members will be
#   re-inserted therefore not sharing the same ids with the reusede database.
# For more details check Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::FlagUpdateClusters::_seq_member_map
sub _remap_leaves {
    my ( $self, $all_leaves ) = @_;

    foreach my $leaf ( @{$all_leaves} ) {
        my $stable_id = $leaf->stable_id;
        my $sql = "SELECT seq_member_id_current FROM seq_member_id_current_reused_map WHERE stable_id = '$stable_id'";
        my $sth = $self->param('compara_dba')->dbc->prepare($sql);
        $sth->execute() || die "Could not execute ($sql)";
        my $seq_member_id_current = $sth->fetchrow();
        $sth->finish();

        if ($seq_member_id_current) {
            $leaf->seq_member_id($seq_member_id_current);
        }
    }
}

sub _disavow_unused_members {

    my ( $self, $members_2_b_changed ) = @_;

    if ( !%{$members_2_b_changed} ) {
        $self->complete_early("An empty hash has been passed to _disavow_unused_members.");
    }

    print "Removing: " . scalar( keys %{$members_2_b_changed} ) . " out of: " . scalar( @{ $self->param('all_leaves') } ) . "\n" if ( $self->debug );

    #Disavow members' parents
    #loop through the list of members, if any found in the 2_b_deleted list, then need to disavow, if not, just copy over
    foreach my $this_leaf ( @{ $self->param('all_leaves') } ) {
        my $seq_id = $this_leaf->name;
        if ( $members_2_b_changed->{$seq_id} ) {
            print "DELETING:$seq_id\n" if ( $self->debug );
            $this_leaf->disavow_parent;

            my $new_root_node = $self->param('reuse_gene_tree')->root->minimize_tree;
            $self->param('reuse_gene_tree')->{'_root'} = $new_root_node;
        }
    }
}
1;
