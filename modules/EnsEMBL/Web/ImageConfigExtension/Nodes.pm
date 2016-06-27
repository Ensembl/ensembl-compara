=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ImageConfigExtension::Nodes;

### An Extension to EnsEMBL::Web::ImageConfig
### Methods to create/append/remove/rearrange nodes of the config tree

package EnsEMBL::Web::ImageConfig;

use strict;
use warnings;

# Delete all tracks where menu = no, and parent nodes if they are now empty
sub remove_disabled_menus {
  my ($self, $node) = @_;
  
  if (!$node) {
    $_->remove for grep $_->get('menu') eq 'no', $self->tree->leaves;
    $self->remove_disabled_menus($_) for $self->tree->nodes;
    return;
  }
  
  if ($node->get('node_type') !~ /^(track|option)$/ && !$node->has_child_nodes) {
    my $parent = $node->parent_node;
    $node->remove;
    $self->remove_disabled_menus($parent) if $parent && !scalar @{$parent->child_nodes};
  }
}

# create_menus - takes an array to configure the menus to be seen on the display
sub create_menus {
  my $self = shift;
  my $tree = $self->tree;

  foreach (@_) {
    my $menu = $self->menus->{$_};   
    if (ref $menu) {
      my $parent = $tree->get_node($menu->[1]) || $tree->append_child($self->create_submenu($menu->[1], $self->menus->{$menu->[1]}));
      $parent->append_child($self->create_submenu($_, $menu->[0]));
    } else {
      $tree->append_child($self->create_submenu($_, $menu));
    }
  }
}

sub create_submenu {
  my ($self, $code, $caption, $options) = @_;
  
  my $details = {
    caption    => $caption, 
    node_type  => 'menu',
    %{$options || {}}
  };
  
  return $self->tree->create_node($code, $details);
}

sub create_track {
  my ($self, $code, $caption, $options) = @_;
  
  my $details = { 
    name      => $caption,
    node_type => 'track',
    %{$options || {}}
  };
  
  $details->{'strand'}    ||= 'b';      # Make sure we have a strand setting
  $details->{'display'}   ||= $details->{'default_style'} || 'normal'; # Show unless we explicitly say no
  $details->{'renderers'} ||= [qw(off Off normal On)];
  $details->{'colours'}   ||= $self->species_defs->colour($options->{'colourset'}) if exists $options->{'colourset'};
  $details->{'glyphset'}  ||= $code;
  $details->{'caption'}   ||= $caption;
  
  return $self->tree->create_node($code, $details);
}

sub add_track { shift->add_tracks(shift, \@_); }

sub add_tracks {
  my $self     = shift;
  my $menu_key = shift;
  my $menu     = $self->get_node($menu_key);

  return unless $menu;

  foreach my $row (@_) {
    my ($key, $caption, $glyphset, $params) = @$row;
    my $node = $self->get_node($key);

    next if $node && $node->get('node_type') eq 'track';

    $params->{'glyphset'} = $glyphset;
    $menu->append($self->create_track($key, $caption, $params));
  }
}

sub create_option {
  my ($self, $code, $caption, $values, $renderers, $display) = @_;
  
  $values    ||= { off => 0, normal => 1 };
  $renderers ||= [ 'off', 'Off', 'normal', 'On' ];
  
  return $self->tree->create_node($code, {
    node_type => 'option',
    caption   => $caption,
    name      => $caption,
    values    => $values,
    renderers => $renderers,
    display   => $display || 'normal'
  });
}

sub add_option {
  my $self = shift;
  my $menu = $self->get_node('options');
  
  return unless $menu;
  
  $menu->append($self->create_option(@_));
}

sub add_options {
  my $self = shift;
  my $menu = $self->get_node(ref $_[0] ? 'options' : shift);
  
  return unless $menu;
  
  $menu->append($self->create_option(@$_)) for @_;
}

sub get_option {
  my ($self, $code, $key) = @_;
  my $node = $self->get_node($code);
  return $node ? $node->get($key || 'values')->{$node->get('display')} : 0;
}

# Order submenus alphabetically by caption
sub alphabetise_tracks {
  my ($self, $track, $menu, $key) = @_;
  $key ||= 'caption';
  
  my $name = $track->data->{$key};
  my ($after, $node_name);

  if (scalar(@{$menu->child_nodes}) > 1) {  
    foreach (@{$menu->child_nodes}) {
      $node_name = $_->data->{$key};
      $after     = $_ if $node_name && $node_name lt $name;
    }
    if ($after) {
      $after->after($track);
    } else {
      $menu->prepend_child($track);
    }
  }
  else {
    $menu->append_child($track);
  }
}

1;
