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

package EnsEMBL::Web::Controller::Config;

### Prints the configuration modal dialog and accepts config change request when the same dialog form us submitted

use strict;
use warnings;

use JSON;

use EnsEMBL::Web::Exceptions qw(WebException);

use parent qw(EnsEMBL::Web::Controller::Modal);

sub init {
  ## @override
  my $self  = shift;
  my $hub   = $self->hub;
  my $r     = $self->r;

  # if function provided, call the mapping function and return json
  if (my $function = $hub->function) {
    my $response = {};

    if (my $sub = $self->can('json_'.$function)) {
      $response = $sub->($self);
    }

    $r->content_type('text/plain');
    $r->print(to_json($response));
    return;
  }

  # submit request returns just json - no need to re-send the entire form HTML again
  if ($hub->param('submit')) {
    my $updated = $self->update_configuration;

    $r->content_type('text/plain');
    $r->print(to_json($updated ? {'updated' => 1} : {}));

  } else {

    # id reset request, reset before showing the configs form
    $self->update_configuration if $hub->param('reset');

    # render the form
    $self->SUPER::init(@_);
  }
}

sub view_config {
  ## Get the required view config according to the url 'action' parameters
  my $hub         = shift->hub;
  my $view_config = $hub->get_viewconfig($hub->action);

  throw WebException('ViewConfig missing') unless $view_config;

  return $view_config;
}

sub page_type {
  ## @override
  return 'Configurator';
}

sub _create_objects {
  ## @override
}

sub update_configuration {
  ## Handles the request to make changes to the configs (when the config modal form is submitted)
  my $self        = shift;
  my $hub         = $self->hub;
  my $view_config = $self->view_config;
  my $updated;

  my $params = { map { my $val = $hub->param($_); ($_ => $val) } $hub->param }; # update_from_input doesn't expect multiple values for a single param

  $params->{$_} = from_json($params->{$_} || '{}') for qw(image_config view_config);

  if ($view_config->update_from_input($params)) {
    $hub->store_records_if_needed;
    $updated = 1;
  }

  return $updated;
}

sub json_apply_config {
  ## Applies a selected configuration as current configuration
  my $self        = shift;
  my $hub         = $self->hub;
  my $view_config = $self->view_config;
  my $config_name = $hub->param('apply');
  my $updated     = 0;

  if ($config_name eq 'default') { # reset configs in this case

    $view_config->reset_user_settings;
    $view_config->save_user_settings;

    if (my $image_config = $view_config->image_config) {
      $image_config->reset_user_settings;
      $image_config->save_user_settings;
    }

    $updated = 1;

  } else {
    my ($config)  = map $_->get_records_data({'type' => 'saved_config', 'view_config_code' => $view_config->code, 'code' => $config_name}), grep $_, $hub->session, $hub->user;
    $updated      = $config && $view_config->copy_from_existing($config) ? 1 : 0;
  }

  $hub->store_records_if_needed if $updated;

  return { 'updated' => $updated };
}

sub json_list_configs {
  ## Gets a list of all the saved configurations for the current user/session for the current viewconfig
  my $self        = shift;
  my $hub         = $self->hub;
  my $view_config = $self->view_config;
  my $settings    = $view_config->get_user_settings;
  my $current     = keys %$settings ? $settings->{'saved'} || 'current' : 'default';

  return {
    'configs' => [
      map {name => $_->{'name'}, value => $_->{'code'}},
      map $_->get_records_data({'type' => 'saved_config', 'view_config_code' => $view_config->code}),
      grep $_, $hub->session, $hub->user
    ],
    'selected' => $current
  };
}

sub json_save_config {
  my $self        = shift;
  my $hub         = $self->hub;
  my $view_config = $self->view_config;
  my $config      = from_json($hub->param('config') || '{}');

  ## TODO
}

1;
