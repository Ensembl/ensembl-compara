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
sub _generate_random_key() {
  return $KEY++;
}

sub create_node {
  my( $self, $key, $data ) = @_;
  $key ||= $self->_generate_random_key();
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
  my $self = shift;
  return map { $self->get_node( $_ ) } $self->_sorted_keys;
}

sub leaves {
  my $self = shift;
  return map { $self->get_node( $_ ) } grep { $self->_node($_)->{right} == $self->_node($_)->{left}+1 } $self->_sorted_keys;
}

sub leaf_codes {
  my $self = shift;
  return grep { $self->_node($_)->{right} == $self->_node($_)->{left}+1 } $self->_sorted_keys;
}

1;

