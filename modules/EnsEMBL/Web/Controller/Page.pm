=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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
use warnings;

use URI::Escape qw(uri_unescape);

use parent qw(EnsEMBL::Web::Controller);

sub request {
  return 'page';
}

sub init {
  my $self  = shift;
  my $hub   = $self->hub;

  # Clear already existing cache if required
  $self->clear_cached_content;

  # Try to retrieve content from cache
  my $cached = $self->get_cached_content;

  if (!$cached) {
    $self->builder->create_objects;
    $self->configure;
    $self->update_configuration_for_request;
  }

  $self->update_user_history if $hub->user;

  return if $cached;

  $self->page->initialize; # Adds the components to be rendered to the page module
  $self->render_page;
}

sub render_page {
  my $self = shift;
  my $hub  = $self->hub;
  
  $self->SUPER::render_page if $self->access_ok && !$self->process_command;
}

sub update_configuration_for_request {
  ## Checks for shared data and updates config settings from the URL and POST parameters
  ## TODO - handle share userdata via url - did not work in 84 either
  my $self        = shift;
  my $r           = $self->r;
  my $input       = $self->input;
  my $hub         = $self->hub;
  my $core_params = $hub->core_params;
  my @components  = @{$self->configuration->get_configurable_components};

  my $do_redirect = 0;

  # Go through each view config and get a list of required params
  my @view_config = map $hub->get_viewconfig({'type' => $components[$_][1], 'component' => $components[$_][0]}), 0..$#components;
  my %url_params  = map { $_ => 1 } map $_->config_url_params, @view_config;
  my %inp_params;

  # Get all the required params from the url and delete the one in the url
  for (keys %url_params) {
    my @vals = $input->param($_);
    if (@vals) {
      $input->delete($_);
      $url_params{$_} = scalar @vals > 1 ? \@vals : $vals[0];
    } else {
      delete $url_params{$_}; # delete the params not present in the url
    }
  }

  # Get all the non-core GET/POST params to pass them to the update_for_input method
  for ($input->param) {
    next if $core_params->{$_};
    my @vals = $input->param($_);
    $inp_params{$_} = scalar @vals > 1 ? \@vals : $vals[0];
  }

  # now update all the view configs accordingly
  for (@view_config) {
    if (keys %inp_params) {
      $_->update_from_input({ %inp_params }); # avoid passing reference to the original hash to prevent manipulation
    }
    if (keys %url_params) {
      $_->update_from_url({ %url_params });
      $do_redirect++;
    }
  }

  if ($do_redirect) {
    $input->param('time', time); # Add time to cache-bust the browser
    $hub->redirect(join('?', $r->uri, uri_unescape($input->query_string)));
  }
}

sub process_command {
  ### Handles Command modules and the Framework-based database frontend. 
  ### Once the command has been processed, a redirect to a Component page will occur.
  
  my $self    = shift;
  my $command = $self->command;
  my $action  = $self->action;
  
  my $object  = $self->object;
  my $page    = $self->page;
  my $builder = $self->builder;
  my $hub     = $self->hub;
  my $node    = $self->node;
  
  if ($command && $self->dynamic_use($command)) {
    my $command_module = $command->new({
      object => $object,
      hub    => $hub,
      page   => $page,
      node   => $node
    });
    
    my $rtn = $command_module->process;
     
    return defined $rtn ? $rtn : 1;
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
