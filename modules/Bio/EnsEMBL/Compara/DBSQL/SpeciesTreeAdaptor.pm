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

Bio::EnsEMBL::Compara::DBSQL::SpeciesTreeAdaptor

=head1 DESCRIPTION

  SpeciesTreeAdaptor - Adaptor for different species trees used in ensembl-compara


=head1 APPENDIX

  The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::SpeciesTreeAdaptor;

use strict;
use warnings;
use Data::Dumper;

use DBI qw(:sql_types);

use Bio::EnsEMBL::Compara::SpeciesTree;
use Bio::EnsEMBL::Compara::SpeciesTreeNode;

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseFullCacheAdaptor');


#################
# Fetch methods #
#################

sub fetch_by_method_link_species_set_id_label {
    my ($self, $mlss_id, $label) = @_;

    return $self->_id_cache->get_by_additional_lookup('mlss_id_label', $mlss_id.'____'.(lc $label));
}

sub fetch_all_by_method_link_species_set_id_label_pattern {
 my ($self, $mlss_id, $label) = @_; 
 $label //= '';
 my $mlss_trees = $self->_id_cache->get_all_by_additional_lookup('mlss_id', $mlss_id);
 return [grep {$_->label =~ /$label/} @$mlss_trees];
}


sub fetch_all_by_method_link_species_set_id {
 my ($self, $mlss_id) = @_; 
 my $mlss_trees = $self->_id_cache->get_all_by_additional_lookup('mlss_id', $mlss_id);
 return $mlss_trees;
}

sub fetch_by_root_id {
    my $self = shift;
    return $self->fetch_by_dbID(@_);
}

sub fetch_by_node_id {
    my ($self, $node_id) = @_;
    my $tree = $self->_id_cache->get_by_additional_lookup('node_id', $node_id);
    unless ($tree) {
        my $sql = 'SELECT root_id FROM species_tree_node WHERE node_id = ?';
        $tree = $self->_id_cache->get_by_sql($sql, [$node_id])->[0];
    }
    return $tree;
}


########################
# Store/update methods #
########################

sub store {
    my ($self, $tree) = @_;
    
    my $mlss_id = $tree->method_link_species_set_id;

    my $species_tree_node_adaptor = $self->db->get_SpeciesTreeNodeAdaptor();

    # Store the nodes
    my $root_id = $species_tree_node_adaptor->store_nodes_rec($tree->root, $mlss_id);

    # Store the tree in the header table
    $self->generic_insert('species_tree_root', {
            'root_id'                       => $root_id,
            'method_link_species_set_id'    => $mlss_id,
            'label'                         => ($tree->label || 'default'),
        } );

    # Register the new object
    $self->_id_cache->put($root_id, $tree);
    $self->attach($tree, $root_id);

    return $root_id;
}


############################################################
# Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor implementation #
############################################################

sub _columns {
    return qw ( str.root_id
                str.method_link_species_set_id
                str.label
             );
}

sub _tables {
    return (['species_tree_root','str']);
}

sub _objs_from_sth {
    my ($self, $sth) = @_;
    return $self->generic_objs_from_sth($sth, 'Bio::EnsEMBL::Compara::SpeciesTree', [
            '_root_id',
            '_method_link_species_set_id',
            '_label',
        ] );
}


################################################################
# Bio::EnsEMBL::Compara::DBSQL::BaseFullAdaptor implementation #
################################################################


sub _build_id_cache {
    my $self = shift;
    return Bio::EnsEMBL::Compara::DBSQL::Cache::SpeciesTree->new($self);
}

# FullIdCache expects each object to associate a single value to each
# lookup key. Here we'd like to register many node_ids for each tree.
# We should be reimplementing remove_from_additional_lookup as well.
sub _add_to_node_id_lookup {
    my ($self, $tree) = @_;
    my $additional_lookup = $self->_id_cache->_additional_lookup();
    foreach my $node (@{$tree->root->get_all_nodes}) {
        push(@{$additional_lookup->{'node_id'}->{$node->node_id}}, $tree->root_id);
    }
}



package Bio::EnsEMBL::Compara::DBSQL::Cache::SpeciesTree;

use base qw/Bio::EnsEMBL::DBSQL::Support::FullIdCache/;
use strict;
use warnings;

sub compute_keys {
    my ($self, $tree) = @_;
    return {
        'mlss_id'       => $tree->method_link_species_set_id,
        'mlss_id_label' => $tree->method_link_species_set_id.'____'.(lc $tree->label),
    }
}

1;
