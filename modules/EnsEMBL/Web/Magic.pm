# $Id$

package EnsEMBL::Web::Magic;

### NAME: Magic.pm
### Converts Apache requests into web pages or HTML fragments

### PLUGGABLE: No 

### STATUS: Stable
### Any changes to this module should not affect external users

### DESCRIPTION:
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
use EnsEMBL::Web::Resource;

use base qw(Exporter);

our @EXPORT = our @EXPORT_OK = qw(stuff modal_stuff ingredient configurator menu);

sub stuff {
  ### Prints the main web page - header, footer, navigation etc, and non dynamically loaded content.
  ### Deals with Command modules if required.
  
  my $r           = shift;
  my $doctype     = shift;
  my $requesttype = shift || 'page';
  
  my ($controller, $resource, $page, $problem) = handler($r, $doctype, $requesttype, 'String');
  
  return unless $controller; # Cache hit or redirecting
  
  my @sections;
    
  if ($doctype eq 'Popup') {
    @sections = qw(global_context local_context content_panel local_tools);
  } else {
    @sections = qw(global_context local_context modal_context context_panel content_panel local_tools);
  }
    
  $controller->build_page($page, $doctype, $resource, @sections);
  
  if (!$controller->process_command($resource, $page) && $controller->access_ok($resource, $page)) {
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
  
  my ($controller, $resource, $page, $problem) = handler(shift, 'Component', undef, 'String');
  
  return unless $controller; # Cache hit
  
  if ($resource->object) {
    # Set action of component to be the same as the action of the parent page - needed for view configs to be correctly created
    $ENV{'ENSEMBL_ACTION'} = $resource->parent->{'ENSEMBL_ACTION'};
    
    $resource->object->action = $ENV{'ENSEMBL_ACTION'};
    $controller->build_page($page, 'Dynamic', $resource, $ENV{'ENSEMBL_TYPE'} eq 'DAS' ? $ENV{'ENSEMBL_SCRIPT'} : 'ajax_content');
    $page->render;
    
    my $content = $page->renderer->content;
    print $content;
    $controller->set_cached_content($content) if $page->{'format'} eq 'HTML' && !$problem;
  }
}

sub configurator {
  ### Prints the configuration modal dialog.
  
  my ($controller, $resource, $page) = handler(shift, 'Configurator', 'modal', 'String');
  
  if (!$controller->update_configuration) { # else config has updated and redirect is occurring
    $controller->build_page($page, 'Popup', $resource, qw(user_context configurator));    
    $page->render;
    print $page->renderer->content;
  }
}

sub menu {
  ### Prints the popup zmenus on the images.
  
  my ($controller, $resource) = handler(shift, 'Dynamic', 'menu');
  
  $controller->build_menu($resource);
}

sub handler {
  ### Deals with common functionality of all request types.
  ### Returns:
  ### controller (EnsEMBL::Web::Controller)
  ### resource   (EnsEMBL::Web::Resource)
  ### page       (EnsEMBL::Web::Document::[DOCTYPE]) - will be a child of EnsEMBL::Web::Document::Page. Not returned for calls from menu.
  ### problem    boolean - true if the factory has a problem
  ###
  ### Will return nothing if the page is retrieved from the cache, or a redirect is required.

  my $r            = shift || Apache2::RequestUtil->can('request') ? Apache2::RequestUtil->request : undef;
  my $doctype      = shift || 'Dynamic';
  my $requesttype  = shift;
  my $renderertype = shift || 'Apache';
  my $input        = new CGI;
  my $resource     = new EnsEMBL::Web::Resource({ _input => $input, _apache_handle => $r }); # The resource object is used throughout the code to store data objects, connections and parameters 
  my $factorytype  = $ENV{'ENSEMBL_FACTORY'} || $input->param('factorytype') || $resource->type;
  my $outputtype   = $resource->type eq 'DAS' ? 'DAS' : undef;
  my $controller   = new EnsEMBL::Web::Controller($resource->hub);
  
  $controller->clear_cached_content if $requesttype eq 'page';                    # Conditional - only clears on force refresh of page. 
  
  $CGI::POST_MAX = $resource->species_defs->CGI_POST_MAX;                         # Set max upload size
  
  return if $controller->get_cached_content($requesttype || lc $doctype);         # Page retrieved from cache
  return if $requesttype eq 'page' && $controller->update_configuration_from_url; # Configuration has been updated - will force a redirect
  
  my $problem = $resource->create_models($factorytype);
  
  return if $problem eq 'redirect';                          # Forcing a redirect - don't need to go any further
  return ($controller, $resource) if $requesttype eq 'menu'; # Menus don't need the page code, so skip it
  
  my $renderer_module = "EnsEMBL::Web::Document::Renderer::$renderertype";
  my $document_module = "EnsEMBL::Web::Document::Page::$doctype";
  
  my ($renderer) = $controller->_use($renderer_module, (r => $r, cache => $resource->cache));
  my ($page)     = $controller->_use($document_module, { 
    renderer     => $renderer, 
    species_defs => $resource->species_defs, 
    input        => $input, 
    outputtype   => $outputtype
  });
  
  $renderer->{'_modal_dialog_'} = $requesttype eq 'modal' && $r && $r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest'; # Flag indicating that this is modal dialog panel, loaded by AJAX
  
  $page->initialize; # Adds the components to be rendered to the page module
  
  # FIXME: Configurator can work even if factory has a fatal problem? Stupid.
  if ($problem && $doctype ne 'Configurator') {
    $page->add_error_panels($problem);
    
    # Abort page construction if any fatal problems present
    if (grep $_->isFatal, @$problem) {
      $page->render;
      print $page->renderer->content;
      return;
    }
  }
  
  return ($controller, $resource, $page, !!$problem);
}


1;
