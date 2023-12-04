=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::UpdateMSA::UpdateGAB

=head1 DESCRIPTION

Updates the genomic align block (GAB) and its genomic align tree (GAT) (EPO
only), removing the given genomic aligns (GAs), and their corresponding
ancestral GAs, dnafrags and GAT nodes to keep the tree binary (EPO only). Flows
each one of the ancestor dnafrag names that have been removed to branch 2.

If the GAB is left with less than 2 GAs, it is removed altogether with the
ancestral GAB, GAs and dnafrags, and the whole GAT (EPO only). Otherwise, the
CIGAR lines of the remaining GAs (and ancestral GAs) are updated, and so it is
the GAB (and ancestral GAB) alignment length.

=over

=item gab_id

Mandatory. Genomic align block ID to be updated.

=item ga_id_list

Mandatory. List of genomic align IDs to be removed from the given genomic align
block.

=back

=head1 EXAMPLES

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::UpdateMSA::UpdateGAB \
        -compara_db $(mysql-ens-compara-prod-9-ensadmin details url jalvarez_mammals_epo_update_102) \
        -gab_id 19040000000160 -ga_id_list "[19040000000645,19040000000646]"

=cut

package Bio::EnsEMBL::Compara::RunnableDB::UpdateMSA::UpdateGAB;

use warnings;
use strict;

use Bio::EnsEMBL::Registry;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::Cigars;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;
    my $gab_id = $self->param_required('gab_id');
    my $ga_ids_to_rm = $self->param_required('ga_id_list');
    # Get all the genomic aligns (GAs) for the given genomic align block (GAB) and skip the ones we already
    # know are going to be removed
    my $gab = $self->compara_dba->get_GenomicAlignBlockAdaptor->fetch_by_dbID($gab_id);
    my %genomic_aligns = map { $_->dbID => $_ } @{ $gab->genomic_align_array };
    # Check the number of remaining GAs in this GAB
    if ( (scalar keys(%genomic_aligns) - scalar @$ga_ids_to_rm) < 2 ) {
        # A GAB must have at least 2 GAs: remove this GAB and all its related information
        print "GAB $gab_id needs to be removed\n" if $self->debug;
        $self->_register_gab_for_rm($gab, [ keys %genomic_aligns ]);
    } else {
        # Update the remaining GAs, deleting every gap-only column that may be left, and the genomic align
        # tree (GAT)
        delete @genomic_aligns{@$ga_ids_to_rm};
        print "GAB $gab_id needs to be updated\n" if $self->debug;
        $self->_register_gab_for_update($gab, $ga_ids_to_rm, [ values %genomic_aligns ]);
    }
}


sub write_output {
    my $self = shift;
    my $gas_to_update = $self->param('gas_to_update');
    my $new_aln_length = $self->param('new_aln_length');
    my $gabs_to_update = $self->param('gabs_to_update');
    my $node_ids_to_update = $self->param('node_ids_to_update');
    my $ga_ids_to_rm = $self->param('ga_ids_to_rm');
    my $gab_ids_to_rm = $self->param('gab_ids_to_rm');
    my $node_ids_to_rm = $self->param('node_ids_to_rm');
    my $dnafrag_ids_to_rm = $self->param('dnafrag_ids_to_rm');
    my $gat_root_id = $self->param('gat_root_id');

    my $dba = $self->compara_dba;
    my @ancestor_names;
    # Update the genomic_align* tables in a single transaction to make sure the database is consistent if
    # something fails
    $dba->dbc->sql_helper->transaction(-CALLBACK => sub {
        if ( defined $gas_to_update ) {
            # Update the CIGAR lines
            my $sth = $dba->dbc->prepare("UPDATE genomic_align SET cigar_line = ? WHERE genomic_align_id = ?");
            foreach my $ga_id ( keys %$gas_to_update ) {
                $sth->execute($gas_to_update->{$ga_id}, $ga_id);
            }
        }
        if ( defined $gabs_to_update ) {
            # Update the length of both the main GAB and the ancestral GAB (if any)
            $dba->dbc->do("UPDATE genomic_align_block SET length = $new_aln_length WHERE genomic_align_block_id IN (" .
                join(',', map {$_->dbID} @$gabs_to_update) . ")");
        }
        if ( defined $node_ids_to_update ) {
            # Move nodes to their new position inside the GAT
            my $sth = $dba->dbc->prepare("UPDATE genomic_align_tree SET parent_id = ?, distance_to_parent = ? WHERE node_id = ?");
            foreach my $node_id ( keys %$node_ids_to_update ) {
                my $values = $node_ids_to_update->{$node_id};
                if ( ! defined $values->{parent_id} ) {
                    # This node is going to be the new root: update the root_id of the entire GAT
                    $dba->dbc->do("UPDATE genomic_align_tree SET root_id = $node_id WHERE root_id = " . $values->{prev_root_id});
                }
                $sth->execute($values->{parent_id}, $values->{distance}, $node_id);
            }
        }
        # Disable foreign key constraints
        $dba->dbc->do("SET FOREIGN_KEY_CHECKS = 0");
        # Delete all marked GAs, GABs, GAT nodes and ancestral dnafrag ids
        my $nrows = $dba->dbc->do("DELETE FROM genomic_align WHERE genomic_align_id IN (" . join(',', @$ga_ids_to_rm) . ")");
        print "Removed $nrows row(s) from genomic_align\n" if $self->debug;
        if ( defined $gab_ids_to_rm && @$gab_ids_to_rm ) {
            $nrows = $dba->dbc->do("DELETE FROM genomic_align_block WHERE genomic_align_block_id IN (" . join(',', @$gab_ids_to_rm) . ")");
            print "Removed $nrows row(s) from genomic_align_block\n" if $self->debug;
        }
        if ( defined $node_ids_to_rm && @$node_ids_to_rm ) {
            $nrows = $dba->dbc->do("DELETE FROM genomic_align_tree WHERE node_id IN (" . join(',', @$node_ids_to_rm) . ")");
            print "Removed $nrows row(s) from genomic_align_tree\n" if $self->debug;
        }
        if ( defined $dnafrag_ids_to_rm && @$dnafrag_ids_to_rm ) {
            # Get the names of the ancestral dnafrags to be removed to do the same in the ancestral database
            my $dnafrag_ids = join(',', @$dnafrag_ids_to_rm);
            my $sth = $dba->dbc->prepare("SELECT name FROM dnafrag WHERE dnafrag_id IN ($dnafrag_ids)");
            $sth->execute();
            while ( my $dnafrag_name = $sth->fetchrow ) {
                push @ancestor_names, $dnafrag_name;
            }
            $nrows = $dba->dbc->do("DELETE FROM dnafrag WHERE dnafrag_id IN ($dnafrag_ids)");
            print "Removed $nrows ancestral row(s) from dnafrag\n" if $self->debug;
        }
        # The work is done, re-enable foreign key constraints
        $dba->dbc->do("SET FOREIGN_KEY_CHECKS = 1");
    });

    # Update the left and right indexes of this GAT
    if ( defined $gat_root_id ) {
        my $gat_adaptor = $self->compara_dba->get_GenomicAlignTreeAdaptor;
        my $root = $gat_adaptor->fetch_tree_by_root_id($gat_root_id);
        $root->build_leftright_indexing();
        $gat_adaptor->update_subtree($root);
    }

    # Flow the ancestor dnafrag names to syncronise the ancestral database with the dnafrag table
    $self->dataflow_output_id({ name => $_ }, 2) for @ancestor_names;
}


sub _register_gab_for_rm {
    my ($self, $gab, $ga_ids_to_rm) = @_;

    my $dba = $self->compara_dba;
    my $gat_adaptor = $dba->get_GenomicAlignTreeAdaptor();

    my (%gab_ids_to_rm, @node_ids_to_rm, @dnafrag_ids_to_rm);
    $gab_ids_to_rm{$gab->dbID} = 1;
    if ( my $gat = $gat_adaptor->fetch_by_GenomicAlignBlock($gab) ) {
        # Mark all the nodes in the GAT as to be removed (including the ancestral GAB and its GAs)
        foreach my $node ( @{ $gat->root->get_all_nodes_from_leaves_to_this() } ) {
            push @node_ids_to_rm, $node->dbID;
            if (! $node->is_leaf ) {
                my $node_gas = $node->get_all_genomic_aligns_for_node();
                foreach my $ga ( @$node_gas ) {
                    $gab_ids_to_rm{$ga->genomic_align_block_id} = 1;
                    push @$ga_ids_to_rm, $ga->dbID;
                    push @dnafrag_ids_to_rm, $ga->dnafrag_id;
                }
            }
        }
    }

    $self->param('ga_ids_to_rm', $ga_ids_to_rm);
    $self->param('gab_ids_to_rm', [ keys %gab_ids_to_rm ]);
    $self->param('node_ids_to_rm', \@node_ids_to_rm);
    $self->param('dnafrag_ids_to_rm', \@dnafrag_ids_to_rm);
}


sub _register_gab_for_update {
    my ($self, $gab, $ga_ids_to_rm, $genomic_aligns) = @_;
    my %ga_ids_to_rm = map { $_ => 1 } @$ga_ids_to_rm;
    my @gabs_to_update = ( $gab );

    my $dba = $self->compara_dba;
    my $ga_adaptor = $dba->get_GenomicAlignAdaptor();
    my $gat_adaptor = $dba->get_GenomicAlignTreeAdaptor();

    my (%node_ids_to_rm, %node_ids_to_update, $gat_root, @dnafrag_ids_to_rm);
    if ( my $gat = $gat_adaptor->fetch_by_GenomicAlignBlock($gab) ) {
        $gat_root = $gat->root;
        # Get all the GAT inner nodes that are going to lose at least one child
        my %children_to_rm;
        foreach my $ga_id ( sort { $a <=> $b } keys %ga_ids_to_rm ) {
            my $leaf_id = $ga_adaptor->fetch_by_dbID($ga_id)->node_id;
            $node_ids_to_rm{$leaf_id} = 1;
            my $inner_node = $gat_adaptor->fetch_by_dbID($leaf_id)->parent;
            push @{ $children_to_rm{$inner_node->dbID} }, $leaf_id;
            # If only one child is removed, the other child will replace this node in the GAT
            if ( (scalar @{ $children_to_rm{$inner_node->dbID} } == 2) && defined $inner_node->parent ) {
                push @{ $children_to_rm{$inner_node->parent->dbID} }, $inner_node->dbID;
            }
        }
        # Each inner node in a GAT must have two children: if at least one is removed, the inner node has to
        # be removed as well
        $node_ids_to_rm{$_} = 1 for sort { $a <=> $b } keys %children_to_rm;
        # Get the list of ancestral GAs, dnafrags and nodes to remove, plus the nodes to relocate in the GAT
        foreach my $node ( @{ $gat_root->get_all_nodes_from_leaves_to_this() } ) {
            my $node_gas = $node->get_all_genomic_aligns_for_node();
            if ( exists $node_ids_to_rm{$node->dbID} ) {
                foreach my $ga ( @$node_gas ) {
                    $ga_ids_to_rm{$ga->dbID} = 1;
                    push @dnafrag_ids_to_rm, $ga->dnafrag_id unless $node->is_leaf();
                }
            } else {
                if ( $node->has_parent() && exists $node_ids_to_rm{$node->parent->dbID} ) {
                    # Find the final parent node, as it can be a (great-)*grandparent
                    my $new_parent = $node->parent->parent;
                    while ( defined $new_parent && exists $node_ids_to_rm{$new_parent->dbID} ) {
                        $new_parent = $new_parent->parent;
                    }
                    # If $parent is undefined we have reached the GAT root, so this node will be the new root
                    $gat_root = $node unless defined $new_parent;
                    $node_ids_to_update{$node->dbID} = {
                        parent_id    => defined $new_parent ? $new_parent->dbID : undef,
                        prev_root_id => $node->root->dbID,  # only used to update root_id
                        distance     => defined $new_parent ? $node->distance_to_node($new_parent) : $node->distance_to_root(),
                    };
                }
                # Also include the ancestral GAs that will remain to update their CIGAR lines
                push @$genomic_aligns, @$node_gas unless $node->is_leaf();
            }
        }
        # The ancestral GAB will need to be updated as well
        push @gabs_to_update, $genomic_aligns->[-1]->genomic_align_block;
    }
    # Get the new CIGAR lines, discarding any gap-only column produced by the removal of the marked GAs
    my @prev_cigars = map { $_->cigar_line } @$genomic_aligns;
    my @updated_cigars = Bio::EnsEMBL::Compara::Utils::Cigars::minimize_cigars(@prev_cigars);
    my %gas_to_update;
    while ( my ($index, $cigar) = each @updated_cigars ) {
        next if $cigar eq $prev_cigars[$index];
        $gas_to_update{$genomic_aligns->[$index]->dbID} = $cigar;
    }
    # Get the new alignment length
    my $new_aln_length = Bio::EnsEMBL::Compara::Utils::Cigars::alignment_length_from_cigar($updated_cigars[0]);

    $self->param('gas_to_update', \%gas_to_update);
    $self->param('new_aln_length', $new_aln_length);
    $self->param('gabs_to_update', \@gabs_to_update);
    $self->param('node_ids_to_update', \%node_ids_to_update);
    $self->param('ga_ids_to_rm', [ keys %ga_ids_to_rm ]);
    $self->param('node_ids_to_rm', [ keys %node_ids_to_rm ]);
    $self->param('dnafrag_ids_to_rm', \@dnafrag_ids_to_rm);
    $self->param('gat_root_id', $gat_root->dbID) if defined $gat_root;
}


1;
