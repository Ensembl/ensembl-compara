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

package EnsEMBL::Web::Session;

### NAME: EnsEMBL::Web::Session
### Object to maintain state during a browser session

### STATUS: Stable

### DESCRIPTION:
### New Session object - passed around inside the data object to handle storage of
### ViewConfigs/ImageConfigs in the web_user_db
###
### How it is used...
###
### The session object is attached to {{EnsEMBL::Web::Hub}} objects and is
### accessed via the {{EnsEMBL::Web::Hub::session}} method. You usually won't need
### to do this explicitly - because it is done implicitly by methods such as:
###
### {{EnsEMBL::Web::Hub::get_imageconfig}},
### {{EnsEMBL::Web::Hub::get_viewconfig}} which create either
### {{EnsEMBL::Web::ViewConfig}} or {{EnsEMBL::Web::ImageConfig}} objects.
###
### These commands in turn access the database if we already have a session (whose is
### accessible by {{session_id}}).
###
### At the end of the configuration section of the webpage if any data needs to be
### saved to the session this is done so (and if required a session cookie set and
### stored in the users browser. (See {{EnsEMBL::Web::Controller}} to see where this is done.
###

use strict;

use Digest::MD5    qw(md5_hex);
use HTML::Entities qw(encode_entities);
use URI::Escape    qw(uri_unescape);

use EnsEMBL::Web::Tools::Misc qw(style_by_filesize);
use EnsEMBL::Web::Data::Session;

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $hub, $cookie, $args) = @_;  
  $args ||= {};
  
  my $self = {
    hub                => $hub,
    cookie             => $cookie,
    session_id         => $cookie ? $cookie->value : undef,
    species            => $hub->species,
    path               => [ 'EnsEMBL::Web', reverse @{$args->{'path'} || []} ],
    view_configs       => {},
    data               => {},
    image_configs      => {},
  };

  bless $self, $class;  
  return $self;
}

sub hub  { return $_[0]{'hub'};  }
sub path { return $_[0]{'path'}; }
sub site { return '';            }

sub session_id    :lvalue { $_[0]{'session_id'};    }
sub cookie        :lvalue { $_[0]{'cookie'};        }
sub view_configs  :lvalue { $_[0]{'view_configs'};  }
sub image_configs :lvalue { $_[0]{'image_configs'}; }

sub create_session_id {
  ### Gets session ID if the session ID doesn't exist
  ### a new one is grabbed and added to the users cookies
  
  my $self = shift;
  
  if (!$self->session_id) {
    my $session_id = EnsEMBL::Web::Data::Session->create_session_id;
    $self->cookie->bake($session_id);
    $self->session_id = $session_id;
  }
  
  return $self->session_id;
}

sub store {
  ### Write to the database if configs have been altered
  
  my $self       = shift;
  my $session_id = $self->create_session_id;
  my $hub        = $self->hub;
  my $adaptor    = $hub->config_adaptor;
  my $user       = $hub->user;
  my %params     = ( record_type => $user ? 'user' : 'session', record_type_id => $user ? $user->user_id : $session_id, active => 'y' );
  my (@data, %links);
  
  foreach my $type (qw(view_config image_config)) {
    foreach my $config (values %{$self->{"${type}s"}}) {
      ## Only store if config has changed
      my $altered = $type eq 'view_config' ? $config->altered : $config->is_altered;
      if ($config->storable && $altered) {
        push @data, {
          code => $config->code,
          type => $type,
          data => $config->get_user_settings,
        };
        
        if ($type eq 'view_config' && $config->image_config) {
          $links{$config->code}         = [ 'image_config', $config->image_config ];
          $links{$config->image_config} = [ 'view_config',  $config->code ];
        }
      }
    }
  }
  
  $adaptor->link_configs(map { id => $adaptor->set_config(%params, %$_), code => $_->{'code'}, link => $links{$_->{'code'}} }, @data);
  
}

sub apply_to_view_config {
  my ($self, $view_config, $cache_code) = @_;
  $self->apply_to_config($view_config, 'view_config', $view_config->code, $cache_code);
}

sub apply_to_image_config {
  my ($self, $image_config, $cache_code) = @_;
  $self->apply_to_config($image_config, 'image_config', $image_config->{'type'}, $cache_code);
}

sub apply_to_config {
  ### Adds session data to a view or image config

  my ($self, $config, $type, $code, $cache_code) = @_;
  my $session_id = $self->session_id;
  
  if ($session_id && $config->storable) {
    my $config_data = $self->hub->config_adaptor->get_config($type, $code);
    $config->set_user_settings($config_data) if $config_data;
  }
  
  $self->{"${type}s"}->{$cache_code || $code} = $config;
}

sub get_cached_data {
  ### Retrieve the data from cache
  
  my $self = shift;
  my %args = ( type => 'tmp', @_ );

  if ($args{'code'}) {
    ## Code is specified
    return $self->{'data'}{$args{'type'}}{$args{'code'}} if $self->{'data'}{$args{'type'}}{$args{'code'}};
  } elsif ($self->{'data'}{$args{'type'}}) {
    ## Code is not specified // wantarray or not?
    my ($code) = keys %{$self->{'data'}{$args{'type'}}};
    return wantarray ? values %{$self->{'data'}{$args{'type'}}} : $self->{'data'}{$args{'type'}}{$code};
  }
}

sub get_data {
  ### Retrieve the data
  
  my $self       = shift;
  my $session_id = $self->session_id;
  
  return unless $session_id;
  
  my %args = ( type => 'upload', @_ );
  
  EnsEMBL::Web::Data::Session->propagate_cache_tags(type => $args{'type'});
  
  return $self->get_cached_data(%args) if $self->get_cached_data(%args);
  
  my @entries = EnsEMBL::Web::Data::Session->get_config(session_id => $session_id, %args);
  
  $self->{'data'}{$args{'type'}} ||= {};
  $self->{'data'}{$args{'type'}}{$_->code} = { type => $args{'type'}, code => $_->code, %{$_->data||{}} } for @entries;

  return $self->get_cached_data(%args);
}

sub set_data {
  my $self = shift; 
  my %args = ( type => 'upload', @_ );
  my ($type, $code) = ($args{'type'}, $args{'code'});
  
  return unless $type && $code;

  my $data = $self->get_data(type => $type, code => $code) || {};
  
  $self->{'data'}{$type}{$code} = { %$data, %args };
  
  $self->save_data(type => $type, code => $code);
}

sub purge_data {
  my $self = shift; 
  my %args = ( type => 'upload', @_ );
  
  if ($args{'code'}) {
    delete $self->{'data'}{$args{'type'}}{$args{'code'}};
  } else {
    $self->{'data'}{$args{'type'}} = {};
  }
  
  $self->save_data(%args);
}

sub add_data {
  ### For multiple objects, such as upload or urls
  
  my $self = shift; 
  my %args = ( type => 'upload', @_ );
  
  ## Unique code
  $args{'code'} ||= time;
  $self->set_data(%args);

  my $data = $self->get_data(type => $args{'type'}, code => $args{'code'});
  
  # Delete the cache, so that calling get_data(type => [TYPE]) afterwards will return all data, not just this one record
  delete $self->{'data'}{$args{'type'}};
  
  return $data;
}

sub save_data {
  ### Save all data back to the database
  
  my $self       = shift;
  my %args       = ( type => 'upload', @_ );
  my $session_id = $self->create_session_id;
  
  EnsEMBL::Web::Data::Session->reset_config(session_id => $session_id, %args);
  
  foreach my $data ($self->get_data(%args)) {
    next unless $data && %$data;
    
    my $code = $data->{'code'};
    
    # Don't put type and code into the data column in the database, since they're already in the type and code columns.
    # Make a new version of the data hash so that type and code don't get deleted from the cached data structure.
    $data = {%$data};
    delete $data->{$_} for qw(type code);
    
    EnsEMBL::Web::Data::Session->set_config(
      session_id => $session_id,
      type       => $args{'type'},
      code       => $code,
      data       => $data,
    );    
  }
}

sub receive_shared_data {
  my ($self, @share_refs) = @_; 
  my (%success, %failure, @track_data);
  
  foreach my $share_ref (@share_refs) {
    my $record;
    
    if ($share_ref =~ s/^conf(set)?-//) {
      # Configuration
      my $hub        = $self->hub;
      my $adaptor    = $hub->config_adaptor;
      my $is_set     = $1;
      my $func       = $is_set ? 'share_set' : 'share_record';
      my $record_ids = $adaptor->$func(split '-', $share_ref) || [];
         $record_ids = [ $record_ids ] unless ref $record_ids eq 'ARRAY';
      
      
      if (scalar @$record_ids) {
        my $configs = $adaptor->all_configs;
        
        if ($is_set) {
          my $set = $adaptor->all_sets->{$record_ids->[0]};
          push @{$success{'sets'}}, $set->{'name'};
          $record_ids = [ keys %{$set->{'records'}} ]; # Get record ids from the set if it's a set
        }
        
        push @{$success{'configs'}}, $configs->{$_}{'name'} for @$record_ids;
      } else {
        push @{$failure{$is_set ? 'configuration sets' : 'configurations'}}, $share_ref;
      }
      
      next;
    }
    
    if ($share_ref =~ /^(\d+)-(\w+)$/) {
      # User record
      $record = $self->receive_shared_user_data($1, $2) if $self->can('receive_shared_user_data');
    } else {
      # Session record
      $record = 
        EnsEMBL::Web::Data::Session->retrieve(session_id => [ split '_', $share_ref ]->[1], type => 'upload', code => $share_ref) ||
        EnsEMBL::Web::Data::Session->retrieve(session_id => [ split '_', $share_ref ]->[1], type => 'url',    code => $share_ref);
    }
    
    if ($record) {
      my $user = $self->hub->user;
      
      if (!($record->{'session_id'} == $self->session_id) && !($record->{'user_id'} && $user && $record->{'user_id'} == $user->id)) {
        $self->add_data(type => $record->{'type'}, code => $share_ref, %{$record->data});
        push @{$success{'tracks'}}, $record->data->{'name'};
      }
      
      push @track_data, $record->{'type'}, { code => $share_ref, %{$record->data} };
    } else {
      push @{$failure{'datasets'}}, $share_ref;
    }
  }
  
  if (scalar keys %failure) {
    $self->add_data(
      type     => 'message', 
      code     => 'no_data:' . (join ',', sort map @$_, values %failure), 
      message  => join('', map sprintf('<p>%s of the %s shared with you %s invalid</p>', scalar @{$failure{$_}}, $_, scalar @{$failure{$_}} == 1 ? 'is' : 'are'), sort keys %failure), 
      function => '_warning'
    );
  }
  
  if (scalar keys %success) {
    my $message;
    my $sets     = join '</li><li>', @{$success{'sets'}    || []};
    my $configs  = join '</li><li>', @{$success{'configs'} || []};
    my $tracks   = join '</li><li>', @{$success{'tracks'}  || []};
       $message .= sprintf "<p>The following configuration set%s been shared with you:<ul><li>$sets</li></ul></p>",                   scalar @{$success{'sets'}}    == 1 ? ' has' : 's have' if $sets;
       $message .= sprintf "<p>The following configuration%s been shared with you and are now in use:<ul><li>$configs</li></ul></p>", scalar @{$success{'configs'}} == 1 ? ' has' : 's have' if $configs;
       $message .= sprintf "<p>The following track%s shared data:<ul><li>$tracks</li></ul></p>",                                      scalar @{$success{'tracks'}}  == 1 ? ' is'  : 's are'  if $tracks;
    
    $self->add_data(
      type     => 'message', 
      code     => 'shared_data:' . (join ',', sort map @$_, values %success),
      message  => $message, 
      function => '_info'
    );
    
    $self->configure_user_data(@track_data);
  }
}

sub configure_user_data {
  my ($self, @track_data) = @_;
  my $hub     = $self->hub;
  my $species = $hub->species;
  
  foreach my $view_config (map { $hub->get_viewconfig(@$_) || () } @{$hub->components}) {
    my $ic_code = $view_config->image_config;
    
    next unless $ic_code;
    
    my $image_config = $hub->get_imageconfig($ic_code, $ic_code . time);
    my $vertical     = $image_config->isa('EnsEMBL::Web::ImageConfig::Vertical');
    
    while (@track_data) {
      my ($track_type, $track) = (shift @track_data, shift @track_data);
      next unless $track->{'species'} eq $species;
      
      my @nodes = grep $_, $track->{'analyses'} ? map $image_config->get_node($_), split(', ', $track->{'analyses'}) : $image_config->get_node("${track_type}_$track->{'code'}");
      
      if (scalar @nodes) {
        foreach (@nodes) {
          my $renderers = $_->get('renderers');
          my %valid     = @$renderers;
          if ($vertical) {
            $_->set_user('ftype', $track->{'ftype'});
            $_->set_user('display', $track->{'style'} || EnsEMBL::Web::Tools::Misc::style_by_filesize($track->{'filesize'}));
          } else {
            my $default_display = $_->get('default_display') || 'normal';
            $_->set_user('display', $valid{$default_display} ? $default_display : $renderers->[2]);
          }
          $image_config->altered($_->data->{'name'} || $_->data->{'coption'});
        }
        
        $image_config->{'code'} = $ic_code;
        $view_config->altered   = 1;
      }
    }
  }
  
  $self->store;
}

1;
