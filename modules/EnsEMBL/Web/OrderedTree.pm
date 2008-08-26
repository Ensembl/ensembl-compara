package EnsEMBL::Web::OrderedTree;

use EnsEMBL::Web::OrderedTree::Node;

use strict;

sub new {
  my( $class ) = @_;
  my $self = { '_tree_info' => { 'nodes' => {}, '_sorted_keys' => [] } };
  bless $self, $class;
  return $self;
}

sub _node        { return EnsEMBL::Web::OrderedTree::Node::_node(        @_ ); }
sub _nodes       { return EnsEMBL::Web::OrderedTree::Node::_nodes(       @_ ); }
sub get_node     { return EnsEMBL::Web::OrderedTree::Node::get_node(     @_ ); }
sub _sorted_keys { return EnsEMBL::Web::OrderedTree::Node::_sorted_keys( @_ ); }

our $KEY = 'aaaa';
sub _generate_unique_key() {
### Generate a unique key ...
  my $self = shift;
  $KEY++ while exists( $self->{'_tree_info'}{'nodes'}{$KEY} );
  return $KEY;
}

sub create_node {
### Creates a new EnsEMBL::Web::OrderedTree::Node with key given by the first param, and the second is a hashref
### of values to store in the node.
### If $key is "undef" then generate a "unique" key
### Node is always created as a "root" node - needs to be "append"ed to another node to make it part of another tree.

  my( $self, $key, $data ) = @_;
  $data ||= {};
  $key ||= $self->_generate_unique_key();
  warn "DUPLICATE KEY $key" if exists( $self->{'_tree_info'}{'nodes'}{$key} );
  return undef if exists( $self->{'_tree_info'}{'nodes'}{$key} );
  my $right = (keys %{$self->{_tree_info}{nodes}}) * 2;
  $self->{'_tree_info'}{'nodes'}{$key} = {
    'left' => $right+1, 'right' => $right+2,
    'parent_key' => '', 'data' => $data
  };
  $self->{'_tree_info'}{'_sorted_keys'} = [];
  return EnsEMBL::Web::OrderedTree::Node->new({ '_key' => $key, '_tree_info' => $self->{_tree_info} });
}

sub nodes {
### Returns an array of nodes from the tree in L-R order..
  my $self = shift;
  return map { $self->get_node( $_ ) } $self->_sorted_keys;
}

sub leaves {
### Returns array of nodes in L-R order that are leaves [ right = left+1 ]
  my $self = shift;
  return map { $self->get_node( $_ ) } grep { $self->_node($_)->{right} == $self->_node($_)->{left}+1 } $self->_sorted_keys;
}

sub leaf_codes {
### Returns array of codes of leaves...
  my $self = shift;
  return grep { $self->_node($_)->{right} == $self->_node($_)->{left}+1 } $self->_sorted_keys;
}

sub dump {
### Dumpes the contents of the tree to standard out...
### Takes two parameters - "$title" - displayed in the error log
### and "$temp" a template used to display attributes of the node.. 
### attribute keys bracketed with "[[""]]" e.g. 
###
###  * "[[name]]"
###  * "[[name]] - [[description]]"
###
  my ($self,$title,$temp) = @_;

  my $indent = 0;
  my $right  = 0;
  warn "\n";
  warn "================================================================================================================================\n";
  warn sprintf "==  %-120.120s  ==\n", $title;
  warn "================================================================================================================================\n";
  warn "   l    r kids                                                    $temp\n";
  warn "--------------------------------------------------------------------------------------------------------------------------------\n";
  foreach my $n ( $self->nodes ) {
    if( $n->right < $right ) {
      $indent+=1;
    } else {
      $indent -= $n->left-$right-1;
    }
    $right = $n->right;
    ( my $map = $temp ) =~ s/\[\[(\w+)\]\]/$n->get($1)/eg;
    my $kids = ($n->right-$n->left-1)/2;
    $kids = $kids ? sprintf( '%4d', $kids ) : '    ';
    warn sprintf "%4d %4d %s %-50.50s %s\n", $n->left, $n->right, $kids,'  'x$indent.$n->key, $map;
  }
  warn "================================================================================================================================\n";
  warn "\n";
}

1;

