=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Configuration;

use strict;

use EnsEMBL::Web::Tree;

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $page, $hub, $builder, $data) = @_;
  
  my $self = {
    page      => $page,
    hub       => $hub,
    builder   => $builder,
    object    => $builder->object,
    _data     => $data,
    cl        => {}
  };
  
  bless $self, $class;
  
  $self->init;
  $self->add_external_browsers;
  $self->modify_tree;
  $self->set_default_action;
  my $assume_valid = 0;
  $assume_valid = 1 if($hub->script eq 'Component');
  $self->set_action($hub->action, $hub->function,$assume_valid);
  $self->modify_page_elements;
  
  return $self;
}

# Get configurable components from a specific action/function combination
sub new_for_components {
  my ($class, $hub, $action, $function) = @_;

  my $self = {
    hub   => $hub,
    _data => {},
  };
  
  bless $self, $class;
  
  $self->init;
  $self->modify_tree;
  
  return $self->get_configurable_components(undef, $action, $function);
}

sub has_tabs          { return 0; } ## Does a page of this type normally have tabs?
sub default_template {}

sub init {
  my $self       = shift;
  my $hub        = $self->hub;
  my $cache      = $hub->cache;
  my $user_tree  = $self->user_tree && ($hub->user || $hub->session);
  my $cache_key  = $self->tree_cache_key;
  my $tree       = $cache->get($cache_key) if $cache && $cache_key; # Try to get default tree from cache

  if ($tree) {
    $self->{'_data'}{'tree'} = $tree;
  } else {
    $self->{'_data'}{'tree'} = EnsEMBL::Web::Tree->new;
    $self->create_node('Unknown', '',
            [qw(
              404  EnsEMBL::Web::Component::404
            )],
            { 'availability' => 1, 'no_menu_entry' => 1 }
    );
    $self->populate_tree; # If no user + session tree found, build one
    $cache->set($cache_key, $self->{'_data'}{'tree'}, undef, 'TREE') if $cache && $cache_key; # Cache default tree
  }

  $self->user_populate_tree if $user_tree;
}

sub populate_tree         {}
sub modify_tree           {}
sub add_external_browsers {}
sub modify_page_elements  {}
sub caption               {}

sub hub            { return $_[0]->{'hub'};                                   }
sub builder        { return $_[0]->{'builder'};                               }
sub object         { return $_[0]->{'object'};                                }
sub page           { return $_[0]->{'page'};                                  }
sub tree           { return $_[0]->{'_data'}{'tree'};                         }
sub configurable   { return $_[0]->{'_data'}{'configurable'};                 }
sub action         { return $_[0]->{'_data'}{'action'};                       }
sub default_action { return $_[0]->{'_data'}{'default'};                      } # Default action for feature type
sub species        { return $_[0]->hub->species;                              }
sub type           { return $_[0]->hub->type;                                 }
sub short_caption  { return sprintf '%s-based displays', ucfirst $_[0]->type; } # return the caption for the tab
sub user_tree      { return 0;                                                }

sub set_default_action {  
  my $self = shift; 
  $self->{'_data'}->{'default'} = $self->object->default_action if $self->object;
}

sub set_action {
  my $self = shift;
  $self->{'_data'}{'action'} = $self->get_valid_action(@_);
}

sub add_form {
  my ($self, $panel, @T) = @_; 
  $panel->add_form($self->page, @T);
}

sub get_availability {
  my $self = shift;
  my $hub = $self->hub;

  my $hash = { map { ('database:'. lc(substr $_, 9) => 1) } keys %{$hub->species_defs->databases} };
  $hash->{'database:compara'} = 1 if $hub->species_defs->compara_like_databases;
  $hash->{'logged_in'}        = 1 if $hub->user;

  return $hash;
}

# Each class might have different tree caching dependences 
# See Configuration::Account and Configuration::Search for more examples
sub tree_cache_key {
  my ($self, $user, $session) = @_;
  
  my $key = join '::', ref $self, $self->species, 'TREE';

  $key .= '::USER['    . $user->id            . ']' if $user;
  $key .= '::SESSION[' . $session->session_id . ']' if $session && $session->session_id;
  
  return $key;
}

sub get_valid_action {
  my ($self, $action, $function,$assume_valid) = @_;
  
  my $object   = $self->object;
  my $hub      = $self->hub;
  my $tree     = $self->tree;
  my $node_key = join '/', grep $_, $action, $function;
  my $node     = $tree->get_node($node_key);

  if (!$node) {
    $node     = $tree->get_node($action);
    $node_key = $action;
  }
  if ($node && !$assume_valid) {
    $self->{'availability'} = $object->availability if $object;
    unless ($node->get('type') =~ /view/ && $self->is_available($node->get('availability'))) {
      $node = $tree->get_node('Unknown');
    }
  }
  elsif (!$node) {
    $node = $tree->get_node('Unknown');
  }
  return $node->id;
}

sub get_node { 
  my ($self, $code) = @_;
  return $self->tree->get_node($code);
}

sub query_string {
  my $self   = shift;
  
  my %parameters = (%{$self->hub->core_params}, @_);
  my @query_string = map "$_=$parameters{$_}", grep defined $parameters{$_}, sort keys %parameters;
  
  return join ';', @query_string;
}

sub create_node {
  my ($self, $code, $caption, $components, $options) = @_;
 
  my $details = {
    caption    => $caption,
    components => $components,
    code       => $code,
    type       => 'view',
    %{$options || {}}
  };

  $details->{'availability'} = 1 if $details->{'type'} =~ /view/ && !defined $details->{'availability'};
  
  return $self->tree->root->append_child($self->tree->create_node($code, $details));
}

sub insert_node_after {
  my ($self, $node, $code, $caption, $components, $options) = @_;

  my $details = {
    caption    => $caption,
    components => $components,
    code       => $code,
    type       => 'view',
    %{$options || {}}
  };

  $details->{'availability'} = 1 if $details->{'type'} =~ /view/ && !defined $details->{'availability'};

  return $self->tree->root->insert_after($self->tree->create_node($code, $details), $node);
}

sub create_subnode {
  my $self  = shift;
  $_[3]{'type'} = 'subview';
  return $self->create_node(@_,);
}

sub create_submenu {
  my $self = shift;
  splice @_, 2, 0, undef;
  $_[3]{'type'} = 'menu';
  return $self->create_node(@_);
}

sub delete_node {
  my ($self, $code) = @_;
  my $node = $self->tree->get_node($code);
  $node->remove if $node;
}

sub get_configurable_components {
  my ($self, $node, $action, $function) = @_;
  my $hub       = $self->hub;
  my $component = $hub->script eq 'Config' ? $hub->action : undef;
  my @components;
  
  if ($component && !$action) {
    my $type        = [ split '::', ref $self ]->[-1];
    my $module_name = $self->get_module_names('ViewConfig', $type, $component);
       @components  = ([ $component, $type ]) if $module_name;
  } else {
    if (!$node) {
      if (my $node_id = $self->get_valid_action($action || $hub->action, $function || $hub->function)) {
        $node = $self->get_node($node_id);
      }
    }

    if ($node) {
      my @all_components = reverse @{$node->get_data('components')};
      
      for (my $i = 0; $i < $#all_components; $i += 2) {
        my ($p, $code)  = map $all_components[$_], $i, $i + 1;
        my @package     = split '::', $p;
        my ($component) = split '/', $package[-1];
        my $module_name = $self->get_module_names('ViewConfig', $package[-2], $component);
        push @components, [ $component, $package[-2], $code ] if $module_name;
      }
    }
  }
  
  return \@components;
}

sub user_populate_tree {}

1;
