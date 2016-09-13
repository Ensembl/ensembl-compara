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

sub create_menu_node {
  ## Creates a menu node (not yet attached to the main tree)
  ## @return TreeNode object
  ## @param Menu node key/id
  ## @param Caption for the menu
  ## @param Hashref of any other details to be saved as track 'data'
  my ($self, $menu_key, $caption, $options) = @_;

  $options ||= {};
  $options->{'caption'}   = $caption;
  $options->{'node_type'} = 'menu';

  return $self->tree->create_node($menu_key, $options);
}

sub add_menus {
  ## Adds menus to the display for image config (creates menu nodes and append them to the tree)
  ## @params List of menu keys (as present in keys in 'menu' method)
  ## @return Number of menu nodes added
  my $self  = shift;
  my $tree  = $self->tree;
  my $root  = $tree->root;
  my $menus = $self->menus;
  my $count = 0;

  foreach my $menu_key (@_) {

    my ($caption, $parent_key) = $menus->{$menu_key} && ref $menus->{$menu_key} ? @{$menus->{$menu_key}} : ($menus->{$menu_key});

    throw WebException("No menu entry found for $parent_key") if $parent_key && !$menus->{$parent_key};

    my $parent_node = $parent_key ? $tree->get_node($parent_key) || $root->append_child($self->create_menu_node($parent_key, $menus->{$parent_key})) : $root;

    $parent_node->append_child($self->create_menu_node($menu_key, $caption || ''));

    $count++;
  }

  return $count;
}

sub create_track_node {
  ## Creates a track node (not yet attached to the main tree)
  ## @param Track node key/id
  ## @param Name for the track
  ## @param Hashred of any other details to be saved as track 'data'
  my ($self, $track_key, $name, $data) = @_;

  $data ||= {};

  $data->{'node_type'}    = 'track';
  $data->{'name'}       ||= $name;
  $data->{'strand'}     ||= 'b';                                  # Make sure we have a strand setting
  $data->{'display'}    ||= $data->{'default_style'} || 'normal'; # Show unless we explicitly say no
  $data->{'renderers'}  ||= [qw(off Off normal On)];
  $data->{'colours'}    ||= $self->species_defs->colour($data->{'colourset'}) if exists $data->{'colourset'};
  $data->{'glyphset'}   ||= $track_key;
  $data->{'caption'}    ||= $name;

  return $self->tree->create_node($track_key, $data);
}

sub add_track {
  ## Adds a single track to the config
  ## @param Parent menu node's key
  ## @param Track key
  ## @param Track name
  ## @param Name of the Glyphset to be used
  ## @param Hashref of track data
  ## @return 1 if added successfully, 0 otherwise
  return shift->add_tracks(shift, \@_);
}

sub add_tracks {
  ## Adds multiple tracks to the config (creates track node and appends it to it parent menu)
  ## @param Parent menu's key
  ## @params List of arrayref [ track key, track name, glyphset, { track data } ], .., one for each track
  ## @return Number of tracks added
  my $self      = shift;
  my $menu_key  = shift;
  my $menu      = $self->get_node($menu_key);
  my $count     = 0;

  if ($menu) {
    foreach my $track_details (@_) {
      my ($track_key, $name, $glyphset, $data) = @$track_details;
      my $node = $self->get_node($track_key);

      next if $node && $node->get_data('node_type') eq 'track';
      $data->{'glyphset'} = $glyphset;
      $menu->append_child($self->create_track_node($track_key, $name, $data));
      $count++;
    }
  }

  return $count;
}

sub create_option_node {
  ## Creates an option node (not yet attached to the main tree)
  ## An option node is just a node that appears as a 'renderer' icon and can be configured by user by clicking it - it just doesn't have a linked track
  ## @param Node key
  ## @param Caption for the option
  ## @param Default display option (has to be one among the keys 'renderers')
  ## @param Hashref of map of renderer values and actual values
  ## @param Renderers for the option (hash in an arrayref syntax to maintain order) - they decide what icons to be displayed for the option
  ## @param Data hash (optional)
  my ($self, $option_key, $caption, $display, $values, $renderers, $data) = @_;

  $data       ||= {};
  $values     ||= { 'off' => 0,     'normal'  => 1    };
  $renderers  ||= [ 'off' => 'Off', 'normal'  => 'On' ];
  $display    ||= $renderers->[2];

  $data->{'node_type'} = 'option';
  $data->{'caption'}   = $caption;
  $data->{'name'}      = $caption;
  $data->{'values'}    = $values;
  $data->{'renderers'} = $renderers;
  $data->{'display'}   = $display;

  return $self->tree->create_node($option_key, $data);
}

sub add_option {
  ## Adds an option to default options menu or any given menu key in the tree
  ## @params Parent menu key plus list of arguments as accepted by create_option_node method
  ## @return 1 if added successfully, 0 otherwise
  return shift->add_options(shift, \@_);
}

sub add_options {
  ## Adds options to default options menu or any given menu key in the tree
  ## @param Parent menu key
  ## @params List of arrayref - one for each option to be added - each arrayref to be arguments as accepted by create_option_node
  ## @return Number of option nodes added
  my $self    = shift;
  my $parent  = $self->get_node(shift);

  return $parent ? scalar @{$parent->append_children(map $self->create_option_node(@$_), @_)} : 0;
}

sub get_option_value {
  ## Gets the value (set by user) of the option node
  ## @param Key name to retrieve the option node
  my ($self, $option_key) = @_;
  my $option_node = $self->get_node($option_key);
  return $option_node && $option_node->get_data('values')->{$option_node->get('display')} || 0;
}

sub create_menus        :Deprecated('Use add_menus')                        { return shift->add_menus(@_);                        } # keeping same as add_tracks, add_options etc
sub create_submenu      :Deprecated('Use create_menu_node')                 { return shift->create_menu_node(@_);                 } # it's not really a submenu, but a menu node
sub create_track        :Deprecated('Use create_track_node')                { return shift->create_track_node(@_);                } # just being explicit
sub create_option       :Deprecated('Use create_option_node')               { return shift->create_option_node(@_);               } # just being explicit
sub get_option          :Deprecated('Use get_option_value')                 { return shift->get_option_value(@_);                 } # it doesn't give you option object, but it's value
sub alphabetise_tracks  :Deprecated('Use TreeNode::insert_alphabetically')  { return $_[2]->insert_alphabetically($_[1], $_[2]);  } # it doesn't belong here

1;
