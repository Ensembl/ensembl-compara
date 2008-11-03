package EnsEMBL::Web::Configuration;

use strict;
use warnings;
no warnings qw(uninitialized);

use POSIX qw(floor ceil);
use CGI qw(escape);
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

  my $user    = $ENSEMBL_WEB_REGISTRY->get_user;
  my $session = $ENSEMBL_WEB_REGISTRY->get_session;
  my $we_can_have_a_user_tree = $self->can('user_populate_tree') && $user && $session;

  ## Trying to get user+session version of the tree from cache
  my $tree = ($we_can_have_a_user_tree && $MEMD)
           ? $MEMD->get($class->tree_key($user, $session))
           : undef;
  
  ## If no user+session tree found, build one
  unless ($tree) {
    ## Trying to get default tree from cache
    $tree = $MEMD->get($class->tree_key) if $MEMD;

    if ($tree) {
      $self->{_data}{tree} = $tree;
    } else {
      $self->populate_tree;
      ## Cache default tree
      $MEMD->set($class->tree_key, $self->{_data}{tree}, undef, 'TREE') if $MEMD;
    }

    if ($we_can_have_a_user_tree) {
      $self->user_populate_tree if $we_can_have_a_user_tree;
      ## Cache user+session tree version
      $MEMD->set(
        $class->tree_key($user, $session),
        $self->{_data}{tree},
        undef,
        'TREE', keys %{ $ENV{CACHE_TAGS}||{} }
      ) if $MEMD;
      
    }
  }

  $self->set_default_action;
  return $self;
}

sub tree_key {
  my ($class, $user, $session) = @_;
  my $key = "::${class}::$ENV{ENSEMBL_SPECIES}::TREE";

  if ($user && $session) {
    $key .= '::USER['    . $user->id                . ']';
    $key .= '::SESSION[' . $session->get_session_id . ']';
  }
  
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
  # my %hash = map { $_ => 1 } $self->{_data}{tree}->get_node(';
  return undef unless ref $self->{'object'};
  my $node;
  $node = $self->tree->get_node( $action."/".$func ) if $func;
  $self->{'availability'} = ref($self->object) ? $self->object->availability : {};

  return $action."/".$func if $node && $node->get('type') =~ /view/ &&
                              $self->is_available( $node->get('availability') );
  $node = $self->tree->get_node( $action )           unless $node;
  return $action if $node && $node->get('type') =~ /view/ &&
                    $self->is_available( $node->get('availability') );
  my @nodes = ( $self->default_action, 'Idhistory', 'Chromosome', 'Karyotype' );
  foreach( @nodes ) {
    $node = $self->tree->get_node( $_ );
     #warn( "H: $_:",$node->get('availability').'; '.join ("\t", grep { $self->{'availability'}{$_} } keys %{$self->{'availability'}||{} } ) ) if $node;
    if( $node && $self->is_available( $node->get('availability') ) ) {
      $self->{'object'}->problem( 'redirect', $self->{'object'}->_url({'action' => $_}) );
      return $_;
    }
  }
  return undef;
#  return $node;
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

sub _ajax_zmenu {
  my $self   = shift;
  my $obj    = $self->{'object'};
  $self->{'page'}->renderer->{'r'}->headers_in->{'X-Requested-With'} = 'XMLHttpRequest';
  my $panel  = $self->new_panel( 'AjaxMenu', 'code' => 'ajax_zmenu', 'object'   => $obj );
  $self->add_panel( $panel );
  return $panel;
}

sub _global_context {
  my $self = shift;
  return unless $self->{'page'}->can('global_context');
  return unless $self->{'page'}->global_context;
  
  my $type = $self->type;
  my $co = $self->{object}->core_objects;
  return unless $co;

  my @data = (
    ['location',        'Location',   'View',    $co->location_short_caption,   $co->location,   0 ],
    ['gene',            'Gene',       'Summary', $co->gene_short_caption,       $co->gene,       1 ],
    ['transcript',      'Transcript', 'Summary', $co->transcript_short_caption, $co->transcript, 1 ],
    ['variation',       'Variation',  'Summary', $co->variation_short_caption,  $co->variation,  0 ],
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

sub trim_referer {
  my( $self, $referer ) = @_;
  $referer =~ s/;time=\d+\.\d+//g;   # remove all references to time...
  $referer =~ s/\?time=\d+\.\d+;/?/;
  $referer =~ s/\?time=\d+\.\d+//g;
#  $referer .= ($referer =~ /\?/ ? ';' : '?')."time=".time();
  return $referer;
}

sub _user_context {
  my $self = shift;
  my $type = $self->type;
  my $obj  = $self->{'object'};
  my $qs = $self->query_string;

  my $referer = $self->trim_referer(
    $obj->param('_referer')||$obj->_url({'type'=>$type,'action'=>$ENV{'ENSEMBL_ACTION'},'time'=>undef})
  );

  my $vc  = $obj->get_viewconfig;
  my $action = $type.'/'.$ENV{'ENSEMBL_ACTION'};
     $action .= $ENV{'ENSEMBL_FUNCTION'} if $ENV{'ENSEMBL_FUNCTION'};

  if( !$vc->real && $obj->parent->{'ENSEMBL_TYPE'} ) {
    $vc = $obj->get_viewconfig( $obj->parent->{'ENSEMBL_TYPE'}, $obj->parent->{'ENSEMBL_ACTION'} );
    $vc->form($obj);
    $action  = $obj->parent->{'ENSEMBL_TYPE'}.'/'.$obj->parent->{'ENSEMBL_ACTION'};
    $action .= $obj->parent->{'ENSEMBL_FUNCTION'} if $obj->parent->{'ENSEMBL_FUNCTION'};
  }

  ## Do we have a View Config for this display?
  # Get view configuration...!
  ## Do we have any image configs for this display?
  my %ics = $vc->image_configs;
  ## Can user data be added to this page?
  my $flag = $obj->param('config') ? 0 : 1;
  my $active_config = $obj->param('config') || $vc->default_config();

  my $active = $type ne 'Account' && $type ne 'UserData' && $active_config eq '_page';

  my $upload_data = $vc->can_upload;

  if( $vc->has_form ) {
    $self->{'page'}->global_context->add_entry(
      'type'      => 'Config',
      'id'        => "config_page",
      'caption'   => 'Configure page',
      $active ? ( 'class' => 'active' ) : ( 'url' => $obj->_url({
        'time' => time, 
        'type'   => 'Config',
        'action' => $action,
        'config' => '_page',
        '_referer' => $referer
      }))
    );
    $flag = 0;
  }
  foreach my $ic_code (sort keys %ics) {
    my $ic = $obj->get_imageconfig( $ic_code );
    $active = $type ne 'Account' && $type ne 'UserData' && $active_config eq $ic_code || $flag;
    $self->{'page'}->global_context->add_entry(
      'type'      => 'Config',
      'id'        => "config_$ic_code",
      'caption'   => $ic->get_parameter('title'),
      $active ? ( 'class' => 'active' ) : ( 'url' => $obj->_url({
        'time' => time, 
        'type'   => 'Config',
	'action' => $action,
	'config' => $ic_code,
        '_referer' => $referer
      }))
    );
    $flag = 0;
  }
  if( $vc->can_upload ) {
    $active = $type eq 'UserData';
    $self->{'page'}->global_context->add_entry(
      'type'      => 'UserData',
      'id'        => 'user_data',
      'caption'   => 'Custom Data',
      $active ? ( 'class' => 'active' ) : ( 'url' => $obj->_url({
        'time' => time,
        '_referer' => $referer,
        '__clear' => 1,
        'type'   => 'UserData',
        'action' => 'Summary'
      }))
    );
  }

  ## Now the user account link - varies depending on whether the user is logged in or not!
  $active = $type eq 'Account';
  if( $obj->species_defs->ENSEMBL_LOGINS) {
    my $user_action = $ENSEMBL_WEB_REGISTRY->get_user ? 'Links' : 'Login';
    $self->{'page'}->global_context->add_entry( 
      'type'      => 'Account',
      'id'        => 'account',
      'caption'   => 'Your account',
      $active ? ( 'class' => 'active') : ( 'url' => $obj->_url({
        '_referer' => $referer,
        'time' => time, 
        '__clear' => 1,
        'type'   => 'Account',
	      'action' => $user_action,
      }))
    );
  }

  $self->{'page'}->global_context->active( lc($type) );
}


sub _reset_config_panel {
  my( $self, $title, $action, $config ) = @_;
  my $obj = $self->{'object'};
  my $panel = $self->new_panel( 'Configurator',
    'code' => 'x',
    'object' => $obj
  );
  my $url = $obj->_url({'type'=>'Config','action'=>$action,'reset'=>1,'config'=>$config,'time'=>time});
  my $c = sprintf '
<p>
  To update this configuration, select your tracks and other options in the box above and close
  this popup window. Your view will then be updated automatically.
</p>
<p>
  <a class="modal_link reset-button" href="%s">Reset configuration for %s to default settings</a>.
</p>', $url, CGI::escapeHTML( $title ) || 'this page';
  if( $title ) {
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
    Certain tracks displayed come from user supplied or external data sources, these are clearly
    marked as <strong>DAS</strong> (Distributed Annotation Sources), 
    <strong>URL</strong> (UCSC style web resources) or <strong>User</strong> data uploaded by
    yourself or another user.
  </li>
</ul>';
  }
  $panel->set_content( $c );
  $self->add_panel( $panel );
}

sub _configurator {
  my $self = shift;
  my $obj  = $self->{'object'};
  my $vc   = $obj->get_viewconfig();

  my $conf;
  my $config_key = $obj->param('config');
  eval {
    $conf = $obj->image_config_hash( $obj->param('config') ) if $obj->param('config');
  };
  my $action = $ENV{'ENSEMBL_TYPE'}.'/'.$ENV{'ENSEMBL_ACTION'};
     $action .= '/'.$ENV{'ENSEMBL_FUNCTION'} if $ENV{'ENSEMBL_FUNCTION'};
  my $referer = $self->trim_referer( $obj->param('_referer'), $ENV{'REQUEST_URI'} );
  my $url = $obj->_url({'type'=>'Config','action'=>$action,'_referer'=>$referer},1);
  unless( $conf ) {
## This must be the view config....
    if( $vc->has_form ) {
      $vc->get_form->{'_attributes'}{'action'} = $url->[0];
      foreach( keys %{$url->[1]}) {
        $vc->add_form_element({'type'=>'Hidden','name'=>$_,'value' => $url->[1]{$_}});
      }
      $self->tree->_flush_tree();
      $self->create_node( 'form_conf', 'Configure', [],  {
        'url' => '', 'availability' => 0, 'id' => 'form_conf_id', 'caption' => 'Configure'
      } );
      $self->{'page'}->{'_page_type_'} = 'configurator';

      $self->{'page'}->local_context->tree(    $self->{_data}{'tree'} );
      $self->{'page'}->local_context->active(  'form_conf' );
      $self->{'page'}->local_context->caption( 'Configure view'     );
      $self->{'page'}->local_context->class(   'view_configuration' );
      $self->{'page'}->local_context->counts(  {} );
      my $panel = $self->new_panel( 'Configurator',
        'code'         => 'configurator',
        'object'       => $obj
      );
      my $content  = '';
         $content .= sprintf '<h2>Configuration for: "%s"</h2>', CGI::escapeHTML($vc->title) if $vc->title;
	 $content .= $vc->get_form->render;
      $panel->set_content( $content );
      $self->add_panel( $panel );
      $self->_reset_config_panel( $vc->title, $action );
      return;
    }
    my %T = $vc->image_configs;
    my @Q = sort keys %T;
    if(@Q) {
      $config_key = $Q[0];
      $conf = $obj->image_config_hash( $Q[0] );
    }
  }
  return unless $conf;
  $self->{'page'}->{'_page_type_'} = 'configurator';
  $self->tree->_flush_tree();

  my $rhs_content = sprintf '
      <form id="configuration" action="%s" method="post">
        <div>', $url->[0];
  foreach( keys %{ $url->[1] } ) {
    $rhs_content .= sprintf '
          <input type="hidden" name="%s" value="%s" />', $_, CGI::escapeHTML( $url->[1]{$_} );
  }
  $rhs_content .= sprintf '
          <input type="hidden" name="config" value="%s" />
        </div>', $obj->param('config') ;
  my $active = '';
  foreach my $node ($conf->tree->top_level) {
    next if $node->is_leaf;
    my $count = 0;
    my $link_key = 'link_'.$node->key;
    my $menu_key = 'menu_'.$node->key;
    $rhs_content .= sprintf '
      <div id="%s">
      <h2>%s</h2>
      <dl class="config_menu">', $menu_key, CGI::escapeHTML( $node->get('caption') );
#      <dl class="config_menu" id="%s">
#       <dt class="title">%s</dt>', $menu_key, CGI::escapeHTML( $node->get('caption') );
    my $available = 0;
    my $on        = 0;
    foreach my $track_node ( $node->descendants ) {
      next if $track_node->get('menu') eq 'no';
      $rhs_content .= sprintf '
        <dt%s><select id="%s" name="%s">', 
        '', # $track_node->get('glyphset') =~ /_(prot)?das/ ? ' class="das_menu_entry"' : '',
        $track_node->key, $track_node->key;
      my $display = $track_node->get( 'display' ) || 'off';
      my @states  = @{ $track_node->get( 'renderers' ) || [qw(off Off normal Normal)] };
      while( my($K,$V) = splice(@states,0,2) ) {
        $rhs_content .= sprintf '
          <option value="%s"%s>%s</option>', $K, $K eq $display ? ' selected="selected"' : '',  CGI::escapeHTML($V);
      }
      $count ++;
      $on    ++ if $display ne 'off';
      my $t = CGI::escapeHTML( $track_node->get('name') );
      $t =~ s/\[(\w+)\]/sprintf( '<img src="\/i\/track-%s.gif" style="width:40px;height:16px" title="%s" alt="[%s]" \/>', lc($1), $1, $1 )/e;
      $rhs_content .= sprintf '
        </select> %s</dt>', $t;
      my $desc =  $track_node->get('description');
      if( $desc ) {
        $desc =~ s/&(?!\w+;)/&amp;/g;
	$desc =~ s/href="?([^"]+?)"?([ >])/href="$1"$2/g;
	$desc =~ s/<a>/<\/a>/g;
	$desc =~ s/"[ "]*>/">/g;
        $rhs_content .= sprintf '
	<dd>%s</dd>', $desc;
      }
    }
    $rhs_content .= '
      </dl>
      </div>';
    $active    ||= $link_key if $count > 0;
    $self->create_node(
      $link_key,
      ( $count ? "($on/$count) " : '' ).$node->get('caption'),
      [], # configurator EnsEMBL::Web::Component::Configurator ],
      { 'url' => "#$menu_key", 'availability' => ($count>0), 'id' => $link_key } 
    );
  }
  $rhs_content .= '
    </form>';

  $self->{'page'}->local_context->tree(    $self->{_data}{'tree'} );
  $self->{'page'}->local_context->active(  $active );
  $self->{'page'}->local_context->caption( $conf->get_parameter('title') );
  $self->{'page'}->local_context->class(   'track_configuration' );
  $self->{'page'}->local_context->counts(  {} );

  my $panel = $self->new_panel(
    'Configurator',
    'code'         => 'configurator',
    'object'       => $obj 
  );
  $panel->set_content( $rhs_content );

  $self->add_panel( $panel );
  $self->_reset_config_panel( $conf->get_parameter('title'), $action, $config_key );
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
  
  my $obj = $self->{object};

  my $referer = $self->trim_referer( $ENV{'REQUEST_URI'} );

  if( $ENV{'ENSEMBL_USER_ID'} ) {
    $self->{'page'}->local_tools->add_entry(
      'caption' => 'Bookmark this page',
      'class'   => 'modal_link',
      'url'     => $obj->_url({ 'type'     => 'Account', 'action'   => 'Bookmark',
                                '_referer' => $ENV{'REQUEST_URI'}, '__clear'  =>1,
                                'name'     => $self->{'page'}->title->get,
                                'url'      => $obj->species_defs->ENSEMBL_BASE_URL.$ENV{'REQUEST_URI'} })
    );
  } else {
    $self->{'page'}->local_tools->add_entry(
      'caption' => 'Bookmark this page',
      'class'   => 'disabled',
      'url'     => undef,
      'title'   => 'You must be logged in to bookmark pages'
    );
  }
  my $vc = $obj->get_viewconfig;
  my $config = $vc->default_config;

  my $disabled_upload = 1;
  if( $vc->real && $config ) {
    my $action = $obj->type.'/'.$obj->action;
       $action .= '/'.$obj->function if $obj->function;
    $self->{'page'}->local_tools->add_entry(
      'caption' => 'Configure this page',
      'class'   => 'modal_link',
      'url'     => $obj->_url({ 'time' => time, 'type' => 'Config', 'action' => $action,
                                'config' => $config, '_referer' => $referer })
    );
    if( $vc->can_upload ) {
      my $caption = 'Add custom data to page';
      my $action = 'Upload';
      my $userdata = $obj->get_session->get_tmp_data;
      my $user = $ENSEMBL_WEB_REGISTRY->get_user;
=pod
      if ($userdata || $user) {
        $caption = 'Add/manage custom data';
        if ($user) {
          $action = 'SaveUpload';
        }
        else {
          $action = 'ShareUpload';
        }
      }
=cut
      $self->{'page'}->local_tools->add_entry(
        'caption' => $caption,
        'class'   => 'modal_link',
        'url'     => $obj->_url({'time' => time, 'type' => 'UserData', 'action' => $action,
                                 '_referer' => $referer, '__clear' => 1 })
      );
      $disabled_upload = 0;
    }
  } else {
    $self->{'page'}->local_tools->add_entry(
      'caption' => 'Configure this page',
      'class'   => 'disabled',
      'url'     => undef,
      'title'   => 'There are no options for this page'
    );
  }
  if( $disabled_upload ) {
    $self->{'page'}->local_tools->add_entry(
      'caption' => 'Add custom data to page',
      'class'   => 'disabled',
      'url'     => undef,
      'title'   => 'You cannot add custom data to this page'
    );
  }

  if( 0 ) {
    $self->{'page'}->local_tools->add_entry(
      'caption' => 'Export data',
      'class'   => 'modal_link',
      'url'     => '/sorry.html'
    );
  }
}

sub _user_tools {
  my $self = shift;
  my $obj = $self->{object};

  my $sitename = $obj->species_defs->ENSEMBL_SITETYPE;
  my @data = (
          ['Back to '.$sitename,   '/index.html'],
  );

  my $type;
  foreach my $row ( @data ) {
    if( $row->[1] =~ /^http/ ) {
      $type = 'external';
    }
    $self->{'page'}->local_tools->add_entry(
      'type'      => $type,
      'caption'   => $row->[0],
      'url'       => $row->[1],
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
    defined($previous_node) &&
    ( $previous_node->get('type') ne 'view' ||
      ! $self->is_available( $previous_node->get('availability') ) )
  ) {
    $previous_node = $previous_node->previous;
  }
  my $next_node     = $node->next;
  while(
    defined($next_node) &&
    ( $next_node->get('type') ne 'view' ||
      ! $self->is_available( $next_node->get('availability') ) )
  ) {
    $next_node = $next_node->next;
  }

  my %params = (
    'object'   => $obj,
    'code'     => 'main',
    'caption'  => $node->data->{'concise'} || $node->data->{'caption'}
  );
  $params{'previous'} = $previous_node->data if $previous_node;
  $params{'next'    } = $next_node->data     if $next_node;

  ## Check for help
  my %help = $self->{object}->species_defs->multiX('ENSEMBL_HELP');
  $params{'help'} = $help{$ENV{'ENSEMBL_TYPE'}}{$ENV{'ENSEMBL_ACTION'}} if keys %help;

  $params{'omit_header'} = $self->{doctype} eq 'Popup' ? 1 : 0;
  
  my $panel = $self->new_panel( 'Navigation', %params );
  if( $panel ) {
    $panel->add_components( @{$node->data->{'components'}} );
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
  
  if ($self->tree) {
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
  };
  foreach ( keys %{$options||{}} ) {
    $details->{$_} = $options->{$_};
  }
  if ($self->tree) {
    return $self->tree->create_node( $code, $details );
  }
}
sub create_submenu {
  my ($self, $code, $caption, $options ) = @_;
  my $details = { 'caption'    => $caption, 'url' => '', 'type' => 'menu' };
  foreach ( keys %{$options||{}} ) {
    $details->{$_} = $options->{$_};
  }
  if ($self->tree) {
    return $self->tree->create_node( $code, $details );
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

sub wizard {
### a
  my ($self, $wizard) = @_;
  if ($wizard) {
    $self->{'wizard'} = $wizard;
  }
  return $self->{'wizard'};
}


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
    if( $error =~ m:$message: ) {
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

sub ajax_zmenu_variation {
 # Specific zmenu for variation features

  my $self = shift;
  my $panel = $self->_ajax_zmenu;
  my $obj = $self->object;
  my $db_adaptor = $obj->database('variation');
  my $var_adaptor = $db_adaptor->get_VariationAdaptor();
  my $var_feat_adaptor = $db_adaptor->get_VariationFeatureAdaptor();
  my $v_id = $obj->param('v');
  my $var = $var_adaptor->fetch_by_name($v_id);
  my @vf = @{$var_feat_adaptor->fetch_all_by_Variation($var)};
  my $feature;
  if ( scalar @vf == 1) { $feature = $vf[0];}
  else {}

  my $tvar_adaptor = $db_adaptor->get_TranscriptVariationAdaptor();
  my $trans_variation = $tvar_adaptor->fetch_by_dbID($obj->param('dbid'));
  ## alternate way to retrieve transcript_variation_feature if there are more than one with the same variation_feature id;
  unless ($trans_variation){
    my $trans_id = $obj->param('vt');
    if ($trans_id){
      my $trans_adaptor = $obj->database('core')->get_TranscriptAdaptor;
      my $transcript = $trans_adaptor->fetch_by_stable_id($trans_id);
      foreach my $trv (@{$tvar_adaptor->fetch_all_by_Transcripts([$transcript])}) {
        if ($trv->variation_feature->variation_name() eq $feature->variation_name){
          $trans_variation = $trv;
        }
      }
    }
  }

  my $type;
  if ($trans_variation){ $type =  join ", ", @{$trans_variation->consequence_type || [] };}
  else {$type = $obj->param('consequence') || '';}

  my $var_link = $obj->_url({'type' => 'Variation', 'action' => 'Summary', 'v' => $feature->variation_name });

  my $chr_start = $feature->start();
  my $chr_end   = $feature->end();
  my $bp = $chr_start;
  if( $chr_end < $chr_start ) {
      $bp = "between&nbsp;$chr_end&nbsp;&amp;&nbsp;$chr_start";
  } elsif($chr_end > $chr_start ) {
      $bp = "$chr_start&nbsp;-&nbsp;$chr_end";
  }
  my $source = (join ", ", @{$feature->get_all_sources ||[] });
  my $allele =  $feature->allele_string;
  my $alleles = (length($allele)<16 ? $allele : substr($allele,0,14).'..');

  $panel->{'caption'} = 'Variation ' . $feature->variation_name;
  $panel->add_entry({
    'label_html'  =>  'Variation Properties',
    'link'        =>  $var_link,
    'priority'    =>  15,
  });
  $panel->add_entry({
    'type'        =>  'bp:',
    'label'       =>  $bp,
    'priority'    =>  13,
  });
  $panel->add_entry({
    'type'        =>  'class:',
    'label'       =>  $feature->var_class,
    'priority'    =>  11,
  });
  $panel->add_entry({
    'type'        =>  'ambiguity code:',
    'label'       =>  $feature->ambig_code,
    'priority'    =>  9,
  });
  $panel->add_entry({
    'type'        =>  'alleles:',
    'label'       =>  $alleles,
    'priority'    =>  7,
  });
  $panel->add_entry({
    'type'        =>  'source:',
    'label'       =>  $source,
    'priority'    =>  5,
  });
  $panel->add_entry({
    'type'        =>  'type:',
    'label'        =>  $type,
    'priority'    =>  2,
  });

  if ($obj->param('snp_fake')){
    my $status = join(', ', @{$feature->get_all_validation_states||[]} );
    $panel->add_entry({
      'type'        =>  'status:',
      'label'       =>  $status || '-',
      'priority'    =>  12,
    });
    $panel->add_entry({
      'type'        =>  'mapweight:',
      'label'       =>  $feature->map_weight,
      'priority'    =>  8,
    });

  } elsif ($obj->param('var_box') && $trans_variation->pep_allele_string){
    $panel->add_entry({
      'type'        =>  'amino acid:',
      'label'       =>  $trans_variation->pep_allele_string,
      'priority'    =>  8,
    });
  }

 return;
}

sub ajax_zmenu_variation_transcript {
 # Specific zmenu for transcripts on variation image

  my $self = shift;
  my $panel = $self->_ajax_zmenu;
  my $obj = $self->object;
  my $trans_id = $obj->param('vt') || die( "No transcript stable ID value in params" );
  my $exon_id =  $obj->param('e') || die( "No exon stable ID value in params" );

  my $trans_adaptor = $obj->database('core')->get_TranscriptAdaptor;
  my $transcript = $trans_adaptor->fetch_by_stable_id($trans_id);
  my $protein_id = $transcript->translation ? $transcript->translation->stable_id() : '';
  my $id = $transcript->external_name() eq '' ? $trans_id : ( $transcript->external_db.": ".$transcript->external_name() );


  $panel->{'caption'} = $obj->species_defs->AUTHORITY." Gene";
  $panel->add_entry({
    'label'  => $id,
    'priority'    => 15,
  });
  $panel->add_entry({
    'type'        => 'Gene:',
    'label_html'  => $obj->stable_id,
    'link'        => $obj->_url({'type' => 'Gene', 'action' => 'Summary', 'g' =>$obj->stable_id }),
    'priority'    => 10,
  });
  $panel->add_entry({
    'type'        => 'Transcript:',
    'label_html'  => $trans_id,
    'link'        => $obj->_url({'type' => 'Transcript', 'action' => 'Summary', 't' => $trans_id }),
    'priority'    => 9,
  });
  if ($protein_id ){
    $panel->add_entry({
      'type'        => 'Protein product:',
      'label_html'  => $protein_id,
      'link'        => $obj->_url({'type' => 'Transcript', 'action' => 'ProteinSummary', 't' => $trans_id }),
      'priority'    => 8,
    });
    $panel->add_entry({
      'label_html'  => 'Export Protein',
      'link'        => $obj->_url({'type' => 'Transcript', 'action' => 'Export/fasta', 't' => $trans_id, 'st' => 'peptide', '_format' =>'Text' }),
      'priority'    => 5,
    });
  }

  $panel->add_entry({
    'type'        => 'Exon:',
    'label'       => $exon_id,
    'priority'    => 7,
  });
  $panel->add_entry({
    'label_html'  => 'Export cDNA',
    'link'        => $obj->_url({'type' => 'Transcript', 'action' => 'Export/fasta', 't' => $trans_id, 'st' => 'cdna', '_format' =>'Text' }),
    'priority'    => 6,
  });

  return;
}

sub ajax_zmenu_id_history_tree_node {
  # Specific zmenu for idhistory tree nodes
  my $self = shift;
  my $panel = $self->_ajax_zmenu;
  my $obj = $self->object;
  my $a_id = $obj->param('node') || die( "No node value in params" );

  my $db    = $obj->param('db')  || 'core';
  my $db_adaptor = $obj->database($db);
  my $arch_adaptor = $db_adaptor->get_ArchiveStableIdAdaptor;
  my $db_name = $obj->param('db_name');
  my $arch_obj = $arch_adaptor->fetch_by_stable_id_dbname( $a_id, $db_name);
  my $id = $arch_obj->stable_id .".". $arch_obj->version;
  my $type = $arch_obj->type eq 'Translation' ? 'Protein' : $arch_obj->type;
  my $url = $id;
  my $link;
  unless ($arch_obj->release <= $obj->species_defs->EARLIEST_ARCHIVE){ $link = _archive_link($obj, $arch_obj, $obj->species_defs->ENSEMBL_ARCHIVES, $obj->species_defs->ENSEMBL_VERSION); }

  $panel->{'caption'} = $id;

  $panel->add_entry({
    'type'        => $type,
    'label_html'  => $id,
    'link'        => $link,
    'priority'    => 10,
  });
  $panel->add_entry({
    'type'      => 'Release',
    'label'     => $arch_obj->release,
    'priority'  => 9,
  });
  $panel->add_entry({
    'type'      => 'Assembly',
    'label'     => $arch_obj->assembly,
    'priority'  => 8,
  });
  $panel->add_entry({
    'type'      => 'Database',
    'label'     => $arch_obj->db_name,
    'priority'  => 7,
  });

  return;
}

sub ajax_zmenu_id_history_tree_branch {
  # Specific zmenu for idhistory tree branch lines
  my $self = shift;
  my $panel = $self->_ajax_zmenu;
  my $obj = $self->object;
  my $old_id = $obj->param('old') || die( "No old id  value in params" );
  my $new_id = $obj->param('new') || die( "No new id  value in params" );

  my $db    = $obj->param('db')  || 'core';
  my $db_adaptor = $obj->database($db);
  my $arch_adaptor = $db_adaptor->get_ArchiveStableIdAdaptor;

  my $old_arch_obj = $arch_adaptor->fetch_by_stable_id_dbname( $old_id, $obj->param('old_db'));
  my $new_arch_obj = $arch_adaptor->fetch_by_stable_id_dbname( $new_id, $obj->param('new_db') );

  my %types = ( 'Old' => $old_arch_obj, 'New' => $new_arch_obj);
  my $priority = 15;


  $panel->{'caption'} = 'Similarity Match';

  foreach ( sort { $types{$a} <=> $types{$b} } keys %types) {
    my $version = $_;
    my $object = $types{$_};
    my $id = $object->stable_id .".".$object->version;
    my $url = $id;
    my $link;
    unless ($old_arch_obj->release <= $obj->species_defs->EARLIEST_ARCHIVE){ $link = _archive_link($obj, $object); }

    $panel->add_entry({
      'type'        => $version." ".$object->type,
      'label_html'  => $object->stable_id .".".$object->version,
      'link'        => $link,
      'priority'    => $priority,
    });
    $panel->add_entry({
      'type'      => $version." ".'Release',
      'label'     => $object->release,
      'priority'  => $priority--,
    });
    $panel->add_entry({
      'type'      => $version." ".'Assembly',
      'label'     => $object->assembly,
      'priority'  => $priority--,
    });
    $panel->add_entry({
      'type'      => $version." ".'Database',
      'label'     => $object->db_name,
      'priority'  => $priority--,
    });
    $priority--;
  }

  my $score = $obj->param('score');
  if ($score ==0 ){$score = 'Unknown';}
  else { $score = sprintf("%.2f", $score);}

  $panel->add_entry({
      'type'      => 'Score',
      'label'     => $score,
      'priority'  => $priority--,
  });

  return
}

sub ajax_zmenu_id_history_tree_label {
  # Specific zmenu for idhistory tree feature labels
  my $self = shift; warn $self;
  my $panel = $self->_ajax_zmenu; warn $panel;
  my $obj = $self->object;
  my $id = $obj->param('label') || die( "No label  value in params" );
  my $type = ucfirst($obj->param('feat_type'));
  my ($action, $p);

  if ($type eq 'Gene') {
      $p = 'g';
      $action = 'Idhistory';
    } elsif ($type eq 'Transcript'){
      $p = 't';
      $action = 'Idhistory';
    } else {
      $type = 'Transcript';
      $p = 'p';
      $action = 'Idhistory/Protein';
    }

  my $url = $obj->_url({'type' => $type, 'action' => $action, $p => $id });

  $panel->add_entry({
    'label_html'  => $id,
    'link'        => $url,
    'priority'    => 1,
  });


 return
}

sub _archive_link {
  my ($OBJ, $obj) = @_;

  my $type =  $obj->type eq 'Translation' ? 'peptide' : lc($obj->type);
  my $name = $obj->stable_id . "." . $obj->version;
  my $url;
  my $current =  $OBJ->species_defs->ENSEMBL_VERSION;

  my $view = $type."view";
  if ($type eq 'peptide') {
    $view = 'protview';
  } elsif ($type eq 'transcript') {
    $view = 'transview';
  }

  my ($action, $p);
  ### Set parameters for new style URLs post release 50
  if ($obj->release >= 51 ){
    if ($type eq 'gene') {
      $type = 'Gene';
      $p = 'g';
      $action = 'Summary';
    } elsif ($type eq 'transcript'){
      $type = 'Transcript';
      $p = 't';
      $action = 'Summary';
    } else {
      $type = 'Transcript';
      $p = 'p';
      $action = 'ProteinSummary';
    }
  }

  if ($obj->release == $current){
     $url = $OBJ->_url({'type' => $type, 'action' => $action, $p => $name });
     return $url;
  } else {
    my $release_info = EnsEMBL::Web::Data::Release->new($obj->release);
    my $archive_site = $release_info->archive;
    $url = "http://$archive_site.archive.ensembl.org";
    if ($obj->release >=51){
      $url .= $OBJ->_url({'type' => $type, 'action' => $action, $p => $name });
    } else {
      $url .= "/".$ENV{'ENSEMBL_SPECIES'};
      $url .= "/$view?$type=$name";
    }
  }

  return $url;
}



1;
