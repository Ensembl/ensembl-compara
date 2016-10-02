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

package EnsEMBL::Web::Config;

### Abstract parent class for all the image and view configs

use strict;
use warnings;
no warnings "uninitialized";

use Data::Dumper;
use Digest::MD5 qw(md5_hex);

use EnsEMBL::Web::Attributes;
use EnsEMBL::Web::Tree;

sub hub                   :Accessor;
sub type                  :Accessor;
sub species               :Accessor;
sub code                  :Accessor;
sub species_defs          :Accessor;

sub storable              :Abstract; ## Any changes in the config by the user are allowed to be saved in records?
sub config_type           :Abstract; ## @return image_config/view_config accordingly
sub init_cacheable        :Abstract; ## Initalises the portion of the object that stays the same for all users/browsers/url params and thus can be safely cached against the cache_key
sub init_non_cacheable    :Abstract; ## Initalises the portion of the object that should not be cached since it might contain settings that do not apply to all visitors
sub get_cacheable_object  :Abstract; ## @return Ref to a hash object that can be saved to the cache for subsequent requests
sub apply_user_settings   :Abstract; ## Applies changes to the config object as saved in user/session record
sub reset_user_settings   :Abstract; ## Removes changes from the config object and returns a list of changed configs (does not delete the saved record in the db)
sub config_url_params     :Abstract; ## Gets a list of url params that get passed to the config object to update user config (As needed by update_from_url method)
sub update_from_url       :Abstract; ## Updates user settings according to the parameters provided in the url and returns true value if config is modified
sub update_from_input     :Abstract; ## Updates user settings according to the POST/GET params and returns true value if config is modified

sub new {
  ## @constructor
  my $class = shift;
  my $self  = $class->_new(@_);

  $self->init;

  return $self;
}

sub _new {
  ## Actual constructor method to populate config object
  ## Override this method to add extra keys to the blessed object
  ## @param Hub object
  ## @param (String) Species name
  ## @param (String) Type
  my ($class, $hub, $species, $type) = @_;

  return bless {
    'hub'           => $hub,
    'species'       => $species,
    'species_defs'  => $hub->species_defs,
    'type'          => $type,
    '_altered'      => {}, # list of the configs that have been altered
  }, $class;
}

sub init {
  ## Initialises the image/view config object from cache (if possible), and then applies some non cacheable setting on top of that
  my $self = shift;

  # Try to initialise the config from cache and if it doesn't succeed, initalises the cacheable settings and save them in cache for next time
  if (!$self->_init_from_cache) {
    $self->init_cacheable;
    $self->_save_to_cache;
  }

  $self->init_non_cacheable;
  $self->apply_user_settings;
  $self->apply_user_cache_tags;
}

sub cache_key {
  ## Cache key for the object to save againt in memcahced
  return join '::', '', ref $_[0], $_[0]->species, $_[0]->code;
}

sub tree {
  ## Creates or returns existing tree for configs
  ## @return EnsEMBL::Web::Tree object
  my $self = shift;

  return $self->{'_tree'} ||= EnsEMBL::Web::Tree->new
}

sub _init_from_cache {
  ## @protected
  my $self      = shift;
  my $cache     = $self->hub->cache;
  my $cache_key = $self->cache_key;
  my $cached    = $cache && $cache_key ? $cache->get($cache_key) : undef;

  return unless $cached;

  $self->{$_} = $cached->{$_} for keys %$cached;
  return 1;
}

sub _save_to_cache {
  ## @protected
  my $self      = shift;
  my $cache     = $self->hub->cache;
  my $cache_key = $self->cache_key;
  my $object    = $self->get_cacheable_object;

  return unless $cache && $cache_key && $object;

  $cache->set($cache_key, $object, undef, $self->config_type, $self->species);
}

sub get_user_settings {
  ## Gets settings saved by the user from the session/user record
  ## Any changes made to the returned hashref will get saved to the db when save_user_settings method is called
  ## @return User settings as a hashref
  my $self = shift;

  return $self->{'_user_settings'} ||= $self->hub->session ? $self->hub->session->get_record_data({'type' => $self->config_type, 'code' => $self->code}) : {};
}

sub get_user_settings_to_save {
  ## @protected
  ## Makes any final changes to the user data before its saved to the db
  ## Override in a child class if needed
  return shift->get_user_settings(@_);
}

sub save_user_settings {
  ## Saves (or removes) user settings to the corresponding user/session record for this image/view config
  ## Does not take any arguments but any changes made to the hash returned by get_user_settings method will get saved
  my $self      = shift;
  my $hub       = $self->hub;
  my $settings  = $self->get_user_settings_to_save;

  $settings->{'type'} = $self->config_type;
  $settings->{'code'} = $self->code;

  $hub->session->set_record_data(_rm_empty_vals($settings));

  return 1;
}

sub get_shareable_settings {
  ## Gets the data that can be shared with another user
  ## @return Hashref
  my $self      = shift;
  my $record    = $self->hub->session->record({'type' => $self->config_type, 'code' => $self->code});
  my $settings  = {};

  if ($record->count) {
    $settings = $record->data->raw;
    $settings->{'code'} = $self->code;
  }

  return $settings;
}

sub receive_shared_settings {
  ## Receives data and sets it as user settings for the current image/view config
  my ($self, $settings) = @_;

  my $session = $self->hub->session;

  # in case config code is now changed since the share link was created
  return unless $settings->{'code'} eq $self->code;

  # delete any saved reference to data
  delete $self->{'_user_settings'};

  $settings->{'type'} = $self->config_type;

  $self->hub->session->set_record_data(_rm_empty_vals($settings));
}

sub altered {
  ## Maintains a list of configs that have been altered
  ## @params List of config (name) that has been altered (optional)
  ## @return Arrayref of all altered configs (including any configs altered in previous calls)
  my $self = shift;

  $self->{'_altered'}{$_} = 1 for grep $_, @_;

  return [ sort keys %{$self->{'_altered'}} ];
}

sub is_altered {
  ## Tells if any change has been applied to the config
  ## @return 0 or 1 accordingly
  return scalar keys %{$_[0]->{'_altered'}} ? 1 : 0;
}

sub apply_user_cache_tags {
  ## Applies extra tags to the current component (i.e. sets any tags if any changes made by the user can change the output of component)
  ## Note: Not to be confused with the cache key against which the current config is saved in the cache
  my $self        = shift;
  my $config_type = $self->config_type;
  my $settings    = $self->get_user_settings;

  if (keys %$settings) {
    $self->hub->controller->add_cache_tags({
      $config_type => sprintf('%s[%s]', uc $config_type, md5_hex(Data::Dumper->new([$self->get_user_settings])->Sortkeys(1)->Terse(1)->Indent(0)->Maxdepth(0)->Dump))
    });
  }
}

sub _rm_empty_vals {
  ## @private
  ## @function
  my $pointer = shift;
  my $ref     = ref($pointer // '') || '';
  if ($ref eq 'HASH') {
    $pointer = { map { my $val = _rm_empty_vals($pointer->{$_}); defined $val ? ($_ => $val) : () } keys %$pointer };
    return keys %$pointer ? $pointer : undef;
  } elsif ($ref eq 'ARRAY') {
    $pointer = [ map { _rm_empty_vals($_) // () } @$pointer ];
    return @$pointer ? $pointer : undef;
  }
  return ($pointer // '') eq '' ? undef : "$pointer";
}

1;
