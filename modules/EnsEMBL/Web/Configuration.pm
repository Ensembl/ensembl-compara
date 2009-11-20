# $Id$

package EnsEMBL::Web::Configuration;

use strict;
use warnings;
no warnings qw(uninitialized);

use CGI qw(escape escapeHTML);
use Time::HiRes qw(time);

use EnsEMBL::Web::Document::Panel;
use EnsEMBL::Web::OrderedTree;
use EnsEMBL::Web::DASConfig;
use EnsEMBL::Web::Cache;
use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Root);

our $MEMD = new EnsEMBL::Web::Cache;

sub object { 
  return $_[0]->{'object'};
}

sub populate_tree {

}

sub set_default_action {

}

sub new {
  my( $class, $page, $object, $flag, $common_conf ) = @_;
  my $self = {
    'page'    => $page,
    'object'  => $object,
    'flag '   => $flag || '',
    'cl'      => {},
    '_data'   => $common_conf
  };
  bless $self, $class;

  my $user       = $ENSEMBL_WEB_REGISTRY->get_user;
  my $session    = $ENSEMBL_WEB_REGISTRY->get_session;
  my $session_id = $session->get_session_id;
  my $we_can_have_a_user_tree = $self->can('user_populate_tree') && ($user || $session_id);

  ## Trying to get user+session version of the tree from cache
  my $tree = ($we_can_have_a_user_tree && $MEMD && $class->tree_cache_key($user, $session))
           ? $MEMD->get($class->tree_cache_key($user, $session))
           : undef;

  if ($tree) {
    $self->{_data}{tree} = $tree;
  } else {
    ## If no user+session tree found, build one
    ## Trying to get default tree from cache
    $tree = $MEMD->get($class->tree_cache_key) if $MEMD && $class->tree_cache_key;

    if ($tree) {
      $self->{_data}{tree} = $tree;
    } else {
      $self->populate_tree;
      ## Cache default tree
      $MEMD->set($class->tree_cache_key, $self->{_data}{tree}, undef, 'TREE')
        if $MEMD && $class->tree_cache_key;
    }

    if ($we_can_have_a_user_tree) {
      $self->user_populate_tree if $we_can_have_a_user_tree;
      ## Cache user+session tree version
      $MEMD->set(
        $class->tree_cache_key($user, $session),
        $self->{_data}{tree},
        undef,
        'TREE', keys %{ $ENV{CACHE_TAGS}||{} }
      ) if $MEMD && $class->tree_cache_key($user, $session);
      
    }
  }

  $self->extra_populate_tree
    if $self->can('extra_populate_tree');
  
  $self->set_default_action;
  return $self;
}

## Each class might have different tree caching dependences 
## See Configuration::Account and Configuration::Search for more examples
sub tree_cache_key {
  my ($class, $user, $session) = @_;
  my $key = "::${class}::$ENV{ENSEMBL_SPECIES}::TREE";

  $key .= '::USER['. $user->id .']'
    if $user;

  $key .= '::SESSION['. $session->get_session_id .']'
    if $session && $session->get_session_id;
  
  return $key;
}

sub tree {
  my $self = shift;
  return $self->{_data}{tree};
}

sub configurable {
  my $self = shift;
  return $self->{_data}{configurable};
}

sub action {
  my $self = shift;
  return $self->{_data}{'action'};
}
sub set_action {
  my $self = shift;
  $self->{_data}{'action'} = $self->_get_valid_action(@_);
}

sub default_action {
### Default action for feature type...
  my $self = shift;
  unless( $self->{_data}{'default'} ) {
    ($self->{_data}{'default'}) = $self->{_data}{tree}->leaf_codes;
  }
  return $self->{_data}{'default'};
}

sub _get_valid_action {
  my $self = shift;
  my $action = shift;
  my $func   = shift;
  return $action if $action eq 'Wizard';
  # my %hash = map { $_ => 1 } $self->{_data}{tree}->get_node(';
  return undef unless ref $self->{'object'};
  my $node;
  $node = $self->tree->get_node( $action."/".$func ) if $func;
  $self->{'availability'} = ref($self->object) ? $self->object->availability : {};

  return $action."/".$func if $node && $node->get('type') =~ /view/ &&
                              $self->is_available( $node->get('availability') );
  $node = $self->tree->get_node( $action ) unless $node;
  return $action if $node && $node->get('type') =~ /view/ &&
                    $self->is_available( $node->get('availability') );
  my @nodes = ( $self->default_action, 'Idhistory', 'Chromosome', 'Genome' );
  foreach( @nodes ) {
    $node = $self->tree->get_node( $_ );
     #warn( "H: $_:",$node->get('availability').'; '.join ("\t", grep { $self->{'availability'}{$_} } keys %{$self->{'availability'}||{} } ) ) if $node;
    if( $node && $self->is_available( $node->get('availability') ) ) {
      $self->{'object'}->problem( 'redirect', $self->{'object'}->_url({'action' => $_}) );
      return $_;
    }
  }
  return undef;
}

sub _ajax_content {
  my $self   = shift;
  my $obj    = $self->{'object'};
  $self->{'page'}->renderer->{'r'}->headers_in->{'X-Requested-With'} = 'XMLHttpRequest';
## Force page type to be ingredient!
  $self->{'page'}->{'_page_type_'} = 'ingredient';
  my $panel  = $self->new_panel( 'Ajax', 'code' => 'ajax_panel', 'object'   => $obj);
  $panel->add_component( 'component' => $ENV{'ENSEMBL_COMPONENT'} );
  $self->add_panel( $panel );
}

sub _global_context {
  my $self = shift;
  return unless $self->{'page'}->can('global_context');
  return unless $self->{'page'}->global_context;
  
  my $type = $self->type;
  my $co = $self->{object}->core_objects;
  return unless $co;

  my @data = (
    ['location',        'Location',   'View',    $co->location_short_caption,     $co->location,    0 ],
    ['gene',            'Gene',       'Summary', $co->gene_short_caption,         $co->gene,        1 ],
    ['transcript',      'Transcript', 'Summary', $co->transcript_short_caption,   $co->transcript,  1 ],
    ['variation',       'Variation',  'Summary', $co->variation_short_caption,    $co->variation,   0 ],
    ['regulation',      'Regulation', 'Summary', $co->regulation_short_caption,   $co->regulation,  1 ],
  );
  my $qs = $self->query_string;
  foreach my $row ( @data ) {
    next unless $row->[4];
    my $action = 
      $row->[4]->isa('EnsEMBL::Web::Fake')            ? $row->[4]->view :
      $row->[4]->isa('Bio::EnsEMBL::ArchiveStableId') ? 'idhistory'     : $row->[2];
    my $url  = $self->{object}->_url({'type'=> $row->[1], 'action' => $action,'__clear'=>1 });
       $url .="?$qs" if $qs;
    
    my @class = ();
    if( $row->[1] eq $type ) {
      push @class, 'active';
    }
    $self->{'page'}->global_context->add_entry( 
      'type'      => $row->[1],
      'caption'   => $row->[3],
      'url'       => $url,
      'class'     => (join ' ',@class),
    );
  }
  $self->{'page'}->global_context->active( lc($type) );
}

sub modal_context {
  my $self = shift;
  
  return if $self->{'page'}->{'modal_context_called'}++;
  
  $self->_user_context('modal_context') if $self->{'page'}->{'modal_context'};
}

sub user_context   {
  my $self = shift;
  
  return if $self->{'page'}->{'user_context_called'}++;
  
  $self->_user_context;
}

sub _user_context {
  my $self = shift;
  my $section = shift || 'global_context';
  
  my $object  = $self->object;
  my $type    = $self->type;
  my $parent  = $object->parent;
  my $qs      = $self->query_string;
  my $referer = $object->param('_referer') || $object->_url({ type => $type, action => $ENV{'ENSEMBL_ACTION'}, time => undef });
  my $vc      = $object->viewconfig;
  my $action  = join '/', grep $_, $type, $ENV{'ENSEMBL_ACTION'}, $ENV{'ENSEMBL_FUNCTION'};
  my %params;
  
  if (!$vc->real && $parent->{'ENSEMBL_TYPE'} && $section eq 'global_context' && !$self->{'page'}->renderer->{'_modal_dialog_'}) {
    $vc = $object->get_viewconfig($parent->{'ENSEMBL_TYPE'}, $parent->{'ENSEMBL_ACTION'});
    $action = join '/', map $parent->{$_} || (), qw(ENSEMBL_TYPE ENSEMBL_ACTION ENSEMBL_FUNCTION);
    %params = map { $_ => $parent->{'params'}->{$_}->[0] } keys %{$parent->{'params'}};
    
    $vc->form($object);
  }
  
  my %ics           = $vc->image_configs;
  my $flag          = $object->param('config') ? 0 : 1;
  my $active_config = $object->param('config') || $vc->default_config;
  my $active        = $section eq 'global_context' && $type ne 'Account' && $type ne 'UserData' && $active_config eq '_page';
  my $upload_data   = $vc->can_upload;

  if ($vc->has_form) {
    $self->{'page'}->$section->add_entry(
      'type'    => 'Config',
      'id'      => 'config_page',
      'caption' => 'Configure page',
      $active ? ( 'class' => 'active' ) : ( 
      'url' => $object->_url({
        'time'     => time, 
        'type'     => 'Config',
        'action'   => $action,
        'config'   => '_page',
        '_referer' => $referer,
        %params
      }))
    );
    
    $flag = 0;
  }
  
  foreach my $ic_code (sort keys %ics) {
    my $ic  = $object->get_imageconfig($ic_code);
    $active = $section eq 'global_context' && $type ne 'Account' && $type ne 'UserData' && $active_config eq $ic_code || $flag;
    
    $self->{'page'}->$section->add_entry(
      'type'    => 'Config',
      'id'      => "config_$ic_code",
      'caption' => $ic->get_parameter('title'),
      $active ? ( 'class' => 'active' ) : ( 
      'url' => $object->_url({
        'time'     => time, 
        'type'     => 'Config',
        'action'   => $action,
        'config'   => $ic_code,
        '_referer' => $referer,
      }))
    );
    
    $flag = 0;
  }
  
  $active = $section eq 'global_context' && $type eq 'UserData';
  
  $self->{'page'}->$section->add_entry(
    'type'    => 'UserData',
    'id'      => 'user_data',
    'caption' => 'Custom Data',
     $active ? ( 'class' => 'active' ) : ( 
     'url' => $object->_url({
      'time' => time,
      '_referer' => $referer,
      '__clear'  => 1,
      'type'     => 'UserData',
      'action'   => $vc->can_upload ? 'SelectFile' : 'ManageData',
     }))
  );
  
  $active = $section eq 'global_context' && $type eq 'Account'; # Now the user account link - varies depending on whether the user is logged in or not
  
  if ($object->species_defs->ENSEMBL_LOGINS) {
    $self->{'page'}->$section->add_entry( 
      'type'    => 'Account',
      'id'      => 'account',
      'caption' => 'Your account',
      $active ? ( 'class' => 'active') : ( 
      'url' => $object->_url({
        '_referer' => $referer,
        'time'     => time, 
        '__clear'  => 1,
        'type'     => 'Account',
        'action'   => $ENSEMBL_WEB_REGISTRY->get_user ? 'Links' : 'Login',
      }))
    );
  }

  $self->{'page'}->$section->active(lc $type);
}


sub _reset_config_panel {
  my ($self, $title, $action, $config) = @_;
  
  my $obj = $self->{'object'};
  
  my $panel = $self->new_panel('Configurator',
    'code' => 'x',
    'object' => $obj
  );
  
  my $url = $obj->_url({ type => 'Config', action => $action, reset => 1 , config => $config, _referer => $obj->param('_referer') });
  
  my $c = sprintf('
    <p>
      To update this configuration, select your tracks and other options in the box above and close
      this popup window. Your view will then be updated automatically.
    </p>
    <p>
      <a class="modal_link" href="%s" rel="modal_config_%s">Reset configuration for %s to default settings</a>.
    </p>', 
    $url, lc $config, escapeHTML($title) || 'this page'
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
  my $vc         = $object->viewconfig;
  my $config_key = $object->param('config');
  my $referer    = $object->param('_referer') || $ENV{'REQUEST_URI'};
  my $action     = join '/', map $object->$_ || (), qw(type action function);
  my $url        = $object->_url({ type => 'Config', action => $action, _referer => $referer }, 1);
  my $conf       = $object->param('config') ? $object->image_config_hash($object->param('config'), undef, 'merged') : undef;
  
  # This must be the view config
  if (!$conf) {
    if ($vc->has_form) {
      $vc->get_form->{'_attributes'}{'action'} = $url->[0];
      
      $vc->add_form_element({ type => 'Hidden', name => $_, value => $url->[1]->{$_} }) for keys %{$url->[1]};
      
      $self->{'page'}->{'_page_type_'} = 'configurator';
      $self->tree->_flush_tree;
      
      $self->{'page'}->local_context->tree($vc->tree);
      $self->{'page'}->local_context->active('form_conf');
      $self->{'page'}->local_context->caption('Configure view');
      $self->{'page'}->local_context->configuration(1);
      $self->{'page'}->local_context->counts({});
      
      my $panel = $self->new_panel('Configurator',
        'code'   => 'configurator',
        'object' => $object
      );
      
      my $content = '';
      $content .= sprintf '<h2>Configuration for %s</h2>', escapeHTML($vc->title) if $vc->title;
      $content .= $vc->get_form->render;
      
      $panel->set_content($content);
      $self->add_panel($panel);
      $self->_reset_config_panel($vc->title, $action);
      
      return;
    }
    
    my @image_configs = sort keys %{$vc->image_configs||{}};
    
    if (@image_configs) {
      $config_key = $image_configs[0];
      $conf = $object->image_config_hash($config_key);
    }
  }
  
  return unless $conf;
  
  $self->{'page'}->{'_page_type_'} = 'configurator';
  $self->tree->_flush_tree;

  my $rhs_content = qq{
    <form class="configuration" action="$url->[0]" method="post">
      <div>
  };
  
  $rhs_content .= sprintf '<input type="hidden" name="%s" value="%s" />', $_, escapeHTML($url->[1]->{$_}) for keys %{$url->[1]};
  $rhs_content .= sprintf('
      <input type="hidden" name="config" value="%s" />
    </div>', 
    $object->param('config')
  );
  
  my $active = '';
  
  $self->create_node('active_tracks',  'Active tracks',  [], { url => "#", class => 'active_tracks',  availability => 1 });
  $self->create_node('search_results', 'Search Results', [], { url => "#", class => 'search_results disabled', availability => 1 });

  foreach my $node ($conf->tree->top_level) {
    next unless $node->get('caption');
    next if $node->is_leaf;
    
    my $count     = 0;
    my $ext_count = 0;
    my $available = 0;
    my $on        = 0;
    my $key       = $node->key;
    my (%renderers, $select_all_menu, $config_group);
    
    foreach my $track_node ($node->descendants) {
      next if $track_node->get('menu') eq 'no';
      
      my $display   = $track_node->get('display') || 'off';
      my @states    = @{$track_node->get('renderers') || [ qw(off Off normal Normal) ]};
      my $desc      = $track_node->get('description');
      my $class     = $track_node->get('_class');
      my $name      = escapeHTML($track_node->get('name'));
      my $close_tag = '</dt>';
      my ($selected, $menu, $external_menu, $external_header);
      
      $name = sprintf '<img src="/i/track-%s.gif" style="width:40px;height:16px" title="%s" alt="[%s]" /> %s', lc $class, $class, $class, $name if $class;
      
      while (my ($val, $text) = splice @states, 0, 2) {
        $text     = escapeHTML($text);
        $selected = sprintf '<input type="hidden" name="%s" value="%s" /><img title="%s" alt="%s" src="/i/render/%s.gif" class="selected" />', $track_node->key, $val, $text, $text, $val if $val eq $display;
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
      $class = lc $class || 'internal';
      $external_header = '<dt class="external">External data sources</dt>' if $ext_count == 1;
      
      if ($desc) {
        $desc =~ s/&(?!\w+;)/&amp;/g;
        $desc =~ s/href="?([^"]+?)"?([ >])/href="$1"$2/g;
        $desc =~ s/<a>/<\/a>/g;
        $desc =~ s/"[ "]*>/">/g;
        
        $selected   = qq{<span class="menu_help">Show info</span>$selected};
        $close_tag .= "<dd>$desc</dd>";
      }
      
      $config_group .= qq{
        $external_header
        <dt class="$class">
          <ul class="popup_menu">$menu$external_menu</ul>
          $selected <span>$name</span>
        $close_tag
      };
    }
    
    if ($count - $ext_count > 1) {
      my %counts = reverse %renderers;
      my $label = 'Enable/disable all tracks';
      
      if (scalar keys %counts != 1) {
        $select_all_menu = '';
        $select_all_menu .= qq{<li class="$_->[2]"><img title="$_->[1]" alt="$_->[1]" src="/i/render/$_->[0].gif" class="$key" />$_->[1]</li>} for [ 'off', 'Off', 'off' ], [ 'normal', 'On', 'all_on' ];
      }
      
      $config_group = qq{
        <dt class="select_all">
          <ul class="popup_menu">$select_all_menu</ul>
          <img title="Enable/disable all" alt="Enable/disable all" src="/i/render/off.gif" class="selected" /> <strong>$label</strong>
        </dt>
        $config_group
      }; 
    }
    
    $rhs_content .= sprintf('
      <div class="config %s">
        <h2>%s</h2>
        <dl class="config_menu">
          %s
        </dl>
      </div>', 
      $key, escapeHTML($node->get('caption')), $config_group
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

  $self->{'page'}->local_context->tree($self->{'_data'}{'tree'});
  $self->{'page'}->local_context->active('active_tracks');
  $self->{'page'}->local_context->caption($conf->get_parameter('title'));
  $self->{'page'}->local_context->configuration(1);
  $self->{'page'}->local_context->counts({});

  my $search_panel = $self->new_panel('Configurator',
    'code'   => 'configurator_search',
    'object' => $object
  );
  
  $search_panel->set_content('<div class="configuration_search">Search display: <input class="configuration_search_text" /></div>');
  
  $self->add_panel($search_panel);
  
  my $panel = $self->new_panel('Configurator',
    'code'   => 'configurator',
    'object' => $object 
  );
  
  $panel->set_content($rhs_content);
  
  $self->add_panel($panel);
  $self->_reset_config_panel($conf->get_parameter('title'), $action, $config_key);
  
  return $panel;
}

sub _local_context {
  my $self = shift;
  return unless $self->{'page'}->can('local_context') && $self->{'page'}->local_context;
  
  my $hash = {}; #  $self->obj->get_summary_counts;
  $self->{'page'}->local_context->tree(    $self->{_data}{'tree'}    );
  my $action = $self->_get_valid_action( $ENV{'ENSEMBL_ACTION'}, $ENV{'ENSEMBL_FUNCTION'} );
  $self->{'page'}->local_context->active(  $action );#$self->{_data}{'action'}  );
  $self->{'page'}->local_context->caption(      ref($self->{object})  ? $self->{object}->short_caption : $self->{object} );
  $self->{'page'}->local_context->counts(       ref( $self->{object}) ? $self->{object}->counts        : {}   );
  $self->{'page'}->local_context->availability( ref($self->{object})  ? $self->{object}->availability  : {}   );
}

sub _local_tools {
  my $self = shift;
  
  return unless $self->{'page'}->can('local_tools');
  return unless $self->{'page'}->local_tools;
  
  my $obj = $self->{'object'};

  my $referer = $ENV{'REQUEST_URI'};

  my $vc = $obj->viewconfig;
  my $config = $vc->default_config;
  
  if ($vc->real && $config) {
    my $action = $obj->type . '/' . $obj->action;
    $action .= '/' . $obj->function if $obj->function;
    
    (my $rel = $config) =~ s/^_//;
    
    $self->{'page'}->local_tools->add_entry(
      'caption' => 'Configure this page',
      'class'   => 'modal_link',
      'rel'     => "modal_config_$rel",
      'url'     => $obj->_url({ 
        'time'     => time, 
        'type'     => 'Config', 
        'action'   => $action,
        'config'   => $config, 
        '_referer' => $referer
      })
    );
  } else {
    $self->{'page'}->local_tools->add_entry(
      'caption' => 'Configure this page',
      'class'   => 'disabled',
      'url'     => undef,
      'title'   => 'There are no options for this page'
    );
  }
  
  my $caption = 'Manage your data';
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my @temp_uploads = $self->object->get_session->get_data(type => 'upload');
  my @user_uploads = $user ? $user->uploads : ();
  my $action = @temp_uploads || @user_uploads ? 'ManageData' : 'SelectFile';

  $self->{'page'}->local_tools->add_entry(
    'caption' => $caption,
    'class'   => 'modal_link',
    'url'     => $obj->_url({
      'time'     => time,
      'type'     => 'UserData',
      'action'   => $action,
      '_referer' => $referer,
      '__clear'  => 1 
    })
  );
  
  if ($obj->can_export) {       
    $self->{'page'}->local_tools->add_entry(
      'caption' => 'Export data',
      'class'   => 'modal_link',
      'url'     => $obj->_url({ type => 'Export', action => $obj->type, function => $obj->action, '_referer' => $referer })
    );
  } else {
    $self->{'page'}->local_tools->add_entry(
      'caption' => 'Export data',
      'class'   => 'disabled',
      'url'     => undef,
      'title'   => 'You cannot export data from this page'
    );
  }
  
  if ($ENV{'ENSEMBL_USER_ID'}) {
    $self->{'page'}->local_tools->add_entry(
      'caption' => 'Bookmark this page',
      'class'   => 'modal_link',
      'url'     => $obj->_url({
        'type'     => 'Account',
        'action'   => 'Bookmark/Add',
        '_referer' => $referer,
        '__clear'  => 1,
        'name'     => $self->{'page'}->title->get,
        'url'      => $obj->species_defs->ENSEMBL_BASE_URL . $referer
      })
    );
  } else {
    $self->{'page'}->local_tools->add_entry(
      'caption' => 'Bookmark this page',
      'class'   => 'disabled',
      'url'     => undef,
      'title'   => 'You must be logged in to bookmark pages'
    );
  }
}

sub _user_tools {
  my $self = shift;

  my $sitename = $self->{'object'}->species_defs->ENSEMBL_SITETYPE;
  my @data = ([ "Back to $sitename", '/index.html' ]);

  my $rel;
  
  foreach (@data) {    
    $self->{'page'}->local_tools->add_entry(
      'rel'     => $_->[1] =~ /^http/ ? 'external' : '',
      'caption' => $_->[0],
      'url'     => $_->[1]
    );
  }
}

sub _context_panel {
  my $self   = shift;
  my $raw    = shift;
  my $obj    = $self->{'object'};
  my $panel  = $self->new_panel( 'Summary',
    'code'     => 'summary_panel',
    'object'   => $obj,
    'raw_caption' => $raw,
    'caption'  => $obj->caption
  );
  $panel->add_component( 'summary' => sprintf( 'EnsEMBL::Web::Component::%s::Summary', $self->type ) );
  $self->add_panel( $panel );
}

sub _content_panel {
  my $self   = shift;
  
  
  my $obj    = $self->{'object'};
  my $action = $self->_get_valid_action( $ENV{'ENSEMBL_ACTION'}, $ENV{'ENSEMBL_FUNCTION'} );
  my $node          = $self->get_node( $action );
  return unless $node;
  my $title = $node->data->{'concise'}||$node->data->{'caption'};
     $title =~ s/\s*\(.*\[\[.*\]\].*\)\s*//;
     $title = join ' - ', '', $title, ( $obj ? $obj->caption : () );
   
  $self->set_title( $title ) if $self->can('set_title');

  my $previous_node = $node->previous;
  ## don't show tabs for 'no_menu' nodes
  $self->{'availability'} = $obj->availability;
  while(
    defined($previous_node) && ( $previous_node->get('type') ne 'view' || ! $self->is_available( $previous_node->get('availability') ) )
  ) {
    $previous_node = $previous_node->previous;
  }
  my $next_node     = $node->next;
  while(
    defined($next_node) && ( $next_node->get('type') ne 'view' || ! $self->is_available( $next_node->get('availability') ) )
  ) {
    $next_node = $next_node->next;
  }

  my %params = (
    'object'   => $obj,
    'code'     => 'main',
    'caption'  => $node->data->{'full_caption'} || $node->data->{'concise'} || $node->data->{'caption'}
  );
  $params{'previous'} = $previous_node->data if $previous_node;
  $params{'next'    } = $next_node->data     if $next_node;

  ## Check for help
  my %help = $self->{object}->species_defs->multiX('ENSEMBL_HELP');
  if (keys %help) {
    my $page_url = $ENV{'ENSEMBL_TYPE'}.'/'.$ENV{'ENSEMBL_ACTION'};
    $page_url .= '/'.$ENV{'ENSEMBL_FUNCTION'} if $ENV{'ENSEMBL_FUNCTION'};
    $params{'help'} = $help{$page_url};
  }

  $params{'omit_header'} = $self->{doctype} eq 'Popup' ? 1 : 0;
  
  my $panel = $self->new_panel( 'Navigation', %params );
  if( $panel ) {
    $panel->add_components( '__messages', 'EnsEMBL::Web::Component::Messages', @{$node->data->{'components'}} );
    $self->add_panel( $panel );
  }
}

sub get_node { 
  my ( $self, $code ) = @_;
  return $self->{_data}{tree}->get_node( $code );
}

sub species { return $ENV{'ENSEMBL_SPECIES'}; }
sub type    { return $ENV{'ENSEMBL_TYPE'};    }

sub query_string {
  my $self = shift;
  return unless defined $self->{object}->core_objects;
  my %parameters = (%{$self->{object}->core_objects->{parameters}},@_);
  my @S = ();
  foreach (sort keys %parameters) {
    push @S, "$_=$parameters{$_}" if defined $parameters{$_}; 
  }
  push @S, '_referer='.CGI::escape($self->object->param('_referer'))
    if $self->object->param('_referer');
  return join ';', @S;
}

sub create_node {
  my ( $self, $code, $caption, $components, $options ) = @_;
 
  my $details = {
    caption    => $caption,
    components => $components,
    code       => $code,
    type       => 'view',
  };
  
  foreach ( keys %{$options||{}} ) {
    $details->{$_} = $options->{$_};
  }
  
  if( $self->tree ) {
    return $self->tree->create_node( $code, $details );
  }
}

sub create_subnode {
  my ( $self, $code, $caption, $components, $options ) = @_;

  my $details = {
    caption    => $caption,
    components => $components,
    code       => $code,
    type       => 'subview',
    %{ $options || {} },
  };

  return $self->tree->create_node( $code, $details )
    if $self->tree;
}

sub create_submenu {
  my ($self, $code, $caption, $options ) = @_;

  my $details = {
    caption => $caption,
    url     => '',
    type    => 'menu',
    %{ $options || {} },
  };
  
  return $self->tree->create_node( $code, $details )
    if $self->tree;
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
  my( $self, $parameter_name, @imageconfigs ) = @_;
  my $val = $self->{object}->param( $parameter_name );
  my $rst = $self->{object}->param( 'reset' );
  my $wsc = $self->{object}->get_viewconfig();
  my @das = $self->{object}->param( 'add_das_source' );

  foreach my $config_name ( @imageconfigs ) {
    $self->{'object'}->attach_image_config( $self->{'object'}->script, $config_name );
    $self->{'object'}->image_config_hash( $config_name );
  }
  foreach my $URL ( @das ) {
    my $das = EnsEMBL::Web::DASConfig->new_from_URL( $URL );
    $self->{object}->get_session( )->add_das( $das );
  }
  return unless $val || $rst;
  if( $wsc ) {
    $wsc->reset() if $rst;
    $wsc->update_config_from_parameter( $val ) if $val;
  }
  foreach my $config_name ( @imageconfigs ) {
    my $wuc = $self->{'object'}->image_config_hash( $config_name );
#    my $wuc = $self->{'object'}->get_imageconfig( $config_name );
    if( $wuc ) {
      $wuc->reset() if $rst;
      $wuc->update_config_from_parameter( $val ) if $val;
      $self->{object}->get_session->_temp_store( $self->{object}->script, $config_name );
    }
  }
}

sub add_panel { $_[0]{page}->content->add_panel( $_[1] ); }
sub set_title { $_[0]{page}->set_title( $_[1] ); }
sub add_form  { my($self,$panel,@T)=@_; $panel->add_form( $self->{page}, @T ); }

sub add_block {
  my $self = shift;
  return unless $self->{page}->can('menu');
  return unless $self->{page}->menu;
  my $flag = shift;
  $flag =~s/#/($self->{flag} || '')/ge;
#     $flag =~s/#/$self->{flag}/g;
  $self->{page}->menu->add_block( $flag, @_ );
}

sub delete_block {
  my $self = shift;
  return unless $self->{page}->can('menu');
  return unless $self->{page}->menu;
  my $flag = shift;
     $flag =~s/#/$self->{flag}/g;
  $self->{page}->menu->delete_block( $flag, @_ );
}

sub add_entry {
  my $self = shift;
  return unless $self->{page}->can('menu');
  return unless $self->{page}->menu;
  my $flag = shift;
  $flag =~s/#/($self->{flag} || '')/ge;
  $self->{page}->menu->add_entry( $flag, @_ );
}

sub new_panel {
  my( $self, $panel_type, %params ) = @_;
  my $module_name = "EnsEMBL::Web::Document::Panel";
     $module_name.= "::$panel_type" if $panel_type;
  $params{'code'} =~ s/#/$self->{'flag'}||0/eg;
  if( $panel_type && !$self->dynamic_use( $module_name ) ) {
    my $error = $self->dynamic_use_failure( $module_name );
    my $message = "^Can't locate EnsEMBL/Web/Document/Panel/$panel_type\.pm in";
    if( $error =~ /$message/ ) {
      $error = qq(<p>Unrecognised panel type "<b>$panel_type</b>");
    } else {
      $error = sprintf( "<p>Unable to compile <strong>$module_name</strong></p><pre>%s</pre>",
                $self->_format_error( $error ) );
    }
    $self->{page}->content->add_panel(
      new EnsEMBL::Web::Document::Panel(
        'object'  => $self->{'object'},
        'code'    => "error_$params{'code'}",
        'caption' => "Panel compilation error",
        'content' => $error,
        'has_header' => $params{'has_header'},
      )
    );
    return undef;
  }
  no strict 'refs';
  my $panel;
  eval {
    $panel = $module_name->new( 'object' => $self->{'object'}, %params );
  };
  return $panel unless $@;
  my $error = "<pre>".$self->_format_error($@)."</pre>";
  $self->{page}->content->add_panel(
    new EnsEMBL::Web::Document::Panel(
      'object'  => $self->{'object'},
      'code'    => "error_$params{'code'}",
      'caption' => "Panel runtime error",
      'content' => "<p>Unable to compile <strong>$module_name</strong></p>$error"
    )
  );
  return undef;
}

sub mapview_possible {
  my( $self, $location ) = @_;
  my @coords = split(':', $location);
  my %chrs = map { $_,1 } @{$self->{object}->species_defs->ENSEMBL_CHROMOSOMES || []};
  return 1 if exists $chrs{$coords[0]};
}

1;
