# $Id$

package EnsEMBL::Web::Controller::Config;

### Prints the configuration modal dialog.

use strict;

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
  
  my $r           = $self->r;
  my $type        = $hub->type;
  my $view_config = $hub->get_viewconfig($hub->action);
  my $updated     = $view_config->update_from_input;
  
  $hub->session->store;
  
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
