=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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
use EnsEMBL::Web::Utils::RandomString qw(random_string);

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

    if (defined $hub->param('updated')) {
      $updated = $hub->param('updated');
    }
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
  my $self          = shift;
  my $hub           = $self->hub;
  my $view_config   = $self->view_config;
  my $vc_settings   = $view_config->get_user_settings;
  my $image_config  = $view_config->image_config;
  my $ic_settings   = $image_config ? $image_config->get_user_settings : {};

  my @configs       = map {name => $_->{'name'}, value => $_->{'code'}},
                      map $_->get_records_data({'type' => 'saved_config', 'view_config_code' => $view_config->code}),
                      grep $_, $hub->session, $hub->user;

  my $current       = keys %$vc_settings ? $vc_settings->{'saved'} || 'current' : 'default';
     $current       = $ic_settings->{'saved'} && $ic_settings->{'saved'} eq $current && $current || 'current' if keys %$ic_settings;
     $current       = 'current' if $current ne 'current' && $current ne 'default' && !grep $_->{'value'} eq $current, @configs;

  return {
    'configs' => \@configs,
    'selected' => $current
  };
}

sub json_save_config {
  ## Saves currentl view_config and image_config as a saved_config
  my $self    = shift;
  my $hub     = $self->hub;
  my $session = $hub->session;
  my $updated = 0;

  try {
    my $config            = from_json($hub->param('config') || '{}');
    my $record_owner      = $hub->user || $session; # if user is logged in, save the configs against user id, otherwise against the session
    my %ignore_keys       = map { $_ => 1 } ('saved', @{$record_owner->record_column_names});
    my $view_config       = $self->view_config;
    my $image_config      = $view_config->image_config;
    my $saved_configs     = {
      'type'                => 'saved_config',
      'view_config_code'    => $view_config->code,
      'code'                => delete $config->{'configId'} || random_string(32),
      'name'                => delete $config->{'configName'} || 'Autosaved',
    };

    # update if any new changes have been made by the user before saving it (image config gets updated while updating the view configs)
    $view_config->update_from_input({'image_config' => delete $config->{'imageConfig'}, 'view_config' => delete $config->{'viewConfig'}});

    # save the required keys from image config and view config
    foreach my $config_type (qw(view_config image_config)) {
      my $conf      = $config_type eq 'view_config' ? $view_config : $image_config;
      my $settings  = $conf ? $conf->get_user_settings_to_save : undef;

      foreach my $key (grep !$ignore_keys{$_}, keys %{$settings || {}}) {
        $saved_configs->{$config_type}{$key} = $settings->{$key};
      }

      # add 'saved' key to data and delete any 'copy' key (since we have made a change, copy is not valid)
      if ($settings) {
        $settings->{'saved_from'} = $saved_configs->{'code'};
        delete $settings->{'copy'};
        delete $settings->{'record_id'};
        $conf->save_user_settings;
      }
    }

    $record_owner->set_record_data($saved_configs);

    $hub->store_records_if_needed;

    $updated = 1;

  } catch {
    warn $_;
  };

  return {'updated' => $updated};
}

sub json_save_desc {
  ## Updates description of a saved_config record
  my $self  = shift;
  my $hub   = $self->hub;
  my $code  = $hub->param('code');
  my $desc  = $hub->param('desc');

  my ($config, $record_owner) = $self->_get_saved_config($code);
  my $updated = 0;

  if ($config) {
    $config->{'desc'} = $desc;
    $record_owner->set_record_data($config);
    $hub->store_records_if_needed;
    $updated = 1;
  }

  return {'updated' => $updated};
}

sub json_move_config {
  ## Moves a saved_config record from session to user
  my $self    = shift;
  my $hub     = $self->hub;
  my $code    = $hub->param('code');
  my $user    = $hub->user;
  my $updated = 0;

  my ($config, $record_owner) = $self->_get_saved_config($code);

  if ($config && $user && $record_owner->record_type eq 'session') {
    delete $config->{$_} for qw(record_id record_type created_at created_by modified_at modified_by);
    $user->set_record_data($config);
    $record_owner->set_record_data({'type' => 'saved_config', 'code' => $code});
    $hub->store_records_if_needed;
    $updated = 1;
  }

  return {'updated' => $updated};
}

sub json_delete_config {
  ## Moves a saved_config record from session to user
  my $self    = shift;
  my $hub     = $self->hub;
  my $code    = $hub->param('code');
  my $updated = 0;

  my ($config, $record_owner) = $self->_get_saved_config($code);

  if ($config) {
    $record_owner->set_record_data({'type' => 'saved_config', 'code' => $code});
    $hub->store_records_if_needed;
    $updated = 1;
  }

  return {'updated' => $updated};
}

sub _get_saved_config {
  my ($self, $code) = @_;

  my $hub = $self->hub;

  my ($config, $record_owner);

  for (grep $_, $hub->session, $hub->user) {
    $config       = $_->get_record_data({'type' => 'saved_config', 'code' => $code});
    $record_owner = $_ and last if keys %$config;
  }

  return $record_owner ? ($config, $record_owner) : ();
}

1;
