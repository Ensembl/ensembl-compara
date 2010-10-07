# $Id$

package EnsEMBL::Web::Controller::Config;

### Prints the configuration modal dialog.

use strict;

use CGI::Cookie;

use base qw(EnsEMBL::Web::Controller::Modal);

sub page_type { return 'Configurator'; }

sub init {
  my $self = shift;
  
  $self->SUPER::init unless $self->update_configuration; # config has updated and redirect is occurring
}

sub update_configuration {
  ### Checks to see if the page's view config or image config has been changed
  ### If it has, returns 1 to force a redirect to the updated page
  
  my $self = shift;
  my $hub  = $self->hub;
  
  if ($hub->param('submit') || $hub->param('reset')) {
    my $r           = $self->r;
    my $session     = $hub->session;
    my $type        = $self->type;
    my $action      = $self->action;
    my $config      = $hub->param('config');
    my $view_config = $hub->viewconfig;
    
    # Updating an image config
    if ($config && $view_config->has_image_config($config)) {
      # If we have multiple species in the view (e.g. Align Slice View) then we would
      # need to make sure that the image config we have is a merged image config, with
      # each of the trees for each species combined      
      $view_config->altered = $hub->get_imageconfig($config, $config, 'merged')->update_from_input;
    } else { # Updating a view config
      $view_config->update_from_input;
      
      if ($action ne 'ExternalData') {
        my $vc_external_data = $hub->get_viewconfig($type, 'ExternalData');
        $vc_external_data->update_from_input if $vc_external_data;
      }
      
      my $cookie_host  = $self->species_defs->ENSEMBL_COOKIEHOST;
      my $cookie_width = $hub->param('cookie_width');
      my $cookie_ajax  = $hub->param('cookie_ajax');
      
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
    
    if ($hub->param('submit')) {
      if ($r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest') {
        $r->content_type('text/plain');
        print 'SUCCESS';
      } else {
        $hub->redirect; # refreshes the page
      }
      
      return 1;
    }
  }
}

1;
