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

use EnsEMBL::Web::Attributes;

sub hub                 :Accessor;
sub type                :Accessor;
sub species             :Accessor;
sub code                :Accessor;
sub species_defs        :Accessor;

sub storable            :Abstract; ## Any changes in the config by the user are allowed to be saved in records?
sub config_type         :Abstract; ## Should return image_config or view_config accordingly
sub init_cacheable      :Abstract; ## Initalises the portion of the object that stays the same for all users/browsers/url params and thus can be safely cached against the cache_key
sub init_non_cacheable  :Abstract; ## Initalises the portion of the object that should not be cached since it might contain settings that do not apply to all visitors
sub apply_user_settings :Abstract; ## Applies changes to the config as made/saved by the user in a user/session record

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
    '_altered'      => [],
    '_parameters'   => {}
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
  ## @private
  my $self      = shift;
  my $cache     = $self->hub->cache;
  my $cache_key = $self->cache_key;
  my $cached    = $cache && $cache_key ? $cache->get($cache_key) : undef;

  return unless $cached;

  $self->{$_} = $cached->{$_} for keys %$cached;
  return 1;
}

sub set_parameters {
  ## Sets multiple parameter values at once
  ## @param Hashref containing keys and values of the params
  my ($self, $params) = @_;
  $self->{'_parameters'}{$_} = $params->{$_} for keys %$params;
}

sub set_parameter {
  ## Sets a parameter value
  ## @param Parameter name
  ## @param Parameter value
  my ($self, $key, $value) = @_;
  $self->{'_parameters'}{$key} = $value;
}

sub get_parameter {
  ## Gets a parameter value
  ## @param Parameter name
  my ($self, $key) = @_;
  return $self->{'_parameters'}{$key};
}

sub _parameter {
  ## @private
  ## Gets (or sets non-zero value to) the given parameter
  ## @param Parameter name
  ## @param (Optional) Non-zero parameter value
  my ($self, $key, $value) = @_;
  $self->set_parameter($key, $value) if $value;
  return $self->get_parameter($key);
}

sub get_user_settings {
  ## Gets settings saved by the user from the session/user record
  ## @return User settings as a hashref
  my $self = shift;

  return $self->{'_user_settings'} ||= $self->hub->get_record_data({'type' => $self->config_type, 'code' => $self->code, 'flag' => 'y'}) || {};
}

sub save_user_settings {
  ## Saves the (possibly) modified user settings to the corresponding user/session record for this image/view config
  my $self      = shift;
  my $hub       = $self->hub;
  my $settings  = $self->get_user_settings;

  if (keys %$settings) {
    $settings->{'type'} = $self->config_type;
    $settings->{'code'} = $self->code;
    $settings->{'flag'} = 'y';

    $hub->set_record_data($settings);
  }
  return 1;
}

sub delete_user_settings {
  ## Deletes the currently saved user settings from the user/session record
  my $self      = shift;
  my $hub       = $self->hub;
  my $settings  = $self->get_user_settings;

  if ($settings->{'record_id'}) {
    $self->hub->delete_records({'record_id' => $settings->{'record_id'}});
  }

  $self->{'_user_settings'} = {};

  return 1;
}

sub altered {
  ## Maintains a list of configs that have been altered
  ## @param Config name that has been altered (optional)
  ## @return Arrayref of altered configs
  my ($self, $altered_config) = @_;

  push @{$self->{'_altered'}}, $altered_config if $altered_config;

  return $self->{'_altered'};
}

sub is_altered {
  ## Tells if any change has been applied to the config
  ## @return 0 or 1 accordingly
  return @{$_[0]->{'_altered'}} ? 1 : 0;
}

#TODO -------------- 

sub update_from_input {
  my $self  = shift;
  my $input = $self->hub->input;

  return $self->reset if $input->param('reset');

  my $diff   = $input->param('image_config');
  my $reload = 0;

  if ($diff) {
    my $track_reorder = 0;

    $diff = from_json($diff);
    $self->update_track_renderer($_, $diff->{$_}->{'renderer'}, undef, 1) for grep exists $diff->{$_}->{'renderer'}, keys %$diff;

    $reload        = $self->is_altered;
    $track_reorder = $self->update_track_order($diff) if $diff->{'track_order'};
    $reload      ||= $track_reorder;
    $self->update_favourite_tracks($diff);
  } else {
    my %favourites;

    foreach my $p ($input->param) {
      my $val = $input->param($p);

      if ($p eq 'track') {
        my $node = $self->get_node($val);
        $node->set_user_setting('userdepth', $input->param('depth')) if $node;
        $self->altered($val);
      }
      elsif ($val =~ /favourite_(on|off)/) {
        $favourites{$p} = { favourite => $1 eq 'on' ? 1 : 0 };
      }
      elsif ($p ne 'depth') {
        $self->update_track_renderer($p, $val);
      }
    }

    $reload = $self->is_altered;

    $self->update_favourite_tracks(\%favourites) if scalar keys %favourites;
  }

  return $reload;
}

sub update_from_url {
  ## Tracks added "manually" in the URL (e.g. via a link)

  my ($self, @values) = @_;
  my $hub     = $self->hub;
  my $session = $hub->session;
  my $species = $hub->species;

  foreach my $v (@values) {
    my $format = $hub->param('format');
    my ($url, $renderer, $attach);

    if ($v =~ /^url/) {
      $v =~ s/^url://;
      $attach = 1;
      ($url, $renderer) = split /=/, $v;
    }

    if ($attach || $hub->param('attach')) {
      ## Backwards compatibility with 'contigviewbottom=url:http...'-type parameters
      ## as well as new 'attach=http...' parameter
      my $p = uri_unescape($url);

      my $menu_name   = $hub->param('menu');
      my $all_formats = $hub->species_defs->multi_val('DATA_FORMAT_INFO');

      if (!$format) {
        my @path = split(/\./, $p);
        my $ext  = $path[-1] eq 'gz' ? $path[-2] : $path[-1];

        while (my ($name, $info) = each %$all_formats) {
          if ($ext =~ /^$name$/i) {
            $format = $name;
            last;
          }
        }
        if (!$format) {
          # Didn't match format name - now try checking format extensions
          while (my ($name, $info) = each %$all_formats) {
            if ($ext eq $info->{'ext'}) {
              $format = $name;
              last;
            }
          }
        }
      }

      my $style = $all_formats->{lc $format}{'display'} eq 'graph' ? 'wiggle' : $format;
      my $code  = join '_', md5_hex("$species:$p"), $session->session_id;
      my $n;

      if ($menu_name) {
        $n = $menu_name;
      } else {
        $n = $p =~ /\/([^\/]+)\/*$/ ? $1 : 'un-named';
      }

      # Don't add if the URL or menu are the same as an existing track
      if ($session->get_record_data({type => 'url', code => $code})) {
        $session->set_record_data({
            type     => 'message',
            function => '_warning',
            code     => "duplicate_url_track_$code",
            message  => "You have already attached the URL $p. No changes have been made for this data source.",
        });

        next;
      } elsif ($session->get_record_data({name => $n, type => 'url'})) {
        $session->set_record_data({
          type     => 'message',
          function => '_error',
          code     => "duplicate_url_track_$n",
          message  => qq{Sorry, the menu "$n" is already in use. Please change the value of "menu" in your URL and try again.},
        });

        next;
      }

      # We then have to create a node in the user_config
      my %ensembl_assemblies = %{$hub->species_defs->assembly_lookup};

      if (uc $format eq 'TRACKHUB') {
        my $info;
        ($n, $info) = $self->_add_trackhub($n, $p);
        if ($info->{'error'}) {
          my @errors = @{$info->{'error'}||[]};
          $session->set_record_data({
              type     => 'message',
              function => '_warning',
              code     => 'trackhub:' . md5_hex($p),
              message  => "There was a problem attaching trackhub $n: @errors",
          });
        }
        else {
          my $assemblies = $info->{'genomes'}
                        || {$hub->species => $hub->species_defs->get_config($hub->species, 'ASSEMBLY_VERSION')};

          foreach (keys %$assemblies) {
            my ($data_species, $assembly) = @{$ensembl_assemblies{$_}||[]};
            if ($assembly) {
              my $data = $session->set_record_data({
                type        => 'url',
                url         => $p,
                species     => $data_species,
                code        => join('_', md5_hex($n . $data_species . $assembly . $p), $session->session_id),
                name        => $n,
                format      => $format,
                style       => $style,
                assembly    => $assembly,
              });
            }
          }
        }
      } else {
        ## Either upload or attach the file, as appropriate
        my $command = EnsEMBL::Web::Command::UserData::AddFile->new({'hub' => $hub});
        ## Fake the params that are passed by the upload form
        $hub->param('text', $p);
        $hub->param('format', $format);
        $command->upload_or_attach($renderer);
        ## Discard URL param, as we don't need it once we've uploaded the file,
        ## and it only messes up the page URL later
        $hub->input->delete('url');
      }
      # We have to create a URL upload entry in the session
      my $message  = sprintf('Data has been attached to your display from the following URL: %s', encode_entities($p));
      $session->set_record_data({
        type     => 'message',
        function => '_info',
        code     => 'url_data:' . md5_hex($p),
        message  => $message,
      });
    } else {
      ($url, $renderer) = split /=/, $v;
      $renderer ||= 'normal';
      $self->update_track_renderer($url, $renderer, $hub->param('toggle_tracks'));
    }
  }

  if ($self->is_altered) {
    my $tracks = join(', ', @{$self->altered});
    $session->set_record_data({
      type     => 'message',
      function => '_info',
      code     => 'image_config',
      message  => "The link you followed has made changes to these tracks: $tracks.",
    });
  }
}



sub reset {
  my $self  = shift;
  my $reset = $self->hub->input->param('reset');
  my ($tracks, $order) = $reset eq 'all' ? (1, 1) : $reset eq 'track_order' ? (0, 1) : (1, 0);

  if ($tracks) {
    my $tree = $self->tree;

    foreach my $node ($tree, $tree->nodes) {
      my $user_data = $node->{'user_data'};

      foreach (keys %$user_data) {
        my $text = $user_data->{$_}{'name'} || $user_data->{$_}{'coption'};
        $self->altered($text) if $user_data->{$_}{'display'};
        delete $user_data->{$_}{'display'};
        delete $user_data->{$_} unless scalar keys %{$user_data->{$_}};
      }
    }
  }

  if ($order) {
    my $node    = $self->get_node('track_order');
    my $species = $self->species;

    if ($node->{'user_data'}{'track_order'}{$species}) {
      delete $node->{'user_data'}{'track_order'}{$species};
      delete $node->{'user_data'}{'track_order'} unless scalar keys %{$node->{'user_data'}{'track_order'}};

      $self->altered('Track order');
    }
  }
}

sub share {
  # Remove anything from user settings that is:
  #   Custom data that the user isn't sharing
  #   A track from a trackhub that the user isn't sharing
  #   Not for the species in the image
  # Reduced track order of explicitly ordered tracks if they are after custom tracks which aren't shared

  my ($self, %shared_custom_tracks) = @_;
  my $user_settings     = EnsEMBL::Web::Root->deepcopy($self->get_user_settings);
  my $species           = $self->species;
  my $user_data         = $self->get_node('user_data');
  my @unshared_trackhubs = grep $_->get('trackhub_menu') && !$shared_custom_tracks{$_->id}, @{$self->tree->child_nodes};
  my @user_tracks       = map { $_ ? $_->nodes : () } $user_data;
  my %user_track_ids    = map { $_->id => 1 } @user_tracks;
  my %trackhub_tracks    = map { $_->id => [ map $_->id, $_->nodes ] } @unshared_trackhubs;
  my %to_delete;

  foreach (keys %$user_settings) {
    next if $_ eq 'track_order';
    next if $shared_custom_tracks{$_};

    my $node = $self->get_node($_);

    $to_delete{$_} = 1 unless $node && $node->parent_node; # delete anything that isn't for this species
    $to_delete{$_} = 1 if $user_track_ids{$_};             # delete anything that isn't shared
  }

  foreach (@unshared_trackhubs) {
    $to_delete{$_} = 1 for grep $user_settings->{$_}, @{$trackhub_tracks{$_->id} || []};  # delete anything for tracks in trackhubs that aren't shared
  }

  # Reduce track orders if custom tracks aren't shared
  if (scalar keys %to_delete) {
    my %track_ids_to_delete = map {( $_ => 1, "$_.b" => 1, "$_.f" => 1 )} keys %to_delete, map { @{$trackhub_tracks{$_->id} || []} } @unshared_trackhubs;

    $user_settings->{'track_order'}{$species} = [ grep { !$track_ids_to_delete{$_->[0]} && !$track_ids_to_delete{$_->[1]} } @{$user_settings->{'track_order'}{$species}} ];
  }

  # remove track order for other species
  delete $user_settings->{'track_order'}{$_} for grep $_ ne $species, keys %{$user_settings->{'track_order'}};

  return $user_settings;
}

sub save_to_cache {
  my $self      = shift;
  my $cache     = $self->hub->cache;
  my $cache_key = $self->cache_key;

  if ($cache && $cache_key) {
    $self->_hide_user_data;

    my $defaults = {
      tree          => $self->{'tree'},
      _parameters   => $self->{'_parameters'},
      _extra_menus  => $self->{'_extra_menus'},
    };

    $cache->set($cache_key, $defaults, undef, 'IMAGE_CONFIG', $self->species);
    $self->_reveal_user_data;
  }
}

1;
