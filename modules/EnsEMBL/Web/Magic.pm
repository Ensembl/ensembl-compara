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
use EnsEMBL::Web::Model;
use EnsEMBL::Web::Builder;

use base qw(Exporter);

our @EXPORT = our @EXPORT_OK = qw(stuff modal_stuff ingredient configurator menu);

sub stuff {
  ### Prints the main web page - header, footer, navigation etc, and non dynamically loaded content.
  ### Deals with Command modules if required.
  
  my $r           = shift;
  my $doctype     = shift;
  my $requesttype = shift || 'page';
  
  my ($controller, $model, $page, $problem) = handler($r, $doctype, $requesttype, 'String');
  
  return unless $controller; # Cache hit or redirecting
  
  my @sections;
    
  if ($doctype eq 'Popup') {
    @sections = qw(check_filters global_context local_context content_panel local_tools);
  } else {
    @sections = qw(check_filters global_context local_context modal_context context_panel content_panel local_tools);
  }
 
  # FIXME - why do we build the page before we check to see if it's a 
  # command and/or accessible?   
  $controller->build_page($page, $doctype, $model, @sections);
  
  if (!$controller->process_command($model, $page, $problem) && $controller->access_ok($model, $page)) {
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
  
  my ($controller, $model, $page, $problem) = handler(shift, 'Component', undef, 'String');
  
  return unless $controller; # Cache hit
  
  if ($model->object) {
    # Set action of component to be the same as the action of the parent page - needed for view configs to be correctly created
    $ENV{'ENSEMBL_ACTION'} = $model->hub->parent->{'ENSEMBL_ACTION'};
    $model->object->__data->{'_action'} = $ENV{'ENSEMBL_ACTION'};
    $model->hub->action = $ENV{'ENSEMBL_ACTION'};
    
    $controller->build_page($page, 'Dynamic', $model, $ENV{'ENSEMBL_TYPE'} eq 'DAS' ? $ENV{'ENSEMBL_SCRIPT'} : 'ajax_content');
    $page->render;
    
    my $content = $page->renderer->content;
    print $content;
    $controller->set_cached_content($content) if $page->{'format'} eq 'HTML' && !$problem;
  }
}

sub configurator {
  ### Prints the configuration modal dialog.
  
  my ($controller, $model, $page) = handler(shift, 'Configurator', 'modal', 'String');
  
  if (!$controller->update_configuration) { # else config has updated and redirect is occurring
    $controller->build_page($page, 'Popup', $model, qw(user_context configurator));    
    $page->render;
    print $page->renderer->content;
  }
}

sub menu {
  ### Prints the popup zmenus on the images.
  
  my ($controller, $model) = handler(shift, 'Dynamic', 'menu');
  warn "URL ".$ENV{'REQUEST_URI'};
  warn "HUB ".$model->hub->type.'/'.$model->hub->action;
  
  $controller->build_menu($model);
}

sub handler {
  ### Deals with common functionality of all request types.
  ### Returns:
  ### controller (EnsEMBL::Web::Controller)
  ### model   (EnsEMBL::Web::Model)
  ### page       (EnsEMBL::Web::Document::[DOCTYPE]) - will be a child of EnsEMBL::Web::Document::Page. Not returned for calls from menu.
  ### problem    boolean - true if the factory has a problem
  ###
  ### Will return nothing if the page is retrieved from the cache, or a redirect is required.

  my $r            = shift || Apache2::RequestUtil->can('request') ? Apache2::RequestUtil->request : undef;
  my $doctype      = shift || 'Dynamic';
  my $requesttype  = shift;
  my $renderertype = shift || 'Apache';
  my $input        = new CGI;
  my $model        = new EnsEMBL::Web::Model({ _input => $input, _apache_handle => $r }); # The model object is used throughout the code to store data objects, connections and parameters 
  my $hub          = $model->hub;
  my $factorytype  = $input->param('factorytype') || $hub->type;
  my $outputtype   = $hub->type eq 'DAS' ? 'DAS' : undef;
  my $controller   = new EnsEMBL::Web::Controller($hub);
  
  $controller->clear_cached_content if $requesttype eq 'page';                    # Conditional - only clears on force refresh of page. 
  
  $CGI::POST_MAX = $hub->species_defs->CGI_POST_MAX;                         # Set max upload size
  
  return if $controller->get_cached_content($requesttype || lc $doctype);         # Page retrieved from cache
  return if $requesttype eq 'page' && $controller->update_configuration_from_url; # Configuration has been updated - will force a redirect

  my $builder = new EnsEMBL::Web::Builder($model);
  my $problem = $builder->create_objects($factorytype, $requesttype);
  
  return if $problem eq 'redirect';                          # Forcing a redirect - don't need to go any further
  return ($controller, $model) if $requesttype eq 'menu'; # Menus don't need the page code, so skip it
  
  my $renderer_module = "EnsEMBL::Web::Document::Renderer::$renderertype";
  my $document_module = "EnsEMBL::Web::Document::Page::$doctype";
  
  my ($renderer) = $controller->_use($renderer_module, (r => $r, cache => $hub->cache));
  my ($page)     = $controller->_use($document_module, { 
    hub          => $hub,
    renderer     => $renderer, 
    species_defs => $hub->species_defs, 
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
  
  return ($controller, $model, $page, !!$problem);
}


1;
