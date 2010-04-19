# $Id$

package EnsEMBL::Web::Configuration;

use strict;

use HTML::Entities qw(encode_entities);
use Time::HiRes qw(time);
use URI::Escape qw(uri_escape);

use EnsEMBL::Web::Document::Panel;
use EnsEMBL::Web::DASConfig;
use EnsEMBL::Web::Cache;
use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Root);

our $MEMD = new EnsEMBL::Web::Cache;

sub new {
  my ($class, $page, $model, $common_conf) = @_;
  
  my $self = {
    page   => $page,
    model  => $model,
    object => $model->object,
    _data  => $common_conf,
    _availability => undef,
    cl     => {}
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

  $self->modify_tree;
  $self->set_default_action;
  $self->set_action($ENV{'ENSEMBL_ACTION'}, $ENV{'ENSEMBL_FUNCTION'});
  
  return $self;
}

sub default_availability {
  my $self = shift;
  my $hub = $self->model->hub;

  my $hash = { map { ('database:'. lc(substr $_, 9) => 1) } keys %{$hub->species_defs->databases} };
  $hash->{'database:compara'} = 1 if $hub->species_defs->compara_like_databases;
  $hash->{'logged_in'} = 1 if $hub->user;

  return $hash;
}

sub availability  { return $_[0]{'_availability'} || {}; }
sub _counts       { return {}; }                            # Implemented in plugins
sub counts        { return $_[0]{'_counts'} || {}; }

sub caption { return ''; }
sub short_caption { return ''; }
sub populate_tree      {}
sub modify_tree        {}
sub set_default_action {}

sub model        { return $_[0]->{'model'}; }
sub object       { return $_[0]->{'object'}; }
sub page         { return $_[0]->{'page'}; }
sub tree         { return $_[0]->{'_data'}{'tree'}; }
sub configurable { return $_[0]->{'_data'}{'configurable'}; }
sub action       { return $_[0]->{'_data'}{'action'}; }
sub species      { return $ENV{'ENSEMBL_SPECIES'}; }
sub type         { return $ENV{'ENSEMBL_TYPE'}; }
sub add_panel    { $_[0]->{'page'}->content->add_panel($_[1]); }
sub set_title    { $_[0]->{'page'}->set_title($_[1]); }
sub set_action   { my $self = shift; $self->{'_data'}{'action'} = $self->_get_valid_action(@_); }
sub add_form     { my ($self, $panel, @T) = @_; $panel->add_form($self->page, @T); }

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

sub _get_valid_action {
  my ($self, $action, $func) = @_;
  
  my $object = $self->object;
  my $hub = $self->model->hub;  

  return $action if $action eq 'Wizard';
  
  my $node;
  
  $node = $self->tree->get_node($action. '/' . $func) if $func;
  $self->{'availability'} = $self->availability;

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

# Top tabs
sub _global_context {
  my $self = shift;
  
  return unless $self->page->can('global_context');
  return unless $self->page->global_context;
  my %tabs = %{$self->model->hub->tabs};

  foreach my $tabtype (@{$self->model->hub->tab_order}) {
    my $tab         = $tabs{$tabtype};
    my $caption     = $tab->{'short_caption'};
    my %core_params = map {$_ => $self->model->hub->param($_)} @{$tab->{'parameters'}};

    my $url     = $self->model->hub->url({ type => $tabtype, action => $tab->{'action'}, %core_params });

    $self->page->global_context->add_entry(
      type    => $tabtype,
      caption => $caption,
      url     => $url,
      class   => $tabtype eq $self->model->hub->type ? 'active' : ''
    );
  }
  
}

sub modal_context {
  my $self = shift;
  
  return if $self->page->{'modal_context_called'}++;
  
  $self->_user_context('modal_context') if $self->page->{'modal_context'};
}

sub user_context {
  my $self = shift;
  
  return if $self->page->{'user_context_called'}++;
  
  $self->_user_context;
}

sub _user_context {
  my $self          = shift;
  my $section       = shift || 'global_context';
  my $hub           = $self->model->hub;
  my $object        = $self->object;
  my $type          = $self->type;
  my $action        = join '/', grep $_, $type, $ENV{'ENSEMBL_ACTION'}, $ENV{'ENSEMBL_FUNCTION'};
  my $vc            = $object->viewconfig;
  my %ics           = $vc ? $vc->image_configs : undef;
  my $active_config = $hub->param('config') || ($vc ? $vc->default_config : undef);
  my $active        = $section eq 'global_context' && $type ne 'Account' && $type ne 'UserData' && $active_config eq '_page';
  my $flag          = $hub->param('config') ? 0 : 1;
  
  if ($vc) {
    if ($vc->has_form) {
      $self->page->$section->add_entry(
        type    => 'Config',
        id      => 'config_page',
        caption => 'Configure page',
        $active ? ( class => 'active' ) : ( 
        url => $hub->url({
          time     => time, 
          type     => 'Config',
          action   => $action,
          config   => '_page'
        }))
      );
    
      $flag = 0;
    }
  
    foreach my $ic_code (sort keys %ics) {
      my $ic  = $hub->get_imageconfig($ic_code);
      $active = $section eq 'global_context' && $type ne 'Account' && $type ne 'UserData' && $active_config eq $ic_code || $flag;
      
      $self->page->$section->add_entry(
        type    => 'Config',
        id      => "config_$ic_code",
        caption => $ic->get_parameter('title'),
        $active ? ( class => 'active' ) : ( 
        url => $hub->url({
          time     => time, 
          type     => 'Config',
          action   => $action,
          config   => $ic_code
        }))
      );
    
      $flag = 0;
    }
  }
  
  $active = $section eq 'global_context' && $type eq 'UserData';
  
  $self->page->$section->add_entry(
    type    => 'UserData',
    id      => 'user_data',
    caption => 'Custom Data',
     $active ? ( class => 'active' ) : ( 
     url => $hub->url({
       time => time,
       __clear  => 1,
       type     => 'UserData',
       action   => 'ManageData'
     }))
  );
  
  $active = $section eq 'global_context' && $type eq 'Account'; # Now the user account link - varies depending on whether the user is logged in or not
  
  if ($hub->species_defs->ENSEMBL_LOGINS) {
    $self->page->$section->add_entry( 
      type    => 'Account',
      id      => 'account',
      caption => 'Your account',
      $active ? ( class => 'active') : ( 
      url => $hub->url({
        time     => time, 
        __clear  => 1,
        type     => 'Account',
        action   => $ENSEMBL_WEB_REGISTRY->get_user ? 'Links' : 'Login'
      }))
    );
  }

  $self->page->$section->active(lc $type);
}

sub _ajax_content {
  my $self = shift;
  
  $self->page->renderer->{'r'}->headers_in->{'X-Requested-With'} = 'XMLHttpRequest';
  
  my $panel = $self->new_panel('Ajax', 'code' => 'ajax_panel', 'object' => $self->object);
  $panel->add_component('component' => $ENV{'ENSEMBL_COMPONENT'});
  $self->add_panel($panel);
}

sub _reset_config_panel {
  my ($self, $title, $action, $config) = @_;
  
  my $object = $self->object;
  
  my $panel = $self->new_panel('Configurator',
    code   => 'x',
    object => $object
  );
  
  my $url = $self->model->hub->url({ 
    type     => 'Config', 
    action   => $action, 
    reset    => 1, 
    config   => $config
  });
  
  my $c = sprintf('
    <p>
      To update this configuration, select your tracks and other options in the box above and close
      this popup window. Your view will then be updated automatically.
    </p>
    <p>
      <a class="modal_link" href="%s" rel="modal_config_%s">Reset configuration for %s to default settings</a>.
    </p>', 
    $url, lc $config, encode_entities($title) || 'this page'
  );

  if ($title) {
    $c .= '
    <p>
      Notes:
    </p>
    <ul>
      <li>
        To change whether a track is drawn OR how it is drawn, click on the icon by the track name and
        then select the way the track is to be rendered.
      </li>
      <li>
        On the left hand side of the page the number of tracks in a menu, and the number of tracks
        currently turned on from that menu are shown by the two numbers in parentheses <span style="white-space:nowrap">(tracks on/total tracks)</span>.
      </li>
      <li>
        <p>
        Certain tracks displayed come from user-supplied or external data sources, these are clearly
        marked as <strong><img src="/i/track-das.gif" alt="DAS" style="vertical-align:top; width:40px;height:16px" title="DAS" /></strong> (Distributed Annotation Sources), 
        <strong><img src="/i/track-url.gif" alt="URL" style="vertical-align:top; width:40px;height:16px" title="URL" /></strong> (UCSC style web resources) or 
        <strong><img src="/i/track-user.gif" alt="User" style="vertical-align:top; width:40px;height:16px" title="User" /></strong> data uploaded by
        yourself or another user.
        </p>
        <p>
        Please note that the content of these tracks is not the responsibility of the Ensembl project.
        </p>
        <p>In the case of URL based or DAS tracks may either slow down your ensembl browsing experience OR may be unavailable as these are served and stored from other servers elsewhere on the Internet.
        </p>
      </li>
    </ul>';
  }
  
  $panel->set_content($c);
  $self->add_panel($panel);
}

sub _configurator {
  my $self = shift;
  
  my $object     = $self->object;
  my $hub        = $self->model->hub;
  my $vc         = $object->viewconfig;
  my $config_key = $hub->param('config');
  my $action     = join '/', map $hub->$_ || (), qw(type action function);
  my $url        = $hub->url({ type => 'Config', action => $action }, 1);
  my $conf       = $hub->param('config') ? $hub->image_config_hash($hub->param('config'), undef, 'merged') : undef;
  
  # This must be the view config
  if (!$conf) {
    if ($vc && $vc->has_form) {
      $vc->get_form->{'_attributes'}{'action'} = $url->[0];
      
      $vc->add_form_element({ type => 'Hidden', name => $_, value => $url->[1]->{$_} }) for keys %{$url->[1]};
      
      $self->tree->_flush_tree;
      
      $self->page->local_context->tree($vc->tree);
      $self->page->local_context->active('form_conf');
      $self->page->local_context->caption('Configure view');
      $self->page->local_context->configuration(1);
      $self->page->local_context->counts({});
      
      my $panel = $self->new_panel('Configurator',
        code   => 'configurator',
        object => $object
      );
      
      my $content = '';
      $content .= sprintf '<h2>Configuration for %s</h2>', encode_entities($vc->title) if $vc->title;
      $content .= $vc->get_form->render;
      
      $panel->set_content($content);
      $self->add_panel($panel);
      $self->_reset_config_panel($vc->title, $action);
      
      return;
    }
    
    my @image_configs = sort keys %{$vc->image_configs||{}};
    
    if (@image_configs) {
      $config_key = $image_configs[0];
      $conf = $hub->image_config_hash($config_key);
    }
  }
  
  return unless $conf;
  
  $self->tree->_flush_tree;

  my $rhs_content = qq{
    <form class="configuration" action="$url->[0]" method="post">
      <div>
  };
  
  $rhs_content .= sprintf '<input type="hidden" name="%s" value="%s" />', $_, encode_entities($url->[1]->{$_}) for keys %{$url->[1]};
  $rhs_content .= sprintf('
      <input type="hidden" name="config" value="%s" />
    </div>', 
    $hub->param('config')
  );
  
  my $active = '';
  
  $self->create_node('active_tracks',  'Active tracks',  [], { availability => 1, url => "#", class => 'active_tracks' });
  $self->create_node('search_results', 'Search Results', [], { availability => 1, url => "#", class => 'search_results disabled' });

  foreach my $node ($conf->tree->top_level) {
    next unless $node->get('caption');
    next if $node->is_leaf;
    
    my $count     = 0;
    my $ext_count = 0;
    my $available = 0;
    my $on        = 0;
    my $key       = $node->key;
    my (%renderers, $select_all_menu, $config_group, $submenu);
    
    foreach my $track_node ($node->descendants) {
      next if $track_node->get('menu') eq 'no';
      
      my $display   = $track_node->get('display') || 'off';
      my @states    = @{$track_node->get('renderers') || [ qw(off Off normal Normal) ]};
      my $desc      = $track_node->get('description');
      my $class     = $track_node->get('_class');
      my $name      = encode_entities($track_node->get('name'));
      my ($dd, $selected, $menu, $external_menu, $pre_config_group);
      
      if ($track_node->get('submenu')) {
        $submenu = $track_node->get('caption');
        $submenu = lc $submenu if $submenu =~ /^[A-Z][a-z]/; # Assume that a word starting with two capitals is an abbreviation, so don't use lower case in this situation 
        $pre_config_group = '</dl><dl class="config_menu submenu">' if $config_group;
      } else {
        $name = sprintf '<img src="/i/track-%s.gif" style="width:40px;height:16px" title="%s" alt="[%s]" /> %s', lc $class, $class, $class, $name if $class;   
        
        while (my ($val, $text) = splice @states, 0, 2) {
          $text     = encode_entities($text);
          $selected = sprintf '<input type="hidden" name="%s" value="%s" /><img title="%s" alt="%s" src="/i/render/%s.gif" class="menu_option" />', $track_node->key, $val, $text, $text, $val if $val eq $display;
          $text     = qq{<li class="$val"><img title="$text" alt="$text" src="/i/render/$val.gif" class="$key" />$text</li>};
          
          if ($class) {
            $external_menu .= $text;
          } else {
            $menu .= $text;
            $renderers{$val}++;
          }
        }
        
        $count++;
        $on++ if $display ne 'off';
        $ext_count++ if $class;
        $select_all_menu ||= $menu;
        $class = (lc $class || 'internal') .' '. $track_node->get('class');
        $pre_config_group = '</dl><dl class="config_menu submenu"><dt class="external">External data sources</dt>' if $ext_count == 1;
        
        if ($desc) {
          $desc =~ s/&(?!\w+;)/&amp;/g;
          $desc =~ s/href="?([^"]+?)"?([ >])/href="$1"$2/g;
          $desc =~ s/<a>/<\/a>/g;
          $desc =~ s/"[ "]*>/">/g;
          
          $selected = qq{<span class="menu_help">Show info</span>$selected};
          $dd       = "<dd>$desc</dd>";
        }
        
        if ($submenu && $submenu != 1) {
          $pre_config_group = $self->build_enable_all_menu($submenu, $key, $select_all_menu, %renderers);
          $submenu = 1;
        }
      }
      
      $config_group .= $pre_config_group;
      
      if ($name) {
        $config_group .= qq{
          <dt class="$class">
            <ul class="popup_menu">$menu$external_menu</ul>
            $selected <span class="menu_option">$name</span>
          </dt>
          $dd
        };
      }
    }
    
    $config_group = $self->build_enable_all_menu('tracks', $key, $select_all_menu, %renderers) . $config_group if !$submenu && $count - $ext_count > 1;
    
    $rhs_content .= sprintf('
      <div class="config %s">
        <h2>%s</h2>
        <dl class="config_menu">
          %s
        </dl>
      </div>', 
      $key, encode_entities($node->get('caption')), $config_group
    );
      
    $active ||= $key if $count > 0;
    
    $self->create_node($key,
      ( $count ? "($on/$count) " : '' ) . $node->get('caption'),
      [],
      { url => "#", availability => ($count > 0), class => $node->key } 
    );
  }
  
  $rhs_content .= '
    </form>';

  $self->page->local_context->tree($self->{'_data'}{'tree'});
  $self->page->local_context->active('active_tracks');
  $self->page->local_context->caption($conf->get_parameter('title'));
  $self->page->local_context->configuration(1);
  $self->page->local_context->counts({});

  my $search_panel = $self->new_panel('Configurator',
    code   => 'configurator_search',
    object => $object
  );
  
  $search_panel->set_content('<div class="configuration_search">Search display: <input class="configuration_search_text" /></div>');
  
  $self->add_panel($search_panel);
  
  my $panel = $self->new_panel('Configurator',
    code   => 'configurator',
    object => $object 
  );
  
  $panel->set_content($rhs_content);
  
  $self->add_panel($panel);
  $self->_reset_config_panel($conf->get_parameter('title'), $action, $config_key);
  
  return $panel;
}

sub build_enable_all_menu {
  my ($self, $label, $key, $menu, %renderers) = @_;
  
  my %counts = reverse %renderers;
  
  if (scalar keys %counts != 1) {
    $menu  = '';
    $menu .= qq{<li class="$_->[2]"><img title="$_->[1]" alt="$_->[1]" src="/i/render/$_->[0].gif" class="$key" />$_->[1]</li>} for [ 'off', 'Off', 'off' ], [ 'normal', 'On', 'all_on' ];
  }
  
  return qq{
    <dt class="select_all">
      <ul class="popup_menu">$menu</ul>
      <img title="Enable/disable all" alt="Enable/disable all" src="/i/render/off.gif" class="menu_option" /> <strong class="menu_option">Enable/disable all $label</strong>
    </dt>
  };
}

sub _local_context {
  my $self = shift;
  
  return unless $self->page->can('local_context') && $self->page->local_context;
  
  my $object = $self->object;
  my $hub    = $self->model->hub;
  my $action = $self->_get_valid_action($hub->action, $hub->function);
  
  $self->page->local_context->tree($self->{'_data'}{'tree'});
  $self->page->local_context->active($action);
  $self->page->local_context->caption($self->short_caption);
  $self->page->local_context->counts($self->counts);
  $self->page->local_context->availability($self->availability);
}

sub _local_tools {
  my $self = shift;
  
  return unless $self->page->can('local_tools');
  return unless $self->page->local_tools;
  
  my $hub    = $self->model->hub;
  my $vc     = $self->object->viewconfig;
  my $config = $vc->default_config;
  
  if ($vc->real && $config) {
    my $action = join '/', map $hub->$_ || (), qw(type action function);
    (my $rel = $config) =~ s/^_//;
    
    $self->page->local_tools->add_entry(
      caption => 'Configure this page',
      class   => 'modal_link',
      rel     => "modal_config_$rel",
      url     => $hub->url({ 
        time     => time, 
        type     => 'Config', 
        action   => $action,
        config   => $config
      })
    );
  } else {
    $self->page->local_tools->add_entry(
      caption => 'Configure this page',
      class   => 'disabled',
      url     => undef,
      title   => 'There are no options for this page'
    );
  }
  
  $self->page->local_tools->add_entry(
    caption => 'Manage your data',
    class   => 'modal_link',
    url     => $hub->url({
      time    => time,
      type    => 'UserData',
      action  => 'ManageData',
      __clear => 1 
    })
  );
  
  if ($self->object && $self->object->can_export) {       
    $self->page->local_tools->add_entry(
      caption => 'Export data',
      class   => 'modal_link',
      url     => $hub->url({ type => 'Export', action => $hub->type, function => $hub->action })
    );
  } 
  else {
    $self->page->local_tools->add_entry(
      caption => 'Export data',
      class   => 'disabled',
      url     => undef,
      title   => 'You cannot export data from this page'
    );
  }
  
  if ($ENV{'ENSEMBL_USER_ID'}) {
    $self->page->local_tools->add_entry(
      caption => 'Bookmark this page',
      class   => 'modal_link',
      url     => $hub->url({
        type    => 'Account',
        action  => 'Bookmark/Add',
        __clear => 1,
        name    => $self->page->title->get,
        url     => $hub->species_defs->ENSEMBL_BASE_URL . $hub->url
      })
    );
  } else {
    $self->page->local_tools->add_entry(
      caption => 'Bookmark this page',
      class   => 'disabled',
      url     => undef,
      title   => 'You must be logged in to bookmark pages'
    );
  }
}

sub _user_tools {
  my $self = shift;

  my $sitename = $self->model->hub->species_defs->ENSEMBL_SITETYPE;
  my @data     = ([ "Back to $sitename", '/index.html' ]);
  my $rel;
  
  foreach (@data) {    
    $self->page->local_tools->add_entry(
      rel     => $_->[1] =~ /^http/ ? 'external' : '',
      caption => $_->[0],
      url     => $_->[1]
    );
  }
}

sub _context_panel {
  my $self   = shift;
  my $raw    = shift;
  my $caption = $self->caption;
  
  my $panel = $self->new_panel('Summary',
    code        => 'summary_panel',
    object      => $self->object,
    raw_caption => $raw,
    caption     => $caption
  );
  
  $panel->add_component(summary => sprintf 'EnsEMBL::Web::Component::%s::Summary', $self->model->hub->type);
  
  $self->add_panel($panel);
}

sub _content_panel {
  my $self   = shift;
  my $object = $self->object;
  my $hub = $self->model->hub;

  my $action = $self->_get_valid_action($hub->action, $hub->function);
  my $node   = $self->get_node($action);
  
  return unless $node;
  
  if ($self->can('set_title')) {
    my $title = $node->data->{'concise'} || $node->data->{'caption'};
    $title =~ s/\s*\(.*\[\[.*\]\].*\)\s*//;
    $title = join ' - ', '', $title, ($self->caption);
     
    $self->set_title($title);
  }
  
  $self->{'availability'} = $self->availability;
  
  my $previous_node = $node->previous;
  my $next_node     = $node->next;
  
  # don't show tabs for 'no_menu' nodes
  while (defined $previous_node && ($previous_node->get('type') ne 'view' || !$self->is_available($previous_node->get('availability')))) {
    $previous_node = $previous_node->previous;
  }
  
  while (defined $next_node && ($next_node->get('type') ne 'view' || !$self->is_available($next_node->get('availability')))) {
    $next_node = $next_node->next;
  }

  my %params = (
    object      => $object,
    code        => 'main',
    caption     => $node->data->{'full_caption'} || $node->data->{'concise'} || $node->data->{'caption'},
    omit_header => $self->{'_data'}{'doctype'} eq 'Popup' ? 1 : 0
  );
  
  $params{'previous'} = $previous_node->data if $previous_node;
  $params{'next'}     = $next_node->data     if $next_node;
  
  my %help = $hub->species_defs->multiX('ENSEMBL_HELP'); # Check for help
  
  if (keys %help) {
    my $page_url = join '/', map $hub->$_ || (), qw(type action function);
    $params{'help'} = $help{$page_url};
  }
  
  my $panel = $self->new_panel('Navigation', %params);
  
  if ($panel) {
    $panel->add_components('__messages', 'EnsEMBL::Web::Component::Messages', @{$node->data->{'components'}});
    $self->add_panel($panel);
  }
}

sub get_node { 
  my ($self, $code) = @_;
  return $self->{'_data'}{'tree'}->get_node($code);
}

sub query_string {
  my $self   = shift;
  
  my %parameters = (%{$self->model->hub->core_params}, @_);
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

sub update_configs_from_parameter {
  my ($self, $parameter_name, @imageconfigs) = @_;
  
  my $hub         = $self->model->hub;
  my $val         = $hub->param($parameter_name);
  my $reset       = $hub->param('reset');
  my @das         = $hub->param('add_das_source');
  my $view_config = $self->object->get_viewconfig;

  foreach my $config_name (@imageconfigs) {
    $hub->attach_image_config($hub->script, $config_name);
    $hub->image_config_hash($config_name);
  }
  
  foreach my $url (@das) {
    my $das = EnsEMBL::Web::DASConfig->new_from_URL($url);
    $hub->session->add_das($das);
  }
  
  return unless $val || $reset;
  
  if ($view_config) {
    $view_config->reset if $reset;
    $view_config->update_config_from_parameter($val) if $val;
  }
  
  foreach my $config_name (@imageconfigs) {
    my $image_config = $hub->image_config_hash($config_name);
    
    if ($image_config) {
      $image_config->reset if $reset;
      $image_config->update_config_from_parameter($val) if $val;
      $hub->session->_temp_store($hub->script, $config_name);
    }
  }
}

sub new_panel {
  my ($self, $panel_type, %params) = @_;
  
  my $module_name = 'EnsEMBL::Web::Document::Panel';
  $module_name.= "::$panel_type" if $panel_type;
  
  $params{'code'} =~ s/#/$self->{'flag'}||0/eg;
  
  if ($panel_type && !$self->dynamic_use($module_name)) {
    my $error = $self->dynamic_use_failure($module_name);
    
    if ($error =~ /^Can't locate/) {
      $error = qq{<p>Unrecognised panel type "<b>$panel_type</b>"};
    } else {
      $error = sprintf '<p>Unable to compile <strong>%s</strong></p><pre>%s</pre>', $module_name, $self->_format_error($error);
    }
    
    $self->page->content->add_panel(
      new EnsEMBL::Web::Document::Panel(
        model      => $self->model,
        object     => $self->object,
        code       => "error_$params{'code'}",
        caption    => 'Panel compilation error',
        content    => $error,
        has_header => $params{'has_header'},
      )
    );
    
    return undef;
  }
  
  no strict 'refs';
  
  my $panel;
  
  eval {
    $panel = $module_name->new('model' => $self->model, 'object' => $self->object, %params);
  };
  
  return $panel unless $@;
  
  $self->page->content->add_panel(
    new EnsEMBL::Web::Document::Panel(
      model   => $self->model,
      object  => $self->object,
      code    => "error_$params{'code'}",
      caption => "Panel runtime error",
      content => sprintf ('<p>Unable to compile <strong>%s</strong></p><pre>%s</pre>', $module_name, $self->_format_error($@))
    )
  );
  
  return undef;
}

sub count_alignments {
  my $self = shift;

  my $species = $self->model->hub->species;
  my %alignments = $self->model->hub->species_defs->multi('DATABASE_COMPARA', 'ALIGNMENTS');
  my $c = { all => 0, pairwise => 0 };

  foreach (grep $_->{'species'}{$species}, values %alignments) {
    $c->{'all'}++ ;
    $c->{'pairwise'}++ if $_->{'class'} =~ /pairwise_alignment/;
  }

  $c->{'multi'} = $c->{'all'} - $c->{'pairwise'};

  return $c;
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
