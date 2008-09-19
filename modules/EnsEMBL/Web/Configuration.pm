package EnsEMBL::Web::Configuration;

use strict;
use warnings;
no warnings qw(uninitialized);
use POSIX qw(floor ceil);
use CGI qw(escape);

use EnsEMBL::Web::Document::Panel;
use EnsEMBL::Web::OrderedTree;
use EnsEMBL::Web::DASConfig;
use EnsEMBL::Web::Cache;

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

  my $tree = $MEMD ? $MEMD->get($class->tree_key) : undef;
  if ($tree) {
    $self->{_data}{tree} = $tree;
  } else {
    $self->populate_tree;
    $MEMD->set($class->tree_key, $self->{_data}{tree}, undef, 'TREE') if $MEMD;
  }

  $self->set_default_action;
  return $self;
}

sub tree_key {
  my $class = shift;
  return "::${class}::TREE";
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
  $self->{_data}{'action'} = $self->_get_valid_action(shift);
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
  my %hash = map { $_ => 1 } $self->{_data}{tree}->leaf_codes;
  return exists( $hash{$action} ) ? $action : $self->default_action;
}

sub _ajax_content {
  my $self   = shift;
  my $obj    = $self->{'object'};
  $self->{'page'}->renderer->{'r'}->headers_in->{'X-Requested-With'} = 'XMLHttpRequest';
## Force page type to be ingredient!
  $self->{'page'}->{'_page_type_'} = 'ingredient';
  my $panel  = $self->new_panel( 'Ajax', 'code' => 'ajax_panel', 'object'   => $obj);
  $panel->add_component( 'component' => $ENV{'ENSEMBL_ACTION'} );
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
  my $type = $self->type;
  return unless $self->{object}->core_objects;

  my @data = (
    ['location',  'Location',   $self->{object}->core_objects->location_short_caption ],
    ['gene',      'Gene',       $self->{object}->core_objects->gene_short_caption ],
    ['transcript','Transcript', $self->{object}->core_objects->transcript_short_caption ],
    ['variation',       'Variation',  $self->{object}->core_objects->variation_short_caption ],
  );
  my $qs = $self->query_string;
  foreach my $row ( @data ) {
    next if $row->[2] eq '-';
    my $url   = "/$ENV{ENSEMBL_SPECIES}/$row->[1]/Summary?$qs";
    my @class = ();
    if( $row->[1] eq $type ) {
      push @class, 'active';
    }
    $self->{'page'}->global_context->add_entry( 
      'type'      => $row->[1],
      'caption'   => $row->[2],
      'url'       => $url,
      'class'     => (join ' ',@class),
    );
  }
  $self->{'page'}->global_context->active( lc($type) );
}

sub _user_context {
  my $self = shift;
  my $type = $self->type;
  my $obj  = $self->{'object'};
  my $qs = $self->query_string;

  ## Do we have a View Config for this display?
  # Get view configuration...!
  my $vc  = $obj->get_viewconfig;
  ## Do we have any image configs for this display?
  my %ics = $vc->image_configs;
  ## Can user data be added to this page?
  my $flag = $obj->param('config') ? 0 : 1;
  foreach my $ic_code (sort keys %ics) {
    my $ic = $obj->get_imageconfig( $ic_code );
    $self->{'page'}->global_context->add_entry(
      'type'      => 'Config',
      'id'        => "config_$ic_code",
      'caption'   => 'Configure "'.$ic->get_parameter('title').'"',
      'url'       => $obj->_url({
        'type'   => 'Config',
	'action' => $type.'/'.$ENV{'ENSEMBL_ACTION'},
	'config' => $ic_code
      }),
      'class'     => ( $type ne 'Account' && 
                       $type ne 'UserData' &&
		       (
		         $obj->param('config') eq $ic_code ||
			 $flag
              	       )
		     ) ? 'active' : ''
    );
    $flag = 0;
  }
  $self->{'page'}->global_context->add_entry(
    'type'      => 'UserData',
    'caption'   => 'Custom Data',
    'url'       => $obj->_url({
      'type'   => 'UserData',
      'action' => 'Summary'
    }),
    'class'     => $type eq 'UserData' ? 'active' : ''
  );
  ## Now the user account link if the user is logged in!

  if( $obj->species_defs->ENSEMBL_LOGINS 
     && $ENV{'ENSEMBL_USER_ID'} ) {
    $self->{'page'}->global_context->add_entry( 
      'type'      => 'Account',
      'caption'   => 'Your account',
      'url'       => $obj->_url({
        'type'   => 'Account',
	'action' => 'Summary'
      }),
      'class'     => $type eq 'Account' ? 'active' : ''
    );
  }

  $self->{'page'}->global_context->active( lc($type) );
}

sub _configurator {
  my $self = shift;
  my $obj  = $self->{'object'};
  my $vc   = $obj->get_viewconfig();
  my $conf;
  eval {
    $conf = $obj->get_imageconfig( $obj->param('config') );
  };
  unless( $conf ) {
    my %T = $vc->image_configs;
    eval {
      $conf = $obj->get_imageconfig( sort keys %T );
    };
  }
  $self->{'page'}->{'_page_type_'} = 'configurator';
  $self->tree->_flush_tree();

  my $rhs_content = sprintf '
      <form id="config" action="%s">', 'this_url';
  my $active = '';
  foreach my $node ($conf->tree->top_level) {
    my $count = 0;
    my $link_key = 'link_'.$node->key;
    my $menu_key = 'menu_'.$node->key;
    $rhs_content .= sprintf '
      <dl class="config_menu" id="%s">
        <dt class="title">%s</dt>', $menu_key, CGI::escapeHTML( $node->get('caption') );
    my $available = 0;
    foreach my $track_node ( $node->descendants ) {
      next if $track_node->get('menu') eq 'no';
      $rhs_content .= sprintf '
        <dt><select id="%s" name="%s">', $track_node->key, $track_node->key;
      my $display = $track_node->get( 'display' ) || 'off';
      my @states  = @{ $track_node->get( 'renderers' ) || [qw(off Off normal Normal)] };
      while( my($K,$V) = splice(@states,0,2) ) {
        $rhs_content .= sprintf '
          <option value="%s"%s>%s</option>', $K, $K eq $display ? ' selected="selected"' : '',  CGI::escapeHTML($V);
      }
      $count ++;
      $rhs_content .= sprintf '
        </select> %s</dt>', $track_node->get('name');
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
      </dl>';
    $active    ||= $link_key if $count > 0;
    $self->create_node(
      $link_key,
      $node->get('caption').( $count ? " ($count)" : '' ), 
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
  warn $panel;
  return $panel;
}

sub _local_context {
  my $self = shift;
  my $hash = {}; #  $self->obj->get_summary_counts;
  $self->{'page'}->local_context->tree(    $self->{_data}{'tree'}    );
  $self->{'page'}->local_context->active(  $self->{_data}{'action'}  );
  $self->{'page'}->local_context->caption( $self->{object}->short_caption  );
  $self->{'page'}->local_context->counts(  $self->{object}->counts   );
}

sub _local_tools {
  my $self = shift;
  my $obj = $self->{object};

  my @data = (
    ['Bookmark this page',  '/Account/Bookmark', 'modal_link' ],
  );
  if( $self->configurable ) {
    push @data, [
      'Configure this page',
      $obj->_url({
        'type' => 'Config',
        'action' => $obj->type.'/'.$obj->action
      }),
      'modal_link'
    ];
  }

  push @data, ['Export Data',     '/sorry.html', 'modal_link' ];

  my $type;
  foreach my $row ( @data ) {
    if( $row->[1] =~ /^http/ ) {
      $type = 'external';
    }
    $self->{'page'}->local_tools->add_entry(
      'type'      => $type,
      'caption'   => $row->[0],
      'url'       => $row->[1],
      'class'     => $row->[2]
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
  my $obj    = $self->{'object'};
  my $panel  = $self->new_panel( 'Summary',
    'code'     => 'summary_panel',
    'object'   => $obj,
    'caption'  => $obj->caption
  );
  $panel->add_component( 'summary' => sprintf( 'EnsEMBL::Web::Component::%s::Summary', $self->type ) );
  $self->add_panel( $panel );
}

sub _content_panel {
  my $self   = shift;
  my $obj    = $self->{'object'};

  my $action = $self->_get_valid_action( $ENV{'ENSEMBL_ACTION'} );
  my $node          = $self->get_node( $action );
  my $title = $node->data->{'concise'}||$node->data->{'caption'};
     $title =~ s/\s*\(.*\[\[.*\]\].*\)\s*//;
     $title = join ' - ', '', ( $obj ? $obj->caption : () ), $title;
  $self->set_title( $title );

  my $previous_node = $node->previous_leaf;
  ## don't show tabs for 'no_menu' nodes
  while( defined($previous_node) && $previous_node->data->{'no_menu_entry'} ) {
    $previous_node = $previous_node->previous_leaf;
  }
  my $next_node     = $node->next_leaf;
  while( defined($next_node) && $next_node->data->{'no_menu_entry'} ) {
    $next_node = $next_node->next_leaf;
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
  };
  
  foreach ( keys %{$options||{}} ) {
    $details->{$_} = $options->{$_};
  }
  
  return $self->tree->create_node( $code, $details );
}

sub create_submenu {
  my ($self, $code, $caption, $options ) = @_;
  my $details = { 'caption'    => $caption, 'url' => '' };
  foreach ( keys %{$options||{}} ) {
    $details->{$_} = $options->{$_};
  }
  return $self->tree->create_node( $code, $details );
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

1;
