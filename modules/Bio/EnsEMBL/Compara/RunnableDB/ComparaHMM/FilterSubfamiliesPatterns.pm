
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

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::FilterSubfamiliesPatterns

=head1 SYNOPSIS

This runnable is used to:

    1 - Builds a FastTree for all the filter_level_2 trees
    2 - Select potential break-points according to the parameter bl_factor
    3 - Split the tree on the break-points until a desired level of balance is achieved (tree_balance_threshold).
    4 - If the split is unsuccessful, the vanilla tree is copied to the filter_level_3.
    5 - If the tree is split, two new trees are created using the supertree approach.

    bl_factor: regulates the stringency of the break-points. Its combined with the average branch lengths across the whole tree.

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to split huge families.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::FilterSubfamiliesPatterns;

use strict;
use warnings;
use List::Util qw( min );
use List::Util qw( sum );
use List::Compare;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GenericRunnable');

sub param_defaults {
    my $self = shift;
    return { %{ $self->SUPER::param_defaults },
             'cmd'                    => '#fasttree_exe# -nosupport -pseudo -noml -quiet -nopr -wag #alignment_file# > #output_file#',
             'runtime_tree_tag'       => 'fasttree_filter_level_3_runtime',
             'input_clusterset_id'    => 'raxml_parsimony',
             'output_file'            => 'FastTree_#gene_tree_id#.tree',
             'tree_balance_threshold' => 0.25,
             'bl_factor'              => 15,
         };
}

sub run {
    my $self = shift @_;

    $self->cleanup_worker_temp_directory;
    $self->run_generic_command;

    my $supertree_root = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree( $self->param('newick_output') ) || die "Could not parse FastTree newick.";

    #1 - Only store the BLs that are greater than the average:
    my %branch_lengths_by_bl;
    my %branch_lengths;

    #2 - Build temporary BL list, only to be used when computing the average BL size:
    my @tmp_bl_list;
    for my $node ( @{ $supertree_root->get_all_nodes } ) {
        next if ( $node->is_leaf );
        push( @tmp_bl_list, $node->distance_to_parent );
    }

    #3 - Get the average BL size:
    my $total_bl   = sum @tmp_bl_list;
    my $average_bl = $total_bl/scalar(@tmp_bl_list);

    #4 - Store the BLs that satisfy the criteria defined by bl_factor vs. average_bl:
    for my $node ( @{ $supertree_root->get_all_nodes } ) {
        next if ( $node->is_leaf );
        my $bl = $node->distance_to_parent;

        #Fast tree may generate 0.0 BLs as well as some negative BLs, which obviously should not be used as break-points.
        if ( ( $bl > 0 ) && ( $bl > ( $self->param('bl_factor')*$average_bl ) ) ) {
            print "==============$bl|\n" if $self->debug;
            $branch_lengths{ $node->dbID } = $bl;
        }
    }

    $self->param( 'branch_lengths',       \%branch_lengths );
    $self->param( 'branch_lengths_by_bl', \%branch_lengths_by_bl );
    $self->param( 'average_bl',           $average_bl );

    #Should try to split the tree only if there are BL that satisfy the requirements for break-points:
    if ( scalar( keys( %{ $self->param('branch_lengths') } ) ) > 0 ) {

        #my $supertree      = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_root_id( $self->param('gene_tree_id') );
        my $supertree = $self->param('gene_tree');
        $supertree->tree_type('supertree');

        #split tree main loop
        $self->_do_splittree_loop($supertree_root);

        print STDERR scalar( @{ $supertree->get_all_Members } ), " members found in the super-tree\n" if $self->debug;

        print "ini_root: ", $supertree->root, "\n" if $self->debug;

        _print_supertree( $self->param('gene_tree')->root, "" ) if $self->debug;

    }
    else {
        #die "ONLY ALLOWING SUPERTREES THIS TIME ;)";
        $self->compara_dba->get_GeneTreeAdaptor->change_clusterset( $self->param('gene_tree'), "filter_level_3" );
        $self->input_job->autoflow(0);
        $self->complete_early("No breakpoints found, just copying the tree to filter_level_3");
    }

} ## end sub run

sub write_output {
    my $self = shift @_;
    #die "NOT ALLOWING SUPERTREES THIS TIME ;)";
    $self->call_within_transaction( sub { $self->_write_output } );
}

##########################################
#
# internal methods
#
##########################################

sub _write_output {
    my $self = shift @_;

    $self->compara_dba->get_GeneTreeAdaptor->store( $self->param('gene_tree') ) || die "Could not store (FastTree/supertree) tree.";

    $self->compara_dba->get_GeneTreeAdaptor->change_clusterset( $self->param('gene_tree'), "filter_level_3" );

    #Traverse the supertree and get the root ids of the two subtrees that are not yet in the database.
    my @root_ids;
    _get_subtree_root_ids( $self->param('gene_tree')->root, \@root_ids );

    die "Something went wrong and only 1 out of the 2 expected trees is present" if (scalar(@root_ids) != 2);

    my ($root_id_1, $root_id_2) = @root_ids;

    #For the moment we will not store the tags, there is a bug causing the root_ids of the subtrees not to be defined
    $self->_rec_update_tags( $self->param('gene_tree')->root );

    #Data flowing the two subtrees to be aligned:
    $self->dataflow_output_id({"gene_tree_id" => $root_id_1}, 2);
    $self->dataflow_output_id({"gene_tree_id" => $root_id_2}, 2);

} ## end sub _write_output

sub _do_splittree_loop {
    my $self                         = shift;
    my $supertree_root               = shift;
    my @splitted_trees_newick_string = $self->_split_tree($supertree_root);

    $self->_rec_update_indexing( $self->param('gene_tree')->root );
}

sub _split_tree {
    my $self            = shift;
    my $input_tree_root = shift;

    #1 - Build an array sorted by the longest BL to the shortest.
    my @sorted_bls;
    foreach my $bl ( sort { $a <=> $b } values %{ $self->param('branch_lengths') } ) {
        push( @sorted_bls, $bl );
    }

    #2 - Longer BLs first
    @sorted_bls = reverse @sorted_bls;

    #3 - Store extra map with the values as keys:
    foreach my $id ( keys %{ $self->param('branch_lengths') } ) {
        $self->param('branch_lengths_by_bl')->{ $self->param('branch_lengths')->{$id} } = $id;
        print "\t\tstoring BL:|$id|" . $self->param('branch_lengths')->{$id} . "|\n";
    }

    #Used to identify the round of balancing.
    my $round = 0;

    #Start with the longest BL:
    my $max_val_key = $self->param('branch_lengths_by_bl')->{ $sorted_bls[$round] };

    print "LONGEST BL = " . $max_val_key . "->" . $self->param('branch_lengths')->{$max_val_key} . "|\n";

    my @members_set_1;
    my @members_set_2;
    my $tree_balance_threshold = $self->param('tree_balance_threshold');

    my $balance = 0;

    my @all_members = sort( map { $_->name } @{ $input_tree_root->get_all_leaves } );

    #Wrap this around a while loop (need to count the balance between the two children to see if one of the sub-trees have at least the $threshold (~20%) of minimun members)
    while ( $balance < $tree_balance_threshold ) {

        $round++;

        #If we exausted all the BLs that are greater than the average, it will not be possible to split.
        if ( $round == scalar( keys( %{ $self->param('branch_lengths') } ) ) ) {
            #die "ONLY ALLOWING SUPERTREES THIS TIME ;)";
            $self->compara_dba->get_GeneTreeAdaptor->change_clusterset( $self->param('gene_tree'), "filter_level_3" );
            $self->input_job->autoflow(0);
            $self->complete_early( "Tree probably need to be splitted, but exausted all the possible BLs (probably due to un-balance of the subtrees). It will be copied to filter_level_3 anyway");
        }

        my $split_node = $input_tree_root->find_node_by_node_id($max_val_key) || die "Could not find the node $max_val_key";
        print "SPLIT ID:" .  $split_node->dbID . " BL:" . $split_node->distance_to_parent . " PARENT_ID:" . $split_node->parent->dbID . " BL: " . $split_node->parent->distance_to_parent . "\n";

        @members_set_1 = sort( map { $_->name } @{ $split_node->get_all_leaves } );

        my $compare_obj = List::Compare->new( \@all_members, \@members_set_1 );
        @members_set_2 = $compare_obj->get_Lonly();

        print "set_1:" . scalar(@members_set_1) . "\n" if $self->debug;
        print "set_2:" . scalar(@members_set_2) . "\n" if $self->debug;
        print "all:" . scalar(@all_members) . "\n" if $self->debug;

        $balance = min( ( scalar(@members_set_1)/scalar(@all_members) ), ( scalar(@members_set_2)/scalar(@all_members) ) );

        print "\nBALANCE:$balance\n" if $self->debug;

        #get the chield with the longest branch as next candidate to split
        if ( $balance < $tree_balance_threshold ) {
            print "RECOMPUTING BALANCE: $round\n" if $self->debug;

            #get the n-th longest branch
            $max_val_key = $self->param('branch_lengths_by_bl')->{ $sorted_bls[$round] };
        }
        else {
            print "BALANCE OK:$balance\n" if $self->debug;
        }
    } ## end while ( $balance < $tree_balance_threshold)

    my $supertree = $self->param('gene_tree');

    my $stable_id = $self->param('gene_tree')->stable_id;

    my $supertree_leaf1 = new Bio::EnsEMBL::Compara::GeneTreeNode;
    my $cluster1 = new Bio::EnsEMBL::Compara::GeneTree( -tree_type                  => 'tree',
                                                        -clusterset_id              => 'filter_level_3',
                                                        -member_type                => $supertree->member_type,
                                                        -method_link_species_set_id => $supertree->method_link_species_set_id,
                                                        -stable_id                  => $stable_id."_1",
                                                      );

    my $supertree_leaf2 = new Bio::EnsEMBL::Compara::GeneTreeNode;
    my $cluster2 = new Bio::EnsEMBL::Compara::GeneTree( -tree_type                  => 'tree',
                                                        -clusterset_id              => 'filter_level_3',
                                                        -member_type                => $supertree->member_type,
                                                        -method_link_species_set_id => $supertree->method_link_species_set_id,
                                                        -stable_id                  => $stable_id."_2",
                                                    );

    print "\n\n\n\nRunning QTB-like code\n\n";

    foreach my $string_id (@members_set_1) {
        my @tok = split( /\_/, $string_id );
        my $leaf = $self->param('gene_tree')->root->find_leaves_by_field( "seq_member_id", $tok[0] );
        $cluster1->add_Member( $leaf->[0] );
    }

    foreach my $string_id (@members_set_2) {
        my @tok = split( /\_/, $string_id );
        my $leaf = $self->param('gene_tree')->root->find_leaves_by_field( "seq_member_id", $tok[0] );
        $cluster2->add_Member( $leaf->[0] );
    }

    #Add comments: ........
    $supertree_leaf1->add_child( $cluster1->root ) || die "Could not add child.";
    $cluster1->root->{'_different_tree_object'} = 1;
    $supertree_leaf1->tree($supertree);

    $supertree_leaf2->add_child( $cluster2->root ) || die "Could not add child.";
    $cluster2->root->{'_different_tree_object'} = 1;
    $supertree_leaf2->tree($supertree);

    $self->param('gene_tree')->root->add_child($supertree_leaf1) || die "Could not add child.";
    $self->param('gene_tree')->root->add_child($supertree_leaf2) || die "Could not add child.";

    $supertree->tree_type('supertree');

} ## end sub _split_tree

sub _rec_update_indexing {
    my $self  = shift;
    my $node  = shift;
    my $index = shift;

    if ( $node->tree->tree_type eq 'supertree' ) {
        $node->left_index($index);
        $index++;
        foreach my $child ( @{ $node->children } ) {
            $index = $self->_rec_update_indexing( $child, $index );
        }
        $node->right_index($index);
        $index++;
    }
    return $index;
}

sub _get_subtree_root_ids {
    my $node         = shift;
    my $ref_root_ids = shift;

    if ( $node->tree->tree_type eq 'tree' ) {
        push( @{$ref_root_ids}, $node->tree->{_root_id} );
    }
    else {
        foreach my $child ( @{ $node->children } ) {
            _get_subtree_root_ids( $child, $ref_root_ids );
        }
    }
}

sub _print_supertree {
    my $node   = shift;
    my $indent = shift;
    print $indent;
    $node->print_node;
    if ( $node->tree->tree_type eq 'tree' ) {
        print $indent, "TREE: ", scalar( @{ $node->get_all_leaves } ), "\n";
    }
    else {
        print $indent, "SUPERTREE\n";
        $indent .= "\t";
        foreach my $child ( @{ $node->children } ) {
            _print_supertree( $child, $indent );
        }
    }
}

sub _rec_update_tags {
    my $self = shift;
    my $node = shift;

    if ( $node->tree->tree_type eq 'tree' ) {
        my $cluster = $node->tree;

        #print "CALLING ON TREE\n";
        my $node_id = $cluster->{_root_id};

        my $leafcount = scalar( @{ $cluster->root->get_all_leaves } );
        $cluster->add_tag( 'gene_count', $leafcount );

        print STDERR "Stored |$node_id| with |$leafcount| leaves\n" if ( $self->debug );

        #We replicate needed tags into the children
        if ( defined $self->param('tags_to_copy') ) {
            $cluster->copy_tags_from( $self->param('gene_tree'), $self->param('tags_to_copy') );
        }

        $cluster->adaptor->_store_all_tags($cluster);

    }
    else {
        #print "CALLING ON SUPERTREE\n";
        $node->store_tag( 'tree_support', 'quicktree' );
        $node->store_tag( 'node_type',    'speciation' );
        foreach my $child ( @{ $node->children } ) {
            $self->_rec_update_tags($child);
        }
    }

} ## end sub _rec_update_tags

# Wrapper around Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks
# NB: this will be testing $self->param('gene_tree_id')
sub post_healthcheck {
    my $self = shift;
    Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks::_embedded_call( $self, 'supertrees' );
}

1;
