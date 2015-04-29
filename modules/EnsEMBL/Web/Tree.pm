=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Tree;

use base qw(EnsEMBL::Web::DOM::Node::Element::Generic);

use strict;

use Data::Dumper; # Actually used: not just left behind.

sub new {
  my ($class, $dom, $args) = @_;
  my $self = $class->SUPER::new($dom);
  
  $self->{'id'}        = 'aaaa';
  $self->{'data'}      = {};
  $self->{'user_data'} = {};
  $self->{'tree_ids'}  = {}; # A complete list of unique identifiers in the tree, and their nodes
  $self->{$_}          = $args->{$_} for keys %{$args || {}}; # Overwrites the values above
  
  $self->{'tree_ids'}{$self->{'id'}} = $self;
  
  return $self;
}

sub id          { return $_[0]->{'id'};                }
sub data        { return $_[0]->{'data'};              }
sub user_data   { return $_[0]->{'user_data'};         }
sub tree_ids    { return $_[0]->{'tree_ids'};          }
sub parent_key  { return $_[0]->parent_node->id;       }
sub nodes       { return @{$_[0]->get_all_nodes};      }
sub descendants { return $_[0]->nodes;                 }
sub is_leaf     { return !$_[0]->has_child_nodes;      }
sub previous    { return $_[0]->previous_sibling;      }
sub next        { return $_[0]->next_sibling;          }
sub append      { return $_[0]->append_child($_[1]);   }
sub prepend     { return $_[0]->prepend_child($_[1]);  }
sub _flush_tree { $_[0]->{'user_data'} = {};           } # TODO: rename to flush_tree - called on Configuration tree in Document::Element::Configurator

sub get_node {
  my ($self, $id) = @_;
  return $self->tree_ids->{$self->clean_id($id)};
}

sub flush_user {
  ### Remove all user data in this tree
  
  my $self   = shift;
  my $return = 0;
  
  foreach ($self, $self->nodes) {
    $return ||= scalar keys %{$_->{'user_data'}} ? 1 : 0;
    $_->{'user_data'} = {};
  }
  
  return $return;
}

# Better than setting and resetting because it keeps the same reference
# when revealed which other objects may have cached.
sub hide_user_data {
  my $self = shift;
  foreach ($self,$self->nodes) {
    $_->{'hidden_user_data'} = $_->{'user_data'} unless exists $_->{'hidden_user_data'};
    $_->{'user_data'} = {};
  }
  return $self;
}

sub reveal_user_data {
  my ($self,$src) = @_;
  foreach ($self,$self->nodes) {
    $_->{'user_data'} = $_->{'hidden_user_data'} || {};
    delete $_->{'hidden_user_data'};
  }
}

sub push_user_data_through_tree {
  my ($self,$data) = @_;

  foreach ($self,$self->nodes) {
    $_->{'user_data'} = $data;
  }
}

sub generate_unique_id {
  my $self = shift;
  $self->{'id'}++ while exists $self->tree_ids->{$self->{'id'}};
  return $self->{'id'};
}

sub clean_id {
  my $match = $_[2] || '[^\w-]';
  $_[1] =~ s/$match/_/g;
  return $_[1];
}

sub create_node {
  ### Node is always created as a "root" node - needs to be appended to another node to make it part of another tree.
  
  my ($self, $id, $data) = @_;
  $id = $id ? $self->clean_id($id) : $self->generate_unique_id;
  
  if (exists $self->tree_ids->{$id}) {
    my $node = $self->get_node($id);
    
    if ($data) {
      $node->data->{$_} = $data->{$_} for keys %$data;
    }
    
    return $node;
  }
  
  return EnsEMBL::Web::Tree->new($self->dom, {
    id        => $id,
    data      => $data || {},
    user_data => $self->user_data,
    tree_ids  => $self->tree_ids,
  });
}

sub leaves {
  my $self = shift;
  my @nodes;
  push @nodes, $self if !$self->has_child_nodes && @_ && shift;
  push @nodes, $_->leaves(1) for @{$self->child_nodes};
  return @nodes;
}

sub get {
  ### Returns user value if defined - otherwise returns value from data
  
  my $self      = shift;
  my $key       = shift;
  my $user_data = $self->user_data;
  my $id        = $self->id;
  
  return $user_data && exists $user_data->{$id} && exists $user_data->{$id}->{$key} ? $user_data->{$id}->{$key} : $self->data->{$key};
}

sub set {
  my $self  = shift;
  my $key   = shift;
  my $value = shift;
  $self->data->{$key} = $value;
}

sub set_user {
  ### Set user data for node
  
  my $self  = shift;
  my $key   = shift;
  my $value = shift;
  my $id    = $self->id;
  
  # If same as default value - flush node
  if ($value eq $self->data->{$key}) {
    delete $self->user_data->{$id}->{$key};
    delete $self->user_data->{$id} unless scalar %{$self->user_data->{$id}};
    return 1;
  }
  
  # If not same as current value set and return true
  if ($value ne $self->user_data->{$id}->{$key}) {
    $self->user_data->{$id}->{$key} = $value;
    return 1; 
  }
  
  return 0; # Return false - not updated
}

sub clear_references {
  my $self = shift;
  delete $self->{'tree_ids'}{$_} for keys %{$self->{'tree_ids'}};
  $_->clear_references for @{$self->child_nodes};
  $self->remove_children;
}

sub dump {
  ### Dumps the contents of the tree to standard out
  ### Takes two parameters - "$title" - displayed in the error log
  ### and "$template" a template used to display attributes of the node
  ### attribute keys bracketed with "[[""]]" e.g. 
  ###
  ###  * "[[name]]"
  ###  * "[[name]] - [[description]]"
  ###
  ### $indent starts as 0 and is set automatically by recursion
  
  my ($self, $title, $template, $indent) = @_;

  if (!$indent) {
    warn "\n";
    warn "================================================================================================================================\n";
    warn sprintf "==  %-120.120s  ==\n", $title;
    warn "================================================================================================================================\n";
    warn " children                                                $template\n";
    warn "--------------------------------------------------------------------------------------------------------------------------------\n";
  }
  
  foreach my $n (@{$self->child_nodes}) {
    (my $map = $template) =~ s/\[\[(\w+)\]\]/$n->get($1)/eg;
    
    my $children = scalar @{$n->child_nodes};
    $children    = $children ? sprintf('%4d', $children) : '    ';
    
    warn sprintf "%s %-50.50s %s\n", $children, '  ' x $indent . $n->id, $map;
    
    $n->dump($title, $template, $indent + 1);
  }
  
  if (!$indent) {
    warn "================================================================================================================================\n";
    warn "\n";
  }
}

sub _debug_part {
  my ($self,$key,$data,$depth) = @_;
  local $Data::Dumper::Indent = 0;

  my $out = '';
  foreach my $k (keys %$data) {
    my $val = Dumper($data->{$k});
    $val =~ s/^\$VAR\d+\s*=\s+//;
    $val =~ s/^(.{40}).+$/$1.../;
    $out .= ('  ' x $depth)."$key $k = $val\n";
  }
  return $out;
}

sub debug {
  my ($self,$depth) = @_;

  my $out = $self->_debug_part('*',{ id => $self->{'id'}},$depth||0).
            $self->_debug_part('+',$self->{'user_data'},  $depth||0).
            $self->_debug_part('-',$self->{'data'},       $depth||0);
  $out .= $_->debug(($depth||0)+1) for(@{$self->child_nodes});
  return $out;
}

1;
