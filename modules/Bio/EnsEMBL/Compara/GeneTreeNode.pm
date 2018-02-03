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

Bio::EnsEMBL::Compara::GeneTreeNode

=head1 DESCRIPTION

Specific subclass of NestedSet to add functionality when the nodes of this tree
are GeneTreeMember objects and the tree is a representation of a gene derived
Phylogenetic tree

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::GeneTreeNode
  `- Bio::EnsEMBL::Compara::NestedSet

=head1 SYNOPSIS

The properties of a GeneTreeNode are:
 - species_tree_node()
 - taxonomy_level() (alias to species_tree_node()->node_name())
 - node_type()
 - lost_taxa()
 - duplication_confidence_score()
 - bootstrap()

Links within the GeneTree/GeneTreeNode structure:
 - tree()
 - root()
 - get_leaf_by_Member()

Extract properties of a sub-tree:
 - get_AlignedMemberSet()

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=head1 METHODS

=cut

package Bio::EnsEMBL::Compara::GeneTreeNode;

use strict;
use warnings;

use IO::File;

use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;

use Bio::EnsEMBL::Compara::AlignedMemberSet;

use base ('Bio::EnsEMBL::Compara::NestedSet');

# Attributes / tags

=head2 species_tree_node

  Description: Getter for the node in the species tree the current node refers to

=cut

sub species_tree_node {
    my $self = shift;

    # If it is already there, return it
    if ($self->{_species_tree_node}) {
        return $self->{_species_tree_node};
    }

    my $stn_id = $self->_species_tree_node_id();
    if ($stn_id && $self->adaptor && !$self->{_species_tree_node}) {
        $self->{_species_tree_node} = $self->adaptor->db->get_SpeciesTreeNodeAdaptor->cached_fetch_by_dbID($stn_id);
    }

    return $self->{_species_tree_node};
}


=head2 _species_tree_node_id

  Description: Internal getter for the node ID of the species tree node related
               to the current gene tree node

=cut

sub _species_tree_node_id {
    my $self = shift;

    ## Leaves don't have species_tree_node_id tag, so this value has to be taken from the GeneTreeMember (via its genome_db_id);
    if (not $self->has_tag('species_tree_node_id') and $self->isa('Bio::EnsEMBL::Compara::GeneTreeMember') and $self->adaptor) {
        my $species_tree = $self->tree->species_tree;
        return unless $species_tree;
        $self->{_species_tree_node} = $species_tree->get_genome_db_id_2_node_hash()->{$self->genome_db_id};
        die sprintf("The genome_db_id '%s' cannot be found in the species_tree root_id=%s", $self->genome_db_id, $species_tree->dbID) unless $self->{_species_tree_node};
        $self->{'_tags'}->{'species_tree_node_id'} = $self->{_species_tree_node}->node_id;
    }

    return $self->get_value_for_tag('species_tree_node_id')
}


=head2 taxonomy_level

  Example    : $taxonomy_level = $homology->taxonomy_level();
  Description: getter of string description of homology taxonomy_level.
               Examples: 'Chordata', 'Euteleostomi', 'Homo sapiens'
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub taxonomy_level {
    my $self = shift;
    return $self->species_tree_node()->node_name() if $self->species_tree_node();
}


=head2 node_type

  Description: Getter/setter for the node_type attribute. It shows the event that took place
               at that node. Currently, one of "duplication", "speciation", "dubious",
               and "gene_split"

=cut

sub node_type {
    my $self = shift;
    return $self->_getter_setter_for_tag('node_type', @_);
}

sub _newick_dup_code {
    my $self = shift;
    my $node_type = $self->node_type;
    return 'D=N' if ($node_type eq 'speciation');
    return 'DD=Y' if ($node_type eq 'dubious');
    return 'D=Y';
}


=head2 lost_taxa

  Description: Returns the list of the species-tree nodes of the taxa
               that have lost that gene on the branch leading to the current node

=cut

sub lost_taxa {
    my $self = shift;
    unless ($self->{_lost_species_tree_nodes}) {
        $self->{_lost_species_tree_nodes} = $self->adaptor->db->get_SpeciesTreeNodeAdaptor->cached_fetch_all_by_dbID_list( $self->get_all_values_for_tag('lost_species_tree_node_id') );
    }
    return $self->{_lost_species_tree_nodes};
}


=head2 duplication_confidence_score

  Description: Getter/setter the confidence score of the duplication node (between 0 and 1)
               "dubious" nodes always return 0, "speciation" nodes always return undef

=cut

sub duplication_confidence_score {
    my $self = shift;
    return $self->_getter_setter_for_tag('duplication_confidence_score', @_);
}


=head2 bootstrap

  Description: Getter/setter the bootstrap value of that node (between 0 and 100)

=cut

sub bootstrap {
    my $self = shift;
    return $self->_getter_setter_for_tag('bootstrap', @_);
}


=head2 tree

  Arg [1]     : GeneTree
  Example     : my $tree = $tree_node->tree();
  Description : Returns the GeneTree this node belongs to
                Can also work as a setter
  Returntype  : Bio::EnsEMBL::Compara::GeneTree object
  Exceptions  :
  Caller      : general
  Status      : stable

=cut

sub tree {
    my $self = shift;
    if (@_) {
        $self->{'_tree'} = shift;
    } elsif ((not defined $self->{'_tree'}) and (defined $self->adaptor) and (defined $self->{_root_id})) {
        $self->{'_tree'} = $self->adaptor->db->get_GeneTreeAdaptor->fetch_by_root_id($self->{_root_id});
    }
    return $self->{'_tree'};
}


=head2 root

  Example     : my $root = $node->root();
  Description : Returns the root of the tree by taking advantage of the
                GeneTree object if possible. Otherwise, defaults to the
                normal tree traversal
  Returntype  : Bio::EnsEMBL::Compara::GeneTreeNode object
  Exceptions  :
  Caller      : general
  Status      : stable

=cut

sub root {
    my $self = shift;
    if (defined $self->tree) {
        return $self->tree->root;
    } else {
        return $self->SUPER::root;
    }
}


=head2 release_tree

  Description: Removes the to/from GeneTree reference to
               allow freeing memory 
  Example    : $self->release_tree;
  Returntype : undef
  Exceptions : none
  Caller     : general

=cut

sub release_tree {
    my $self = shift;

    if (defined $self->{'_tree'}) {
        delete $self->{'_tree'}->{'_root'};
        delete $self->{'_tree'};
    }
    return $self->SUPER::release_tree;
}


#use Data::Dumper;

#sub string_node {
#    my $self = shift;
#    my $str = $self->SUPER::string_node;
#    if (defined $self->{'_tree'}) {
#        my $t = $self->{'_tree'};
#        $str = chop($str)." $t/root_id=".($self->{'_tree'}->root_id)."/".join("/", map { "$_ => ${$t}{$_}" } keys %$t)."\n";
#    }
#    return $str;
#}


=head2 get_leaf_by_Member

  Arg [1]     : Member: the member to search in the tree
  Example     : my $leaf = $brca2_tree->get_leaf_by_Member($brca2_peptide)
  Description : Returns the leaf that corresponds to the member given as argument
  Returntype  : Bio::EnsEMBL::Compara::GeneTreeMember object
  Exceptions  :
  Caller      : general
  Status      : stable

=cut

sub get_leaf_by_Member {
  my $self = shift;
  my $member = shift;

  if($member->isa('Bio::EnsEMBL::Compara::GeneTreeNode')) {
    return $self->find_leaf_by_node_id($member->node_id);
  } elsif ($member->isa('Bio::EnsEMBL::Compara::GeneMember')) {
    return $self->find_leaf_by_name($member->get_canonical_SeqMember->stable_id);
  } elsif ($member->isa('Bio::EnsEMBL::Compara::SeqMember')) {
    return $self->find_leaf_by_name($member->gene_member->get_canonical_SeqMember->stable_id);
  } else {
    die "Need a Member object!";
  }
}


=head2 get_AlignedMemberSet

  Example     : my $member_set = $tree->get_AlignedMemberSet
  Description : Returns a new AlignedMemberSet object for this sub-tree
                This is the prefered method of getting an alignment for a sub-tree
  Returntype  : Bio::EnsEMBL::Compara::AlignedMemberSet object
  Exceptions  :
  Caller      : general
  Status      : stable

=cut

sub get_AlignedMemberSet {
    my $self = shift;
    my $set = Bio::EnsEMBL::Compara::AlignedMemberSet->new(
        -adaptor => $self->adaptor,
        -method_link_species_set_id => $self->tree->method_link_species_set_id,
        -stable_id => $self->tree->stable_id,
        -version => sprintf("%d.%d", $self->tree->version || 0, $self->node_id),
    );
    foreach my $member (@{$self->get_all_leaves}) {
        $set->add_Member($member) if $member->isa('Bio::EnsEMBL::Compara::GeneTreeMember');
    }
    return $set;
}


=head2 get_SimpleAlign

  Example     : $tree->get_SimpleAlign(-SEQ_TYPE => 'cds');
  Description : Returns the tree with removed nodes in taxon_id list.
  Returntype  : Bio::SimpleAlign
  Exceptions  :
  Caller      : general
  Status      : At risk (may become deprecated soon)

=cut

sub get_SimpleAlign {
    my $self = shift;
    return $self->get_AlignedMemberSet->get_SimpleAlign(@_, -REMOVE_GAPS => 1);
}


=head2 consensus_cigar_line

  Example    : my $consensus_cigar = $gene_tree->consensus_cigar_line();
  Description: Creates a consensus cigar line for all the leaves of the
               sub-tree. See Bio::EnsEMBL::Compara::AlignedMemberSet
  Returntype : string
  Caller     : general
  Status     : At risk (may become deprecated soon)

=cut

sub consensus_cigar_line {
    my $self = shift;
    my @cigars;
    foreach my $leaf (@{$self->get_all_leaves}) {
        push @cigars, $leaf->cigar_line if $leaf->isa('Bio::EnsEMBL::Compara::GeneTreeMember') and $leaf->cigar_line;
    }
    return Bio::EnsEMBL::Compara::Utils::Cigars::consensus_cigar_line(@cigars);
}



=head2 remove_nodes_by_taxon_ids

  Arg [1]     : arrayref of taxon_ids
  Example     : my $ret_tree = $tree->remove_nodes_by_taxon_ids($taxon_ids);
  Description : Returns the tree with removed nodes in taxon_id list.
  Returntype  : Bio::EnsEMBL::Compara::GeneTreeNode object
  Exceptions  :
  Caller      : general
  Status      : At risk (behaviour on exceptions could change)

=cut

sub remove_nodes_by_taxon_ids {
  my $self = shift;
  my $species_arrayref = shift;

  my @tax_ids = @{$species_arrayref};
  # Turn the arrayref into a hash.
  my %tax_hash;
  map {$tax_hash{$_}=1} @tax_ids;

  my @to_delete;
  foreach my $leaf (@{$self->get_all_leaves}) {
    if (exists $tax_hash{$leaf->taxon_id}) {
      push @to_delete, $leaf;
    }
  }
  return $self->remove_nodes(\@to_delete);

}


=head2 keep_nodes_by_taxon_ids

  Arg [1]     : arrayref of taxon_ids
  Example     : my $ret_tree = $tree->keep_nodes_by_taxon_ids($taxon_ids);
  Description : Returns the tree with kept nodes in taxon_id list.
  Returntype  : Bio::EnsEMBL::Compara::GeneTreeNode object
  Exceptions  :
  Caller      : general
  Status      : At risk (behaviour on exceptions could change)

=cut

sub keep_nodes_by_taxon_ids {
  my $self = shift;
  my $species_arrayref = shift;

  my @tax_ids = @{$species_arrayref};
  # Turn the arrayref into a hash.
  my %tax_hash;
  map {$tax_hash{$_}=1} @tax_ids;

  my @to_delete;
  foreach my $leaf (@{$self->get_all_leaves}) {
    unless (exists $tax_hash{$leaf->taxon_id}) {
      push @to_delete, $leaf;
    }
  }
  return $self->remove_nodes(\@to_delete);

}

=head2 find_multifurcations

  Arg [1]     : none
  Example     : my $multifurcations = $multifurcated_tree_root->find_multifurcations;
  Description : List of multifurcations given a tree.
                In order to avoid changing parts of the tree that are not in the multifurcations, we have local MRCAs.
                e.g.:
                multifurcations[0] = (child_1,child2,child3)
                multifurcations[1] = (child_7,child8,child9)

  Returntype  : array reference
  Exceptions  :
  Caller      :

=cut

sub find_multifurcations {
    my $self = shift;

    my $multifurcations = [];
    foreach my $node (@{$self->get_all_nodes}) {
        next if $node->is_leaf;
        next if (!$node->has_parent);
        if (scalar(@{$node->children}) > 2) {
            push(@{$multifurcations},[@{$node->children}]) if scalar(@{$node->children}) > 2;
        }
    }
    return $multifurcations;
}


=head2 binarize_flat_tree_with_species_tree

  Arg [1]     : Species Tree object
  Arg [1]     : multifurcation hash from (find_multifurcations)
  Example     : $multifurcated_tree_root->binarize_flat_tree_with_species_tree($species_tree, $multifurcations);
  Description : Tries to binarize the genetree using the Species Tree to resolve the multifurcations.
  Returntype  : None
  Exceptions  :
  Caller      :

=cut

sub binarize_flat_tree_with_species_tree {
    my $self            = shift;
    my $species_tree    = shift;
    my $multifurcations = shift;

    #fetch specie tree objects for the multifurcated nodes
    my %species_tree_leaves_in_multifurcation;
    foreach my $multi (@$multifurcations){
        foreach my $child (@{$multi}){
            my ($name_id, $species_tree_node_id) = split(/\_/,$child->name);
            my $species_tree_node = $species_tree->root->find_leaf_by_node_id($species_tree_node_id);
            push(@{$species_tree_leaves_in_multifurcation{$multi}}, $species_tree_node);
        }
    }

    foreach my $multi (@$multifurcations) {
        #get mrca sub-tree
        my $mrca = $species_tree->root->find_first_shared_ancestor_from_leaves( [@{$species_tree_leaves_in_multifurcation{$multi}}] );

        #get gene_tree mrca sub-tree
        my $mrcaGeneTree = $self->find_first_shared_ancestor_from_leaves( [@{$multi}] );

        #get mrca leaves
        my @leaves_mrca= @{ $mrca->get_all_leaves() };

        #get taxon_ids for the mrca sub-tree
        my @taxonIdsMrca;
        foreach my $leaf (@leaves_mrca){
            push(@taxonIdsMrca,$leaf->dbID);
            #print $leaf->dbID."\n";
        }

        #get taxon_ids for the leaves in the multifurcations
        my @taxonIdsMultifurcation;
        foreach my $leaf (@{$species_tree_leaves_in_multifurcation{$multi}}){
            push(@taxonIdsMultifurcation,$leaf->dbID);
            #print $leaf->dbID."\n";
        }

        my @nodesToDisavow;
        my %count;
        foreach my $e (@taxonIdsMrca, @taxonIdsMultifurcation) { $count{$e}++ }
        foreach my $e (keys %count) {
            if ($count{$e} != 2) {
                push @nodesToDisavow, $e;
            }
        }

        my $castedMrca = $mrca->copy('Bio::EnsEMBL::Compara::GeneTreeNode');

        #prune castedMrca sub-tree
        #e.g. when the taxonomic sub-tree has more species that the ones in the gene-tree, in those cases we need to remove the extra leaves.

        #disavow these nodes from the castedMrca sub-tree
        foreach my $nodeName (@nodesToDisavow) {
            my $node = $castedMrca->find_leaf_by_node_id($nodeName);
            #since nodes are leaves at this point, we can delete them directly.
            #print "disavowing: |" . $node->name() . "|\n";
            $node->disavow_parent();
            $castedMrca = $castedMrca->minimize_tree;
        }

        #list of all the leaves mapped by taxon_id
        my %leaves_list;
        my %branch_length_list;
        foreach my $leaf (@{$mrcaGeneTree->get_all_leaves}) {
            my ($member_id, $taxon_id) = split(/\_/,$leaf->name);
            push(@{$leaves_list{$taxon_id}},$member_id);

            #get the leaves branch lengths
            my $bl = $leaf->distance_to_parent;
            $branch_length_list{$member_id} = $bl;
        }

        #Renaming nodes
        foreach my $leaf (@{$castedMrca->get_all_leaves}) {
           my $taxon_id = $leaf->dbID;
           foreach my $member (@{$leaves_list{$taxon_id}}) {
               my $new_name = $member."_".$taxon_id;
               #new name
               $leaf->name($new_name);
               #keep same bl from before, since they are leaves
               $leaf->distance_to_parent($branch_length_list{$member});
           }
        }

        my $parentMrca = $mrcaGeneTree->parent();
        my $bl = $mrcaGeneTree->distance_to_parent;
        $mrcaGeneTree->disavow_parent();

        #adding new binary branch
        #We need to add from the casted MRCA tree
        #$parentMrca->add_child($mrcaGeneTree,$bl);
        $parentMrca->add_child($castedMrca,$bl);
    }
}

1;

