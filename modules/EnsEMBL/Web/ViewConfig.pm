=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ViewConfig;

### Abstract base class for all ViewConfigs

use strict;
use warnings;

use JSON qw(from_json to_json);

use EnsEMBL::Web::Attributes;
use EnsEMBL::Web::Form::ViewConfigForm;
use EnsEMBL::Web::Form::ViewConfigMatrix;
use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_use);
use EnsEMBL::Web::Utils::EqualityComparator qw(is_same);
use EnsEMBL::Web::Utils::RandomString qw(random_string);

use parent qw(EnsEMBL::Web::Config);

sub form_fields       :Abstract;  ## @return Hashref with keys as field ids and value as hashref as excepted by Form->add_field method
sub field_order       :Abstract;  ## @return List of field ids in same order as should be displayed in the form

sub image_config_type :AccessorMutator;
sub title             :AccessorMutator;
sub component         :Accessor;

sub _new {
  ## Abstract method implementation
  ## @param EnsEMBL::Web::Hub
  ## @param (String) Type
  ## @param (String) Component name
  my ($class, $hub, $type, $component) = @_;

  my $self = $class->SUPER::_new($hub, $hub->species, $type);

  $self->{'component'}    = $component;
  $self->{'code'}         = "${type}::$component";
  $self->{'options'}      = {};
  $self->{'labels'}       = {};
  $self->{'value_labels'} = {};

  return $self;
}

sub storable {
  ## Abstract method implementation
  return 1;
}

sub config_type {
  ## Abstract method implementation
  return 'view_config';
}

sub get_cacheable_object {
  ## Abstract method implementation
  my $self = shift;
  return { map { exists $self->{$_} ? ($_ => $self->{$_}) : () } qw(image_config_type title code options form) };
}

sub init_non_cacheable {
  ## Abstract method implementation
  ## Many child class won't have anything that can't be cached
}

sub apply_user_settings {
  ## Abstract method implementation
  ## Nothing specific needs to be done
}

sub reset_user_settings {
  ## Abstract method implementation
  my $self          = shift;
  my $user_settings = $self->get_user_settings;

  my @altered;

  for (keys %$user_settings) {
    push @altered, $_ if exists $self->{'options'}{$_};
    delete $user_settings->{$_};
  }

  return @altered;
}

sub image_config {
  ## Gets the linked image config object
  ## @return Instance of ImageConfig subclass
  my $self = shift;

  unless (exists $self->{'_image_config'}) {
    $self->{'_image_config'} = $self->image_config_type ? $self->hub->get_imageconfig($self->image_config_type) : undef;
  }

  return $self->{'_image_config'};
}

sub options {
  ## Gets a list of all the options set for the view config
  ## @return List of options (Strings)
  return keys %{$_[0]->{'options'}};
}

sub set_default_options {
  ## Sets default values for configs options as provided
  ## @param Hasreh with keys as { config_param_1 => $default_value, config_param_2 => [ $label, $default_value ], ... }
  my ($self, $defaults) = @_;

  for (keys %$defaults) {
    if (ref $defaults->{$_}) {
      ($self->{'labels'}{$_}, $self->{'options'}{$_}) = @{$defaults->{$_}};
    } else {
      $self->{'options'}{$_} = $defaults->{$_};
    }
  }
}

sub set_user_setting {
  ## Sets an option to the given value (Value set by the user)
  ## TODO - $force?
  my ($self, $key, $value, $force) = @_;

  use Carp; Carp::cluck('$force used') if $force; # To find where's $force being used

  my $user_settings = $self->get_user_settings;

  if (($force || exists $self->{'options'}{$key}) && (!exists $user_settings->{$key} || !is_same($user_settings->{$key}, $value))) {
    if (is_same($self->{'options'}{$key}, $value)) {
      delete $user_settings->{$key};
    } else {
      $user_settings->{$key} = $value;
    }
    return 1;
  }
  return 0;
}

sub get {
  ## Gets value of an option giving precedence to user set value over default values
  ## @return Value for the option (possibly a list in case of multiple values)
  my ($self, $key) = @_;

  use Carp; Carp::cluck unless defined $key;

  return unless exists $self->{'options'}{$key};

  my $user_settings = $self->get_user_settings;
  my $value         = exists $user_settings->{$key} ? $user_settings->{$key} : $self->{'options'}{$key};

  return $value && ref $value ? @$value : $value;
}

sub extra_tabs {
  ## Used to add tabs for related configuration.
  ## @return List of arrayrefs ([ caption, url ] ... )
}

sub field_values {
  ## Gets the values as set by user (or default if not changed by user) for each form fields
  ## @return Hashref of keys as form field name, values as values of each field
  my $self = shift;

  return $self->{'_field_values'} ||= { map { $_ => $self->get($_) // '' } $self->field_order };
}

sub config_url_params {
  ## Abstract method implementation
  my $self          = shift;
  my $image_config  = $self->image_config;

  return qw(config share_config), $image_config ? $image_config->config_url_params : ();
}

sub update_from_url {
  ## Abstract method implementation
  my ($self, $params) = @_;
  my $hub           = $self->hub;
  my $input         = $hub->input;
  my $species       = $hub->species;
  my $config        = $input->param('config');
  my $image_config  = $self->image_config;

  # if config param is present, apply all configs as required
  if (my $config_str = $params->{'config'}) {
    foreach my $config (split /,/, $config_str) {
      my ($config_key, $config_val) = split /=/, $config, 2;

      if ($config_key eq 'image_width') {
        $hub->image_width($config_val);
        $self->altered('Image Width');
      }

      $self->altered(1) if $self->set_user_setting($config_key, $config_val);
    }

    if ($self->is_altered) {
      $hub->session->set_record_data({
        'type'      => 'message',
        'function'  => '_info',
        'code'      => 'configuration',
        'message'   => 'Your configuration has changed for this page',
      });
    }
  }

  # if shared config is present in the url
  if (my $shared_config_code = $params->{'share_config'}) {

    ($shared_config_code) = grep $_, reverse split "/", $shared_config_code; # remove name

    my $shared_config = $hub->get_saved_config($shared_config_code);

    if ($shared_config && $shared_config->{'view_config_code'} eq $self->code) {

      # check if share config belongs to the logged in user itself
      my ($existing_config) = $hub->user->get_records_data({'type' => 'saved_config', 'code' => $shared_config_code});

      # check if a copy of config already exists
      if (!$existing_config) {
        for (grep $_, $hub->session, $hub->user) {
          ($existing_config) = $_->get_records_data({'type' => 'saved_config', 'copy' => $shared_config_code}) unless $existing_config;
          last if $existing_config;
        }
      }

      # create and save a new config if it doesn't exist already
      if (!$existing_config) {
        $shared_config->{'type'} = 'saved_config';
        $shared_config->{'code'} = random_string(32);
        $shared_config->{'name'} = "$shared_config->{'name'} (copy)";
        $shared_config->{'copy'} = $shared_config_code;

        ($hub->user || $hub->session)->set_record_data({%{$shared_config}}); # set_record_data removes code and type key, so passing a copy of the hash here
      }

      return $self->copy_from_existing($existing_config || $shared_config);
    }
  }

  # now apply config changes to linked image config
  $self->altered('image_config') if $image_config && $image_config->update_from_url($params);

  $self->save_user_settings if $self->is_altered; # update the record table

  return $self->is_altered;
}

sub update_from_input {
  ## Abstract method implementation
  my ($self, $params) = @_;

  # if user is resetting the configs
  if (my $reset = $params->{'reset'}) {
    $self->altered($self->reset_user_settings($reset));
  }


  if ($params->{alignment_selector}) {
    $self->receive_alignments_selector_settings(from_json $params->{alignment_selector});
    $self->altered(1);
  }

  my $settings = $params->{$self->config_type};
  foreach my $key (grep exists $self->{'options'}{$_}, keys %$settings) {

    my @values = ref $settings->{$key} eq 'ARRAY' ? @{$settings->{$key}} : ($settings->{$key});
    $self->altered($key) if $self->set_user_setting($key, @values > 1 ? \@values : $values[0]);
  }

  # now apply config changes to linked image config
  my $image_config = $self->image_config;
  $self->altered('image_config') if $image_config && $image_config->update_from_input($params);

  $self->save_user_settings if $self->is_altered; # update the record table

  return $self->is_altered;
}

sub copy_from_existing {
  ## @override
  ## Update only if the code is matching, and update image config too
  my ($self, $existing_record_data) = @_;

  if ($self->code eq $existing_record_data->{'view_config_code'}) {

    # update image config too
    my $image_config  = $self->image_config;
    $image_config->copy_from_existing($existing_record_data) if $image_config;

    return $self->SUPER::copy_from_existing($existing_record_data);
  }

  return 0;
}

sub init_form {
  ## Generic form-building method based on fields provided in form_field and field_order methods
  ## @return ViewConfigForm object
  my $self    = shift;
  my $form    = $self->form;
  my $fields  = $self->form_fields || {};

  $form->add_form_element($_) for map $fields->{$_} || (), $self->field_order;

  return $form;
}

sub init_form_non_cacheable {
  ## @return Form after making non-cacheable changes
  return shift->form;
}

######## -----------

sub form {
  my $self = shift;

  if (!$self->{'form'}) {
    my $view = 'EnsEMBL::Web::Form::ViewConfigForm';
    my $matrix = $self->hub->param('matrix');
    if ($matrix) {
      if ($matrix eq '1') { ## old-style matrix
        $view = 'EnsEMBL::Web::Form::ViewConfigMatrix';
      }
      else { ## new matrix interface
        $view = 'EnsEMBL::Web::Form::ViewConfig'.$matrix;
        if (!dynamic_use($view, 1)) {
          $view = 'EnsEMBL::Web::Form::ViewConfigMatrix';
        }
      }
    }
    $self->{'form'} = $view->new($self, sprintf('%s_%s_configuration', lc $self->type, lc $self->component), $self->hub->url('Config', undef, 1)->[0]);
  }

  return $self->{'form'};
}

sub add_fieldset {
  my ($self, $legend, $class, $no_tree) = @_;

  return $self->form->add_fieldset($legend, $class, $no_tree);
}

sub get_fieldset {
  my ($self, $i) = @_;

  return $self->form->get_fieldset($i);
}

sub add_form_element {
  my ($self, $element) = @_;

  return $self->form->add_form_element($element);
}

sub build_form {
  my ($self, $object, $image_config) = @_;

  return $self->form->build($object, $image_config);
}

sub set_label { $_[0]{'labels'}{$_[1]} = $_[2]; }
sub get_label { $_[0]{'labels'}{$_[1]}; }

sub set_value_label { $_[0]{'value_labels'}{$_[1]} = $_[2]; }
sub get_value_label { $_[0]{'value_labels'}{$_[1]}; }





sub add_image_config :Deprecated('Use method image_config_type') {
  my ($self, $image_config) = @_;
  $self->image_config_type($image_config);
}

sub set :Deprecated('Use set_user_setting') {
  return shift->set_user_setting(@_);
}

sub get_alignments_selector_settings {
  my $self   = shift;
  my $code   = 'alignments_selector';
  my $record = $self->hub->session->record({'type' => $self->config_type, 'code' => $code});
  my $settings = {};

  if ($record->count) {
    $settings = $record->data->raw;
    $settings->{'code'} = $code;
  }

  return $settings;
}

sub receive_alignments_selector_settings {
  my $self   = shift;
  my $params = shift;
  $params->{code} ||= 'alignments_selector';
  $params->{type} ||= $self->config_type;
  $self->hub->session->set_record_data($params);
}

1;
