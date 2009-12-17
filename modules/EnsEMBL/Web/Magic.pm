# $Id$

package EnsEMBL::Web::Magic;

### Handles script requests, routed through different functions depending on request type.
### Exports:
### stuff        - main page
### modal_stuff  - popup window/modal dialog
### ingredient   - dynamically loaded components
### configurator - popup window/modal dialog configuration page
### menu         - zmenus

use strict;

use Apache2::RequestUtil;
use CGI;

use EnsEMBL::Web::Cache;
use EnsEMBL::Web::Controller;
use EnsEMBL::Web::CoreObjects;
use EnsEMBL::Web::DBSQL::DBConnection;
use EnsEMBL::Web::Proxy::Factory;
use EnsEMBL::Web::RegObj;

use base qw(Exporter);

our @EXPORT = our @EXPORT_OK = qw(stuff modal_stuff ingredient configurator menu);

sub stuff {
  ### Prints the main web page - header, footer, navigation etc, and non dynamically loaded content.
  ### Deals with Command modules if required.
  
  my $r           = shift;
  my $doctype     = shift;
  my $requesttype = shift || 'page';
  
  my ($controller, $factory, $page, $problem) = handler($r, $doctype, $requesttype, 'String');
  
  return unless $controller; # Cache hit or redirecting
  
  my $object = $factory->object;
  
  foreach (@{$factory->DataObjects}) {
    my @sections;
    
    if ($doctype eq 'Popup') {
      @sections = qw(global_context local_context content_panel local_tools);
    } else {
      @sections = qw(global_context local_context modal_context context_panel content_panel local_tools);
    }
    
    $controller->build_page($page, $doctype, $_, @sections);
  }
  
  if (!$controller->process_command($object, $page) && $controller->access_ok($object, $page)) {
    $page->render;
    
    my $content = $page->renderer->content;
    print $content;
    $controller->set_cached_content($content) if $page->{'format'} eq 'HTML' && !$problem;
  }
}

sub modal_stuff {
  ### Wrapper for stuff. Prints popup window/modal dialog.
  
  stuff(shift, 'Popup', 'modal'); 
}

sub ingredient {
  ### Prints the dynamically created components. Loaded either via AJAX (if available) or parallel HTTP requests.
  
  my ($controller, $factory, $page, $problem) = handler(shift, 'Component', undef, 'String');
  
  return unless $controller; # Cache hit
  
  my $object = $factory->object;

  if ($object) {
    $ENV{'ENSEMBL_ACTION'} = $factory->parent->{'ENSEMBL_ACTION'};
    
    $factory->action = $ENV{'ENSEMBL_ACTION'};
    $object->action  = $ENV{'ENSEMBL_ACTION'};
    $controller->build_page($page, 'Dynamic', $object, $ENV{'ENSEMBL_TYPE'} eq 'DAS' ? $ENV{'ENSEMBL_SCRIPT'} : 'ajax_content');
    $page->render;
    
    my $content = $page->renderer->content;
    print $content;
    $controller->set_cached_content($content) if $page->{'format'} eq 'HTML' && !$problem;
  } 
}

sub configurator {
  ### Prints the configuration popup window/modal dialog.
  
  my ($controller, $factory, $page) = handler(shift, 'Configurator', 'modal', 'String');
  
  if (!$controller->update_configuration) { # else config has updated and redirect is occurring
    $controller->build_page($page, 'Popup', $factory->object, qw(user_context configurator));    
    $page->render;
    print $page->renderer->content;
  }
}

sub menu {
  ### Prints the popup zmenus on the images.
  
  my ($controller, $factory) = handler(shift, 'Dynamic', 'menu');
  
  $controller->build_menu($factory->object);
}

sub handler {
  ### Deals with common functionality of all request types.
  ### Returns:
  ### controller (EnsEMBL::Web::Controller)
  ### factory    (EnsEMBL::Web::Proxy::Factory) of type dependant on page
  ### page       (EnsEMBL::Web::Document::[DOCTYPE]) - will be a child of EnsEMBL::Web::Document::Page. Not returned for calls from menu.
  ### problem    boolean - true if the factory has a problem
  ###
  ### Will return nothing if the page is retrieved from the cache, or a redirect is required.
  
  $CGI::POST_MAX = $ENSEMBL_WEB_REGISTRY->species_defs->CGI_POST_MAX; # Set max upload size

  my $r            = shift || Apache2::RequestUtil->can('request') ? Apache2::RequestUtil->request : undef;
  my $doctype      = shift || 'Dynamic';
  my $requesttype  = shift;
  my $renderertype = shift || 'Apache';
  my $input        = new CGI;
  my $species      = $ENV{'ENSEMBL_SPECIES'};
  my $objecttype   = $ENV{'ENSEMBL_TYPE'};
  my $action       = $ENV{'ENSEMBL_ACTION'};
  my $factorytype  = $ENV{'ENSEMBL_FACTORY'} || $input->param('factorytype') || $objecttype;
  my $outputtype   = $objecttype eq 'DAS' ? 'DAS' : undef;
  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $cache        = new EnsEMBL::Web::Cache(enable_compress => 1, compress_threshold => 10000);
  my $controller   = new EnsEMBL::Web::Controller({ r => $r, input => $input, cache => $cache });
  
  $controller->clear_cached_content if $requesttype eq 'page';                    # Conditional - only clears on force refresh of page. 
  
  return if $controller->get_cached_content($requesttype || lc $doctype);         # Page retrieved from cache
  return if $requesttype eq 'page' && $controller->update_configuration_from_url; # Configuration has been updated - will force a redirect
  
  my $problem;
  my $db_connection = $species ne 'common' ? new EnsEMBL::Web::DBSQL::DBConnection($species, $species_defs) : undef;
  my $core_objects  = new EnsEMBL::Web::CoreObjects($input, $db_connection);
  my $factory       = new EnsEMBL::Web::Proxy::Factory($factorytype, {
    _input         => $input,
    _apache_handle => $r,
    _core_objects  => $core_objects,
    _databases     => $db_connection,
    _parent        => $controller->_parse_referer
  });
  
  if ($factory->has_fatal_problem) {
    $problem = $factory->problem('fatal', 'Fatal problem in the factory')->{'fatal'};
  } else {
    eval {
      $factory->createObjects;
    };
    
    $factory->problem('fatal', "Unable to execute createObject on Factory of type $objecttype.", $@) if $@;
    
    $problem = $factory->handle_problem if $factory->has_a_problem; # $factory->handle_problem returns string 'redirect', or array ref of EnsEMBL::Web::Problem object
    
    return if $problem eq 'redirect';                         # Forcing a redirect - don't need to go any further
    return ($controller, $factory) if $requesttype eq 'menu'; # Menus don't need the page code, so skip it
  }
  
  my $renderer_module = "EnsEMBL::Web::Document::Renderer::$renderertype";
  my $document_module = "EnsEMBL::Web::Document::$doctype";
  
  my ($renderer) = $controller->_use($renderer_module, (r => $r, cache => $cache));
  my ($page)     = $controller->_use($document_module, $renderer, undef, $species_defs, $input, $outputtype);
  
  $renderer->{'_modal_dialog_'} = $requesttype eq 'modal' && $r && $r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest'; # Flag indicating that this is modal dialog panel, loaded by AJAX
  
  $page->initialize; # Adds the components to be rendered to the page module
  
  # FIXME: Configurator can work even if factory has a fatal problem? Stupid.
  if ($problem && $doctype ne 'Configurator') {
    $page->add_error_panels($problem);
    
    # Display the error on the page
    if ($factory->has_fatal_problem) {
      $page->render;
      print $page->renderer->content;
      return;
    }
    
    $factory->clear_problems;
  }
  
  return ($controller, $factory, $page, !!$problem);
}

1;
