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
  
  return unless $hub->param('submit') || $hub->param('reset');
  
  my $r            = $self->r;
  my $session      = $hub->session;
  my $type         = $hub->type;
  my $view_config  = $hub->get_viewconfig($hub->action);
  my $updated      = $view_config->update_from_input;
  my $cookie_host  = $hub->species_defs->ENSEMBL_COOKIEHOST;
  my $image_width  = $hub->param('image_width');
  my $cookie_ajax  = $hub->param('cookie_ajax');
  my @cookies;
  
  # Set width
  if ($image_width && $image_width != $ENV{'ENSEMBL_IMAGE_WIDTH'}) {
    push @cookies, new CGI::Cookie(
      -name    => 'ENSEMBL_WIDTH',
      -value   => $image_width,
      -domain  => $cookie_host,
      -path    => '/',
      -expires => $image_width =~ /\d+/ ? 'Monday, 31-Dec-2037 23:59:59 GMT' : 'Monday, 31-Dec-1970 00:00:01 GMT'
    );
  }
  
  # Set ajax cookie
  if ($cookie_ajax && $cookie_ajax ne $ENV{'ENSEMBL_AJAX_VALUE'}) {
    push @cookies, new CGI::Cookie(
      -name    => 'ENSEMBL_AJAX',
      -value   => $cookie_ajax,
      -domain  => $cookie_host,
      -path    => '/',
      -expires => 'Monday, 31-Dec-2037 23:59:59 GMT'
    );
  }
  
  foreach my $cookie (@cookies) {
    $r->$_->add('Set-cookie' => $cookie) for qw(headers_out err_headers_out);
  }
  
  $session->store;
  
  if ($hub->param('submit')) {
    if ($r->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest') {
      my $json = {};
      
      if ($hub->action =~ /^(ExternalData|TextDAS)$/) {
        my $function = $view_config->altered == 1 ? undef : $view_config->altered;
        
        $json = {
          redirect => $hub->url({ 
            action   => 'ExternalData', 
            function => $function, 
            %{$hub->referer->{'params'}}
          })
        };
      } elsif ($updated || $hub->param('reload')) {
        $json = $updated if ref $updated eq 'HASH';
        $json->{'updated'} = 1;
      }
      
      $r->content_type('text/plain');
      
      print $self->jsonify($json || {});
    } else {
      $hub->redirect; # refreshes the page
    }
    
    return 1;
  }
}

1;
