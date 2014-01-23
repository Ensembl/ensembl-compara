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

Bio::EnsEMBL::Compara::DBSQL::SpeciesTreeAdaptor

=head1 SYNOPSIS


=head1 DESCRIPTION

  SpeciesTreeAdaptor - Adaptor for different species trees used in ensembl-compara


=head1 APPENDIX

  The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::SpeciesTreeAdaptor;

use strict;
use warnings;
use Data::Dumper;

use Bio::EnsEMBL::Compara::SpeciesTree;
use Bio::EnsEMBL::Compara::SpeciesTreeNode;
use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor');

sub new_from_newick {
    my ($self, $newick, $label, $name_method, $taxon_id_method) = @_;

    my $st = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick, 'Bio::EnsEMBL::Compara::SpeciesTreeNode');

    my $st_root = $self->db->get_SpeciesTreeNodeAdaptor->new_from_NestedSet($st, $name_method, $taxon_id_method);

    my $speciesTree = Bio::EnsEMBL::Compara::SpeciesTree->new();
    $speciesTree->label($label);
    $speciesTree->species_tree($newick);
    $speciesTree->root($st_root);

    return $speciesTree;
}

sub fetch_all {
    my ($self) = @_;

    my $constraint = "stn.node_id = str.root_id";
    return $self->generic_fetch($constraint);
}

sub fetch_by_method_link_species_set_id_label {
    my ($self, $mlss_id, $label) = @_;

    $label = 'default' unless (defined $label);

    my $constraint = "method_link_species_set_id = $mlss_id AND label = '$label'";
    my $sp_trees = $self->generic_fetch($constraint);
    return $sp_trees->[0];
}

sub fetch_all_by_method_link_species_set_id_label_pattern {
 my ($self, $mlss_id, $label) = @_; 
 $label = 'default' unless (defined $label);
 my $constraint = "method_link_species_set_id = $mlss_id AND label LIKE '%$label%'";
 return  $self->generic_fetch($constraint);
}

sub fetch_by_root_id {
    my ($self, $root_id) = @_;

    my $constraint = "root_id = $root_id";
    my $sp_trees = $self->generic_fetch($constraint);
    return $sp_trees->[0];
}

sub store {
    my ($self, $tree, $mlss_id) = @_;
    
    if($mlss_id){
     $tree->method_link_species_set_id($mlss_id);
    } else {
     $mlss_id = $tree->method_link_species_set_id;
    }

    my $species_tree_node_adaptor = $self->db->get_SpeciesTreeNodeAdaptor();

    # Store the nodes
    my $root_id = $species_tree_node_adaptor->store($tree->root, $mlss_id);
    $tree->{'_root_id'} = $root_id;

    # Store the rest of the nodes
    # for my $child (@{$tree->root->get_all_nodes}) {
    #     print "ROOT_ID FOR NODE IS: ", $child->root->node_id, "\n";
    #     $species_tree_node_adaptor->store($child);
    # }

    # Store the tree in the header table
    # method_link_species_set_id must be set to its real value to honour the foreign key
    my $sth = $self->prepare('INSERT INTO species_tree_root (root_id, method_link_species_set_id, label, species_tree) VALUES (?,?,?,?)');
    $sth->execute($root_id, $tree->method_link_species_set_id, $tree->label || 'default', $tree->species_tree);

    $tree->adaptor($self);
    return $root_id;
}


sub _columns {
    return qw ( str.root_id
                str.method_link_species_set_id
                str.species_tree
                str.label
             );
}

sub _tables {
    return (['species_tree_root','str']);
}

sub _objs_from_sth {
    my ($self, $sth) = @_;
    my $tree_list = [];

    while (my $rowhash = $sth->fetchrow_hashref) {
        my $tree = $self->create_instance_from_rowhash($rowhash);
        push @$tree_list, $tree;
    }
    return $tree_list;
}

sub create_instance_from_rowhash {
    my ($self, $rowhash) = @_;

    my $tree = new Bio::EnsEMBL::Compara::SpeciesTree;
    $self->init_instance_from_rowhash($tree, $rowhash);
    return $tree;
}

sub init_instance_from_rowhash {
    my ($self, $tree, $rowhash) = @_;

    $tree->method_link_species_set_id($rowhash->{method_link_species_set_id});
    $tree->species_tree($rowhash->{species_tree});
    $tree->label($rowhash->{label});
    $tree->root_id($rowhash->{root_id});

    $tree->adaptor($self);
    return $tree;
}

1;
