# $Id$

package EnsEMBL::Web::Document::Element::PageNav;

# Container HTML for left sided navigation menu on dynamic pages 

use strict;

use HTML::Entities qw(encode_entities);
use URI::Escape    qw(uri_escape);

use base qw(EnsEMBL::Web::Document::Element::Navigation);

sub label_classes {
  return {
    'Configure this page' => 'config',
    'Manage your data'    => 'data',
    'Add your data'       => 'data',
    'Export data'         => 'export',
    'Bookmark this page'  => 'bookmark',
    'Share this page'     => 'share',
  };
}

sub modify_init {
  my ($self, $controller) = @_;
  my $hub        = $controller->hub;
  my $object     = $controller->object;
  my @components = @{$hub->components};
  my $session    = $hub->session;
  my $user       = $hub->user;
  my $has_data   = grep($session->get_data(type => $_), qw (upload url das)) || ($user && (grep $user->get_records($_), qw(uploads urls dases)));
  my $view_config;
     $view_config = $hub->get_viewconfig(@{shift @components}) while !$view_config && scalar @components;
  
  ## Set up buttons
  if ($view_config) {
    my $component = $view_config->component;

    $self->add_button({
      caption => 'Configure this page',
      class   => 'modal_link',
      rel     => "modal_config_$component",
      url     => $hub->url('Config', {
        type      => $view_config->type,
        action    => $component,
        function  => undef,
      })
    });
  } else {
    $self->add_button({
      caption => 'Configure this page',
      class   => 'disabled',
      url     => undef,
      title   => 'There are no options for this page'
    });
  }
  
  my %data;
  
  $self->add_button({
    caption => $has_data ? 'Manage your data' : 'Add your data',
    class   => 'modal_link',
    rel     => 'modal_user_data',
    url     => $hub->url({
      time    => time,
      type    => 'UserData',
      action  => $has_data ? 'ManageData' : 'SelectFile',
      __clear => 1
    })
  });

  if ($object && $object->can_export) {
    $self->add_button({
      caption => 'Export data',
      class   => 'modal_link',
      url     => $self->_export_url($hub)
    });
  } else {
    $self->add_button({
      caption => 'Export data',
      class   => 'disabled',
      url     => undef,
      title   => 'You cannot export data from this page'
    });
  }

  if ($hub->user) {
    my $title = $controller->page->title;

    $self->add_button({
      caption => 'Bookmark this page',
      class   => 'modal_link',
      url     => $hub->url({
        type        => 'Account',
        action      => 'Bookmark/Add',
        __clear     => 1,
        name        => uri_escape($title->get_short),
        description => uri_escape($title->get),
        url         => uri_escape($hub->species_defs->ENSEMBL_BASE_URL . $hub->url)
      })
    });
  } else {
    $self->add_button({
      caption => 'Bookmark this page',
      class   => 'disabled',
      url     => undef,
      title   => 'You must be logged in to bookmark pages'
    });
  }

  $self->add_button({
    caption => 'Share this page',
    url     => $hub->url('Share', {
      __clear => 1,
      create  => 1,
      time    => time
    })
  });
}

sub content {
  my $self = shift;
  my $html;

  ## LH MENU ------------------------------------------
  my $tree = $self->tree;
 
  if ($tree) { 
  
   my $active = $self->active;
    my @nodes  = grep { $_->can('data') && !$_->data->{'no_menu_entry'} && $_->data->{'caption'} } @{$tree->child_nodes};
    my $menu;
  
    if ($tree->get_node($active) || $nodes[0]) {
      my $hub        = $self->{'hub'};
      my $modal      = $self->renderer->{'_modal_dialog_'};
      my $config     = $hub->session->get_data(type => 'nav', code => $hub->type) || {};
      my $img_url    = $hub->species_defs->img_url;
      my $counts     = $self->counts;
      my $all_params = !!$hub->object_types->{$hub->type};
    
      foreach (@nodes) {
        $_->data->{'top_level'} = 1;
        $self->_build_menu($_, $hub, $config, $img_url, $modal, $counts, $all_params, $active, $nodes[-1]);
      } 
    
      $menu .= $_->render for @nodes;
    }
  
    $html .= sprintf('
      %s
      <div class="header">%s</div>
      <ul class="local_context">%s</ul>',
      $self->configuration ? '' : '<input type="hidden" class="panel_type" value="LocalContext" />',
      encode_entities($self->strip_HTML($self->caption)),
      $menu
    );
  }

  ## TOOL BUTTONS ---------------------------------
  my $buttons = $self->buttons;

  if (scalar(@$buttons)) {

    $html .= '<div class="tool_buttons">';
    my $classes = $self->label_classes;

    foreach (@$buttons) {
      if ($_->{'class'} eq 'disabled') {
        $html .= qq(<p class="disabled $classes->{$_->{'caption'}}" title="$_->{'title'}">$_->{'caption'}</p>);
      } 
      else {
        my $rel   = lc $_->{'rel'};
        my $class = join ' ', map $_ || (), $_->{'class'}, $rel eq 'external' ? 'external' : '', $classes->{$_->{'caption'}};
        $class    = qq{ class="$class"} if $class;
        $rel      = qq{ rel="$rel"}     if $rel;

        $html .= qq(<p><a href="$_->{'url'}"$class$rel>$_->{'caption'}</a></p>);
      }
    }
    $html .= '</div>'; 
  }

  return $html;
}

##----------- PRIVATE METHODS -------------------------------

sub _build_menu {
  my ($self, $node, $hub, $config, $img_url, $modal, $counts, $all_params, $active, $last_child) = @_;
  
  my $data = $node->data;
  
  return if $data->{'no_menu_entry'} || !$data->{'caption'};
  
  my @children     = grep { $_->can('data') && !$_->data->{'no_menu_entry'} && $_->data->{'caption'} } @{$node->child_nodes};
  my $caption      = $data->{'caption'};
  my $title        = $data->{'full_caption'} || $caption;
  my $count        = $data->{'count'};
  my $availability = $data->{'availability'};
  my $class        = $data->{'class'};
    ($class        = $caption) =~ s/ /_/g unless $class;
  my $state        = $config->{$class} ^ $data->{'closed'};
  my $toggle       = $state ? 'closed' : 'open';
  my @classes      = $data->{'li_class'} || ();
  my @append;
  
  if ($modal) {
    if ($data->{'top_level'}) {
      @append = ([ 'img', { src => "$img_url${toggle}2.gif", class => "toggle $class", alt => '' }]) if scalar @children;
    } else {
      @append = ([ 'img', { src => "${img_url}leaf.gif", alt => '' }]);
    }
  } else {
    @append = ([ 'img', scalar @children ? { src => "$img_url$toggle.gif", class => "toggle $class", alt => '' } : { src => "${img_url}leaf.gif", alt => '' }]);
  }
  
  if ($availability && $self->is_available($availability)) {
    # $node->data->{'code'} contains action and function where required, so setting function to undef is fine.
    # If function is NOT set to undef and you are on a page with a function, the generated url could be wrong
    # e.g. on Location/Compara_Alignments/Image the url for Alignments (Text) will also be Location/Compara_Alignments/Image, rather than Location/Compara_Alignments
    my $url = $data->{'url'} || $hub->url({ action => $data->{'code'}, function => undef }, undef, $all_params);
    my $rel = $data->{'external'} ? 'external' : $data->{'rel'};
    
    for ($title, $caption) {
      s/\[\[counts::(\w+)\]\]/$counts->{$1}||0/eg;
      $_ = encode_entities($_);
    }
    
    push @append, [ 'a',    { class => $class,  inner_HTML => $caption, href => $url, title => $title, rel => $rel }];
    push @append, [ 'span', { class => 'count', inner_HTML => $count }] if $count;
  } else {
    $caption =~ s/\(\[\[counts::(\w+)\]\]\)//eg;
    push @append, [ 'span', { class => 'disabled', title => $data->{'disabled'}, inner_HTML => $caption }];
  }
  
  if (scalar @children) {
    my $ul = $node->dom->create_element('ul');
    
    foreach (@children) {
      $self->_build_menu($_, $hub, $config, $img_url, $modal, $counts, $all_params, $active, $children[-1]);
      $ul->append_child($_);
    }
    
    push @append, $ul;
    push @classes, 'parent';
  }
  
  push @classes, 'active'         if $node->id eq $active;
  push @classes, 'top_level'      if $data->{'top_level'};
  push @classes, 'last'           if $node eq $last_child;
  push @classes, 'closed'         if $toggle eq 'closed';
  push @classes, 'default_closed' if $data->{'closed'};
  
  $node->node_name = 'li';
  $node->set_attributes({ id => $data->{'id'}, class => join(' ', @classes) });
  $node->append_children(@append);
}

sub _export_url {
  my $self   = shift;
  my $hub    = shift;
  my $type   = $hub->type;
  my $action = $hub->action;
  my $export;

  if ($type eq 'Location' && $action eq 'LD') {
    $export = 'LDFormats';
  } elsif ($type eq 'Transcript' && $action eq 'Population') {
    $export = 'PopulationFormats';
  } elsif ($action eq 'Compara_Alignments') {
    $export = 'Alignments';
  } else {
    $export = 'Configure';
  }

  return $hub->url({ type => 'Export', action => $export, function => $type });
}


1;
