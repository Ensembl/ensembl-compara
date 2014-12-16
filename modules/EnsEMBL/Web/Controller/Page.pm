=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Controller::Page;

### Prints the main web page - header, footer, navigation etc, and non dynamically loaded content.
### Deals with Command modules if required.

use strict;

use URI::Escape qw(uri_unescape);

use EnsEMBL::Web::Cookie;

use base qw(EnsEMBL::Web::Controller);

sub request   { return 'page'; }
sub cacheable { return 1;      }

sub init {
  my $self    = shift;
  my $hub     = $self->hub;
  my $request = $self->request;
  
  $self->clear_cached_content;
  
  my $cached = $self->get_cached_content($request); # Page retrieved from cache
  
  if (!$cached) {
    my $redirect = $self->builder->create_objects($hub->factorytype, $request) eq 'redirect'; # Build objects before checking configuration - they are needed by Configuration.pm
    $self->configure;                                                                         # Set hub->components before checking configuration
    return if $self->update_configuration_from_url || $redirect;                              # Redirect if a configuration has been updated or object parameters have changed
  }
  
  $self->update_user_history if $hub->user;
  
  return if $cached;
  
  $self->page->initialize; # Adds the components to be rendered to the page module
  $self->render_page;
}

sub render_page {
  my $self = shift;
  my $hub  = $self->hub;
  
  # Set cookies for toggleable content, then delete the param so it doesn't appear on any links in the page
  foreach (grep /^toggle_.+/, $hub->param) {
    $hub->set_cookie($_, $hub->param($_));
    $hub->delete_param($_);
  }
  
  $self->SUPER::render_page if $self->access_ok && !$self->process_command;
}

sub update_configuration_from_url {
  ### Checks for shared data and updated config settings from the URL parameters
  ### If either exist, returns 1 to force a redirect to the updated page
  ### This function is only called during main page (EnsEMBL::Web::Magic::stuff) requests
  
  my $self       = shift;
  my $r          = $self->r;
  my $input      = $self->input;
  my $hub        = $self->hub;
  my $session    = $hub->session;
  my @share_ref  = $input->param('share_ref');
  my @components = @{$self->configuration->get_configurable_components};
  my $new_url;
  
  if (@share_ref) {
    $session->receive_shared_data(@share_ref); # This should push a message onto the message queue
    $input->delete('share_ref');
    $new_url = 1;
  }
  
  $new_url += $hub->get_viewconfig(@{$components[$_]})->update_from_url($r, $_ == $#components) for 0..$#components; # This should push a message onto the message queue
  
  if ($new_url) {
    if (keys %{$hub->species_defs->ENSEMBL_MIRRORS || {}}) {
      my $redirect_cookie = EnsEMBL::Web::Cookie->new($r, {'name' => 'redirect_mirror_url'});
      $redirect_cookie->value($r->unparsed_uri);
      $redirect_cookie->bake;
    }
    $input->param('time', time); # Add time to cache-bust the browser
    $input->redirect(join '?', $r->uri, uri_unescape($input->query_string)); # If something has changed then we redirect to the new page  
    return 1;
  }
}

sub process_command {
  ### Handles Command modules and the Framework-based database frontend. 
  ### Once the command has been processed, a redirect to a Component page will occur.
  
  my $self    = shift;
  my $command = $self->command;
  my $action  = $self->action;
  
  return unless $command || $action eq 'Wizard';
  
  my $object  = $self->object;
  my $page    = $self->page;
  my $builder = $self->builder;
  my $hub     = $self->hub;
  my $node    = $self->node;
  
  if ($command eq 'db_frontend') {
    my $type     = $self->type;
    my $function = $self->function || 'Display';

    # Look for all possible modules for this URL, in order of specificity and likelihood
    my @classes = (
      "EnsEMBL::Web::Component::${type}::${action}::$function",
      "EnsEMBL::Web::Command::${type}::${action}::$function",
      "EnsEMBL::Web::Component::DbFrontend::$function",
      "EnsEMBL::Web::Command::DbFrontend::$function"
    );

    foreach my $class (@classes) {
      if ($self->dynamic_use($class)) {
        if ($class =~ /Command/) {
          my $command_module = $class->new({
            object => $object,
            hub    => $hub,
            page   => $page,
            node   => $node
          });
          
          my $rtn = $command_module->process;
          
          return defined $rtn ? $rtn : 1;
        } else {
          $self->SUPER::render_page;
        }
      }
    }
  } else {
    # Normal command module
    my $class = $action eq 'Wizard' ? 'EnsEMBL::Web::Command::Wizard' : $command;
    
    if ($class && $self->dynamic_use($class)) {
      my $command_module = $class->new({
        object => $object,
        hub    => $hub,
        page   => $page,
        node   => $node
      });
      
      my $rtn = $command_module->process;
      
      return defined $rtn ? $rtn : 1;
    }
  }
}

sub access_ok {
  ### Checks if the given Command module is allowed, and forces a redirect if it isn't
  
  my $self = shift;
  
  my $filter = $self->not_allowed($self->hub, $self->object);
  
  if ($filter) {
    my $url = $filter->redirect_url;
    
    # Double-check that a filter name is being passed, since we have the option 
    # of using the default URL (current page) rather than setting it explicitly
    $url .= ($url =~ /\?/ ? ';' : '?') . 'filter_module=' . $filter->name       unless $url =~ /filter_module/;
    $url .= ($url =~ /\?/ ? ';' : '?') . 'filter_code='   . $filter->error_code unless $url =~ /filter_code/;
    
    $self->page->ajax_redirect($url);
    
    return 0;
  }
  
  return 1;
}

1;
