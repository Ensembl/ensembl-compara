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

Bio::EnsEMBL::Compara::GeneTree

=head1 DESCRIPTION

Class to represent a gene tree object. Contains a link to
the root of the tree, as long as general tree properties.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::GeneTree
  `- Bio::EnsEMBL::Compara::Taggable

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

package Bio::EnsEMBL::Compara::GeneTree;

use strict;
no strict 'refs';

use base ('Bio::EnsEMBL::Compara::Taggable');

#our $AUTOLOAD;

=head2 new()

  Description : Creates a new GeneTree object. 
  Returntype  : Bio::EnsEMBL::Compara::GeneTree
  Exceptions  : None
  Example     : my $w = Bio::EnsEMBL::Compara::GeneTree->new();
  Status      : Stable  
  
=cut

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}


=head2 DESTROY()

  Description : Deletes the reference to the root node and breaks
                the circular reference.
  Returntype  : None
  Exceptions  : None
  Status      : System
  
=cut

sub DESTROY {
    my $self = shift;
    delete $self->{'_root'};
}


=head2 tree_type()

  Description : Getter/Setter for the tree_type field. This field can
                currently be 'tree', 'supertree' or 'clusterset'
  Returntype  : String
  Exceptions  : None
  Example     : my $type = $tree->tree_type();
  Status      : Stable  
  
=cut

sub tree_type {
    my $self = shift;
    $self->{'_tree_type'} = shift if(@_);
    return $self->{'_tree_type'};
}


=head2 member_type()

  Description : Getter/Setter for the member_type field. This field can
                currently be 'ncrna' or 'protein'
  Returntype  : String
  Exceptions  : None
  Example     : my $type = $tree->member_type();
  Status      : Stable  
  
=cut

sub member_type {
    my $self = shift;
    $self->{'_member_type'} = shift if(@_);
    return $self->{'_member_type'};
}


sub clusterset_id {
    my $self = shift;
    $self->{'_clusterset_id'} = shift if(@_);
    return $self->{'_clusterset_id'};
}


=head2 method_link_species_set_id()

  Description : Getter/Setter for the method_link_species_set_id field.
                This field should be a valid dbID of a MethodLinkSpeciesSet
                object.
  Returntype  : Integer
  Exceptions  : None
  Example     : $tree->method_link_species_set_id($mlss_id);
  Status      : Stable  
  
=cut

# FIXME MLSS Object
sub method_link_species_set_id {
    my $self = shift;
    $self->{'_method_link_species_set_id'} = shift if(@_);
    return $self->{'_method_link_species_set_id'};
}


=head2 stable_id()

  Description : Getter/Setter for the stable_id field. Currently, only the
                'proteintree' have a stable id. This field should be empty
                for other tree types.
  Returntype  : String
  Exceptions  : None
  Example     : my $stable_id = $tree->stable_id();
  Status      : Stable  
  
=cut

sub stable_id {
    my $self = shift;
    $self->{'_stable_id'} = shift if(@_);
    return $self->{'_stable_id'};
}


=head2 version()

  Description : Getter/Setter for the version field. It contains the numeric
                version of a tree which keeps an identical stable id (when
                members are removed / added)
  Returntype  : Numeric
  Exceptions  : None
  Example     : my $version = $tree->version();
  Status      : Stable  
  
=cut

sub version {
    my $self = shift;
    $self->{'_version'} = shift if(@_);
    return $self->{'_version'};
}


=head2 root()

  Description : Getter/Setter for the root node of the tree. This is
                internally synchronised with the root_id() method and
                vice-versa to ensure consistency.
  Returntype  : Bio::EnsEMBL::Compara::GeneTreeNode
  Exceptions  : None
  Example     : my $root_node = $tree->root();
  Status      : Stable
  
=cut

sub root {
    my $self = shift;
    my $new = shift;
    if ($new) {
        #print "DEFINE root=$new IN $self\n";
        # defines the new root
        $self->{'_root'} = $new;
        #print "UPDATES $self for root_id\n";
        delete $self->{'_root_id'};
        $self->{'_root_id'} = $new->node_id unless ref($new->node_id);
    } 

    if (not defined $self->{'_root'} and defined $self->{'_root_id'} and defined $self->{'_adaptor'}) {
        #print "UPDATES $self for root\n";
        my $gtn_adaptor = $self->{'_adaptor'}->db->get_GeneTreeNodeAdaptor;
        $gtn_adaptor->{'_ref_tree'} = $self;
        $self->{'_root'} = $gtn_adaptor->fetch_tree_by_root_id($self->{'_root_id'});
        delete $gtn_adaptor->{'_ref_tree'};
    }
    $self->{'_root'}->tree($self) if $self->{'_root'};
    return $self->{'_root'};
}


=head2 adaptor()

  Description : Getter/Setter for the DB adaptor that is used for database
                queries. This field is automatically populated when the
                tree is queried.
  Returntype  : Bio::EnsEMBL::Compara::DBSQL::GeneTreeNodeAdaptor
  Exceptions  : None
  Example     : $tree->adaptor($genetree_adaptor);
  Status      : Internal
  
=cut

sub adaptor {
    my $self = shift;
    $self->{'_adaptor'} = shift if(@_);
    return $self->{'_adaptor'};
}


=head2 root_id()

  Description : Getter/Setter for the root_id of the root node of the tree.
                This is internally synchronised with the root() method and
                vice-versa to ensure consistency.
  Returntype  : Integer
  Exceptions  : None
  Example     : my $root_node_id = $tree->root_id();
  Status      : Stable
  
=cut

sub root_id {
    my $self = shift;
    my $new = shift;
    if ($new and ((not defined $self->{'_root_id'}) or ($self->{'_root_id'} ne $new))) {
        #print "DEFINES root_id=$new IN $self\n";
        # defines the new root_id
        $self->{'_root_id'} = $new;
        # should update the root object accordingly, but I prefer delaying the fetch_node_by_node_id
        delete $self->{'_root'};
    }
    if (not defined $self->{'_root_id'} and defined $self->{'_root'}) {
        $self->{'_root_id'} = $self->{'_root'}->node_id unless ref($self->{'_root'}->node_id);
    }
    return $self->{'_root_id'};
}

# sub get_SimpleAlign {
#     my $self = shift;
#     return $self->root->get_SimpleAlign(@_);
# }

# sub consensus_cigar_line {
#     my $self = shift;
#     return $self->root->consensus_cigar_line(@_);
# }


# sub release_tree {
#     my ($self) = @_;
#     $self->root->release_tree();
# }

# sub AUTOLOAD {
#     my $self = shift @_;
#     my $type = ref($self) or die "$self is not an object\n";
#     my $name = $AUTOLOAD;
#     $name =~ s/.*://;
#     $self->root->can($name) or die "$self can't $name\n";
#     $self->root->$name(@_);
# }



# Dynamic definition of functions to allow NestedSet methods work with GeneTrees
foreach my $func_name (qw(get_all_leaves_indexed get_all_leaves get_all_sorted_leaves
                          find_leaf_by_node_id find_leaf_by_name find_node_by_node_id node_id
                          find_node_by_name remove_nodes build_leftright_indexing flatten_tree
                          newick_simple_format newick_format nhx_format string_tree print_tree
                          get_all_nodes release_tree copy get_SimpleAlign consensus_cigar_line
                        )) {
    my $full_name = "Bio::EnsEMBL::Compara::GeneTree::$func_name";
    *$full_name = sub {
        my $self = shift;
        my $ret = $self->root->$func_name(@_);
        return $ret;
    };
#    print STDERR "REDEFINE $func_name\n";
}


1;

