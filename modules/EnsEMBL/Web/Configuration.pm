# $Id$

package EnsEMBL::Web::Configuration;

use strict;

use HTML::Entities qw(encode_entities);
use Time::HiRes qw(time);

use EnsEMBL::Web::Document::Panel;
use EnsEMBL::Web::Cache;
use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Root);

our $MEMD = new EnsEMBL::Web::Cache;

sub new {
  my ($class, $page, $hub, $builder, $common_conf) = @_;
  
  my $self = {
    page    => $page,
    hub     => $hub,
    builder => $builder,
    object  => $builder->object,
    _data   => $common_conf,
    cl      => {}
  };
  
  bless $self, $class;

  my $user       = $ENSEMBL_WEB_REGISTRY->get_user;
  my $session    = $ENSEMBL_WEB_REGISTRY->get_session;
  my $session_id = $session->get_session_id;
  my $user_tree  = $self->can('user_populate_tree') && ($user || $session_id);
  my $tree       = $user_tree && $MEMD && $self->tree_cache_key($user, $session) ? $MEMD->get($self->tree_cache_key($user, $session)) : undef; # Trying to get user + session version of the tree from cache
  
  if ($tree) {
    $self->{'_data'}{'tree'} = $tree;
  } else {
    $tree = $MEMD->get($self->tree_cache_key) if $MEMD && $self->tree_cache_key; # Try to get default tree from cache

    if ($tree) {
      $self->{'_data'}{'tree'} = $tree;
    } else {
      $self->populate_tree; # If no user + session tree found, build one
      
      $MEMD->set($self->tree_cache_key, $self->{'_data'}{'tree'}, undef, 'TREE') if $MEMD && $self->tree_cache_key; # Cache default tree
    }

    if ($user_tree) {
      $self->user_populate_tree;
      $MEMD->set($self->tree_cache_key($user, $session), $self->{'_data'}{'tree'}, undef, 'TREE', keys %{$ENV{'CACHE_TAGS'}||{}}) if $MEMD && $self->tree_cache_key($user, $session); # Cache user + session tree version
    }
  }
  
  $self->add_external_browsers;
  $self->modify_tree;
  $self->set_default_action;
  $self->set_action($ENV{'ENSEMBL_ACTION'}, $ENV{'ENSEMBL_FUNCTION'});
  $self->modify_page_elements;
  
  return $self;
}

sub populate_tree         {}
sub modify_tree           {}
sub add_external_browsers {}
sub modify_page_elements  {}

sub delete_tree   { my $self = shift; $self->tree->_flush_tree;              } 
sub hub           { return $_[0]->{'hub'};                                   }
sub builder       { return $_[0]->{'builder'};                               }
sub object        { return $_[0]->{'object'};                                }
sub page          { return $_[0]->{'page'};                                  }
sub tree          { return $_[0]->{'_data'}{'tree'};                         }
sub configurable  { return $_[0]->{'_data'}{'configurable'};                 }
sub action        { return $_[0]->{'_data'}{'action'};                       }
sub species       { return $_[0]->hub->species;                              }
sub type          { return $_[0]->hub->type;                                 }
sub short_caption { return sprintf '%s-based displays', ucfirst $_[0]->type; } # return the caption for the tab

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
  $hash->{'logged_in'} = 1 if $hub->user;

  return $hash;
}

# Each class might have different tree caching dependences 
# See Configuration::Account and Configuration::Search for more examples
sub tree_cache_key {
  my ($self, $user, $session) = @_;
  
  my $key = join '::', ref $self, $self->species, 'TREE';

  $key .= '::USER[' . $user->id . ']' if $user;
  $key .= '::SESSION[' . $session->get_session_id . ']' if $session && $session->get_session_id;
  
  return $key;
}

# Default action for feature type
sub default_action {
  my $self = shift;
  ($self->{'_data'}{'default'}) = $self->{'_data'}{'tree'}->leaf_codes unless $self->{'_data'}{'default'};
  return $self->{'_data'}{'default'};
}

sub get_valid_action {
  my ($self, $action, $func) = @_;
  my $object = $self->object;
  my $hub = $self->hub;  

  return $action if $action eq 'Wizard';
  
  my $node;
  
  $node = $self->tree->get_node($action. '/' . $func) if $func;
  $self->{'availability'} = $object ? $object->availability : {};

  return $action. '/' . $func if $node && $node->get('type') =~ /view/ && $self->is_available($node->get('availability'));
  
  $node = $self->tree->get_node($action) unless $node;
  
  return $action if $node && $node->get('type') =~ /view/ && $self->is_available($node->get('availability'));
  
  foreach ($self->default_action, 'Idhistory', 'Chromosome', 'Genome') {
    $node = $self->tree->get_node($_);
    
    if ($node && $self->is_available($node->get('availability'))) {
      $hub->problem('redirect', $hub->url({ action => $_ }));
      return $_;
    }
  }
  
  return undef;
}

sub get_node { 
  my ($self, $code) = @_;
  return $self->{'_data'}{'tree'}->get_node($code);
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
    %{$options||{}}
  };
  
  return $self->tree->create_node($code, $details) if $self->tree;
}

sub create_subnode {
  my ($self, $code, $caption, $components, $options) = @_;

  my $details = {
    caption    => $caption,
    components => $components,
    code       => $code,
    type       => 'subview',
    %{$options||{}},
  };

  return $self->tree->create_node($code, $details) if $self->tree;
}

sub create_submenu {
  my ($self, $code, $caption, $options) = @_;

  my $details = {
    caption => $caption,
    url     => '',
    type    => 'menu',
    %{$options||{}},
  };
  
  return $self->tree->create_node($code, $details) if $self->tree;
}

sub delete_node {
  my ($self, $code) = @_;
  if ($code && $self->tree) {
    my $node = $self->tree->get_node($code);
    $node->remove_node if $node;
  }
}

sub delete_submenu {
  my ($self, $code) = @_;
  if ($code && $self->tree) {
    my $node = $self->tree->get_node($code);
    $node->remove_subtree if $node;
  }
}

sub get_submenu {
  my ($self, $code) = @_;
  if ($code && $self->tree) {
    my $node = $self->tree->get_node($code);
    return $node if $node;
  }
}

# FIXME: Dead?
sub add_block {
  my $self = shift;
  return unless $self->page->can('menu') && $self->page->menu;
  
  my $flag = shift;
  $flag =~ s/#/($self->{'flag'} || '')/ge;
  
  $self->page->menu->add_block($flag, @_);
}

# FIXME: Dead?
sub delete_block {
  my $self = shift;
  return unless $self->page->can('menu') && $self->page->menu;
  
  my $flag = shift;
  $flag =~ s/#/$self->{'flag'}/g;
  $self->page->menu->delete_block($flag, @_);
}

# FIXME: Dead?
sub add_entry {
  my $self = shift;
  
  return unless $self->page->can('menu') && $self->page->menu;
  
  my $flag = shift;
  $flag =~ s/#/($self->{'flag'} || '')/ge;
  
  $self->page->menu->add_entry($flag, @_);
}

1;
