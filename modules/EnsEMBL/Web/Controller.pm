# $Id$

package EnsEMBL::Web::Controller;

### Deals with basic page building functionality.

use strict;

use CGI::Cookie;

use SiteDefs;

use Bio::EnsEMBL::Registry;

use EnsEMBL::Web::Document::Panel;
use EnsEMBL::Web::OrderedTree;

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $hub) = @_;
    
  my $self = {
    hub        => $hub,
    r          => $hub->apache_handle,
    input      => $hub->input,
    cache      => $hub->cache,
    type       => $hub->type,
    action     => $hub->action,
    function   => $hub->function,
    command    => undef,
    filters    => undef,
  };
  
  if ($self->{'cache'}) {
    my $species_defs = $hub->species_defs;
    
    # Add parameters useful for caching functions
    $self = {
      %$self,
      session_id  => $hub->session->get_session_id,
      url_tag     => $species_defs->ENSEMBL_BASE_URL . $ENV{'REQUEST_URI'},
      cache_debug => $species_defs->ENSEMBL_DEBUG_FLAGS & $species_defs->ENSEMBL_DEBUG_MEMCACHED
    }
  }
  
  bless $self, $class;
  
  return $self;
}

sub hub { return $_[0]->{'hub'}; }

sub get_cached_content {
  ### Attempt to retrieve page and component requests from Memcached
  
  my ($self, $type) = @_;
  
  my $cache = $self->{'cache'};
  my $r     = $self->{'r'};
  
  return unless $cache;
  return if $r->method eq 'POST';
  return unless $type =~ /^(page|component)$/;
  
  $ENV{'CACHE_TAGS'}{'DYNAMIC'} = 1;
  $ENV{'CACHE_TAGS'}{'AJAX'}    = 1;

  $ENV{'CACHE_KEY'} = $ENV{'REQUEST_URI'};
  $ENV{'CACHE_KEY'} .= "::SESSION[$self->{'session_id'}]" if $self->{'session_id'};
  
  if ($type eq 'page') {
    $ENV{'CACHE_TAGS'}{$self->{'url_tag'}} = 1;
    $ENV{'CACHE_KEY'} .= "::USER[$ENV{ENSEMBL_USER_ID}]" if $ENV{'ENSEMBL_USER_ID'}; # If user logged in, some content depends on user
  } else {
    $ENV{'CACHE_TAGS'}{$ENV{'HTTP_REFERER'}} = 1;
    $ENV{'CACHE_KEY'} .= "::WIDTH[$ENV{ENSEMBL_IMAGE_WIDTH}]" if $ENV{'ENSEMBL_IMAGE_WIDTH'};
  }
  
  my $content = $cache->get($ENV{'CACHE_KEY'}, keys %{$ENV{'CACHE_TAGS'}});
  
  if ($content) {
    $r->headers_out->set('X-MEMCACHED' => 'yes');     
    $r->content_type('text/html');
    
    print $content;
    
    warn "DYNAMIC CONTENT CACHE HIT:  $ENV{'CACHE_KEY'}" if $self->{'cache_debug'};
  } else {
    warn "DYNAMIC CONTENT CACHE MISS: $ENV{'CACHE_KEY'}" if $self->{'cache_debug'};
  }
  
  return !!$content;
}

sub set_cached_content {
  ### Attempt to add page and component requests to Memcached
  
  my ($self, $content) = @_;
  
  return unless $self->{'cache'};
  return if $self->{'r'}->method eq 'POST';
  
  $self->{'cache'}->set($ENV{'CACHE_KEY'}, $content, 60*60*24*7, keys %{$ENV{'CACHE_TAGS'}}) if $self->{'cache'};
  
  warn "DYNAMIC CONTENT CACHE SET:  $ENV{'CACHE_KEY'}" if $self->{'cache_debug'};
}

sub clear_cached_content {
  ### Flush the cache if the user has hit ^R or F5.
  ### Removes content from Memcached based on the request's URL and the user's session id.
  
  my $self = shift;
  my $r = $self->{'r'};
  
  if ($self->{'cache'} && ($r->headers_in->{'Cache-Control'} eq 'max-age=0' || $r->headers_in->{'Pragma'} eq 'no-cache') && $r->method ne 'POST') {
    $self->{'cache'}->delete_by_tags($self->{'url_tag'}, $self->{'session_id'} ? "session_id[$self->{'session_id'}]" : ());
    
    warn "DYNAMIC CONTENT CACHE CLEAR: $self->{'url_tag'}, $self->{'session_id'}" if $self->{'cache_debug'};
  }
}

sub build_page {
  ### Creates Configuration modules and calls relevant functions (determined by @functions) in order to create the page.
  
  my ($self, $page, $doctype, $model, @functions) = @_;
  
  my $object = $model->object;
  my $type;
  
  if (ref $object) { # Actual object
    $type = $object->__objecttype;
    $object->viewconfig->form($object);
  } elsif ($object =~ /^\w+$/) { # String (type of E::W object)
    $type = $object;
  } elsif ($model->type) { ## No domain objects created on page startup
    $type = $model->type;
  } else {
    $type = 'Static';
  }
  
  $type = 'DAS' if $type =~ /^DAS::.+/;
  
  my @plugins = ('EnsEMBL::Web', '', @$ENSEMBL_PLUGINS);
  my $functions_called = {};
  my $common_conf = {
    tree         => new EnsEMBL::Web::OrderedTree,
    default      => undef,
    action       => undef,
    configurable => 0,
    doctype      => $doctype
  };
  
  my %configs;
  
  # Loop through the EnsEMBL root directory and plugins
  while (my ($module_root) = splice @plugins, 0, 2) {
    my $config_module_name = "${module_root}::Configuration::$type"; # First work out what the module name is, to see if it can be used
    my ($configuration, $error) = $self->_use($config_module_name, $page, $model, $common_conf);
    
    if ($configuration) {
      $configs{$_} = [ $configuration, $config_module_name ] for grep $configuration->can($_), @functions; 
    } elsif ($error) {
      # Handle "use" failures gracefully, but skip "Can't locate" errors
      $self->add_error_panel($page, 
        'Configuration module compilation error',
        '<p>Unable to use Configuration module <strong>%s</strong> due to the following error:</p><pre>%s</pre>',
        $config_module_name, $error
      );
    }
  }
  
  # Loop through the functions to configure
  foreach my $func (@functions) {
    # Get the configuration module for that function
    my ($configuration, $config_module_name) = @{$configs{$func}};
    
    eval {
      $configuration->$func();
    };
    
    # Catch any errors and display as a "configuration runtime error"
    if ($@) {
      warn ">>> FUNCTION $func failed: $@";
      
      $page->content->add_panel($page,
        'Configuration module runtime error',
        '<p>Unable to execute configuration %s from configuration module <strong>%s</strong> due to the following error:</p><pre>%s</pre>', 
        $_, $config_module_name, $@
      );
    } else {
      $functions_called->{$func} = 1;
      
      my $node = $configuration->get_node($configuration->_get_valid_action($self->{'action'}, $self->{'function'}));
      
      if ($node) {
        $self->{'command'} = $node->data->{'command'};
        $self->{'filters'} = $node->data->{'filters'};
      }
    }
  }
  
  # Handle errors for functions which failed
  foreach my $func (@functions) {
    if (!$functions_called->{$func}) {
      if ($type eq 'DAS') {
        $self->add_error_panel($page, 'Fatal error - bad request', 'Unimplemented');
      } else {
        warn "Can't do configuration function $func on $type objects, or an error occurred when executing that function.";
      }
    }
  }
}

sub build_menu {
  ### Creates a ZMenu module based on the object type and action of the page (see below), and renders the menu
  
  my ($self, $model) = @_;
  
  return unless $model;
  
  my $object = $model->object;
  
  return unless $object;
 
  # Force values of action and type because apparently require "EnsEMBL::Web::ZMenu::::Gene" (for eg) doesn't fail. Stupid perl.
  my $type     = $model->hub->type   || 'NO_TYPE';
  my $action   = $model->hub->action || 'NO_ACTION';
  my @packages = ('EnsEMBL::Web', '', @$ENSEMBL_PLUGINS);
  
  my $menu;
  
  ### Check for all possible module permutations.
  ### This way we can have, for example, ZMenu::Contig and ZMenu::Contig::Gene (contig menu with Gene page specific functionality),
  ### and also ZMenu::Gene and ZMenu::Gene::ComparaTree (has a similar menu to that of a gene, but has a different glyph in the drawing code)
  my @modules = (
    "::ZMenu::$type",
    "::ZMenu::$action",
    "::ZMenu::${type}::$action",
    "::ZMenu::${action}::$type"
  );
  
  while (my ($module_root) = splice @packages, 0, 2) {    
    my $module_name = [ map { $self->dynamic_use("$module_root$_") ? "$module_root$_" : () } @modules ]->[-1];
    
    if ($module_name) {
      $menu = $module_name->new($object, $menu);
    } else {
      my $error = $self->dynamic_use_failure("$module_root$modules[-1]");
      warn $error unless $error =~ /^Can't locate/;
    }
  }
  
  $self->{'r'}->content_type('text/plain');
  
  $menu->render if $menu;
}

sub update_configuration {
  ### Checks to see if the page's view config or image config has been changed
  ### If it has, returns 1 to force a redirect to the updated page
  ### This function is only called during EnsEMBL::Web::Magic::configurator requests
  
  my $self  = shift;
  my $input = $self->{'input'};
    
  if ($input->param('submit') || $input->param('reset')) {
    my $r          = $self->{'r'};
    my $session    = $self->hub->session;
    my $type       = $self->{'type'};
    my $action     = $self->{'action'};
    my $config     = $input->param('config');
    
    $session->set_input($input);
    
    my $view_config = $session->getViewConfig($type, $action);
    
    # Updating an image config
    if ($config && $view_config->has_image_config($config)) {
      # If we have multiple species in the view (e.g. Align Slice View) then we would
      # need to make sure that the image config we have is a merged image config, with
      # each of the trees for each species combined
      $view_config->altered = $session->getImageConfig($config, $config, 'merged')->update_from_input($input); 
    } else { # Updating a view config
      $view_config->update_from_input($input);
      
      if ($action ne 'ExternalData') {
        my $vc_external_data = $session->getViewConfig($type, 'ExternalData');
        $vc_external_data->update_from_input($input) if $vc_external_data;
      }
      
      my $cookie_host  = $session->get_species_defs->ENSEMBL_COOKIEHOST;
      my $cookie_width = $input->param('cookie_width');
      my $cookie_ajax  = $input->param('cookie_ajax');
      
      # Set width
      if ($cookie_width && $cookie_width != $ENV{'ENSEMBL_IMAGE_WIDTH'}) {
        my $cookie = new CGI::Cookie(
          -name    => 'ENSEMBL_WIDTH',
          -value   => $cookie_width,
          -domain  => $cookie_host,
          -path    => '/',
          -expires => $cookie_width =~ /\d+/ ? 'Monday, 31-Dec-2037 23:59:59 GMT' : 'Monday, 31-Dec-1970 00:00:01 GMT'
        );
        
        $r->headers_out->add('Set-cookie' => $cookie);
        $r->err_headers_out->add('Set-cookie' => $cookie);
      }
      
      # Set ajax cookie
      if ($cookie_ajax && $cookie_ajax ne $ENV{'ENSEMBL_AJAX_VALUE'}) {
        my $cookie = new CGI::Cookie(
          -name    => 'ENSEMBL_AJAX',
          -value   => $cookie_ajax,
          -domain  => $cookie_host,
          -path    => '/',
          -expires => 'Monday, 31-Dec-2037 23:59:59 GMT'
        );
        
        $r->headers_out->add('Set-cookie' => $cookie);
        $r->err_headers_out->add('Set-cookie' => $cookie);
      }
    }
    
    $session->store;
    
    if ($input->param('submit')) {
      if ($r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest') {
        $r->content_type('text/plain');
        print 'SUCCESS';
      } else {
        $input->redirect; # refreshes the page
      }
      
      return 1;
    }
  }
}

sub update_configuration_from_url {
  ### Checks for shared data and updated config settings from the URL parameters
  ### If either exist, returns 1 to force a redirect to the updated page
  ### This function is only called during main page (EnsEMBL::Web::Magic::stuff) requests
  
  my $self      = shift;
  my $input     = $self->{'input'};
  my $session   = $self->hub->session;
  my @share_ref = $input->param('share_ref');
  my $url;
  
  $session->set_input($input);
  
  if (@share_ref) {
    $session->receive_shared_data(@share_ref); # This should push a message onto the message queue
    $input->delete('share_ref');
    $url = $input->self_url;
  }
  
  my $view_config = $session->getViewConfig($self->{'type'}, $self->{'action'});
  my $new_url     = $view_config->update_from_config_strings($session, $self->{'r'}); # This should push a message onto the message queue
  
  $url = $new_url if $new_url;
  
  if ($url) {
    my @t = split /\?/, $url;
    $t[1] =~ s/%3A/:/g; # Unescape : in query string generated by $input->self_url
    $url = join '?', @t;
    
    $input->redirect($url); # If something has changed then we redirect to the new page
    return 1;
  }
}

sub process_command {
  ### Handles Command modules and the Framework-based database frontend. 
  ### Once the command has been processed, a redirect to a Component page will occur.
  
  my ($self, $model, $page, $problem) = @_;

  if ($self->{'command'} eq 'db_frontend') {
    my $type     = $model->hub->type;
    my $action   = $model->hub->action;
    my $function = $model->hub->function || 'Display';

    # Look for all possible modules for this URL, in order of specificity and likelihood
    my @classes = (
      "EnsEMBL::Web::Component::${type}::${action}::$function",
      "EnsEMBL::Web::Command::${type}::${action}::$function",
      "EnsEMBL::Web::Component::DbFrontend::$function",
      "EnsEMBL::Web::Command::DbFrontend::$function"
    );

    foreach my $class (@classes) {
      if ($class && $self->dynamic_use($class) && $self->access_ok($model, $page)) {
        if ($class =~ /Command/) {
          my $command = $class->new({
            object => $model->object,
            page   => $page
          });
          
          $command->process;
          return 1;
        } else {
          $page->render;
          my $content = $page->renderer->content;
          print $content;
          $self->set_cached_content($content) if $page->{'format'} eq 'HTML' && !$problem;
        }
      }
    }
  } else {
    # Normal command module
    my $class = $self->{'action'} eq 'Wizard' ? 'EnsEMBL::Web::Command::Wizard' : $self->{'command'};
    
    if ($class && $self->dynamic_use($class) && $self->access_ok($model, $page)) {    
      my $command = $class->new({
        object => $model->object,
        page   => $page
      });
    
      $command->process;
      return 1;
    }
  }
}

sub _use {
  ### Wrapper for EnsEMBL::Web::Root::dynamic_use.
  ### Returns either a newly created module or the error detailing why the new function failed.
  ### Skips "Can't locate" errors - these come from trying to use non-existant modules in plugin directories and can be safely ignored.
  
  my $self = shift;
  my $module_name = shift;
  
  my $module = $self->dynamic_use($module_name) ? $module_name->new(@_) : undef;
  my $error;
  
  if (!$module) {
    $error = $self->dynamic_use_failure($module_name);
    $error = undef if $error =~ /^Can't locate/;
  }
  
  return ($module, $error);
}

sub access_ok {
  ### Checks if the given Command module is allowed, and forces a redirect if it isn't
  
  my ($self, $model, $page) = @_;
  
  my $r      = $self->{'r'};
  my $filter = $self->not_allowed($model->object);
  
  if ($filter) {
    my $url = $filter->redirect_url;
    
    # Double-check that a filter name is being passed, since we have the option 
    # of using the default URL (current page) rather than setting it explicitly
    $url .= ($url =~ /\?/ ? ';' : '?') . 'filter_module=' . $filter->name       unless $url =~ /filter_module/;
    $url .= ($url =~ /\?/ ? ';' : '?') . 'filter_code='   . $filter->error_code unless $url =~ /filter_code/;
    
    $page->ajax_redirect($url);
    return 0;
  }
  
  return 1;
}

sub add_error_panel {
  ### Wrapper for 
  
  my ($self, $page, $caption, $template, @content) = @_;
  my $error = $self->_format_error(pop @content);
  
  $page->content->add_panel(new EnsEMBL::Web::Document::Panel(
    caption => $caption,
    content => sprintf($template, @content, $error)
  ));
}

sub DESTROY { Bio::EnsEMBL::Registry->disconnect_all; }

1;
