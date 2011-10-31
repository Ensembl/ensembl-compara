# $Id$

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

use Bio::EnsEMBL::ExternalData::DAS::SourceParser;

use EnsEMBL::Web::DASConfig;
use EnsEMBL::Web::Data::Session;
use EnsEMBL::Web::Tools::Encryption qw(checksum);

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $hub, $cookie, $args) = @_;  
  $args ||= {};
  
  my $self = {
    hub                => $hub,
    cookie             => $cookie,
    session_id         => $cookie ? $cookie->get_value : undef,
    species            => $hub->species,
    das_parser         => $args->{'das_parser'},
    das_sources        => $args->{'das_sources'},
    path               => [ 'EnsEMBL::Web', reverse @{$args->{'path'} || []} ],
    das_image_defaults => [ 'display', 'off' ],
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
    $self->cookie->create($self->hub->apache_handle, $session_id);
    $self->session_id = $session_id;
  }
  
  return $self->session_id;
}

sub store {
  ### Write to the database if configs have been altered
  
  my $self       = shift;
  my $data       = [];
  my $session_id = $self->create_session_id;
  
  foreach my $type (qw(view_config image_config)) {
    foreach my $config (values %{$self->{"${type}s"}}) {
      ## Only store if config has changed
      if ($config->storable && $config->altered) {
        push @$data, {
          code => $config->code,
          type => $type,
          data => $config->get_user_settings
        };
      }
    }
  }
  
  foreach (@$data) {
    if (scalar keys %{$_->{'data'}}) {
      EnsEMBL::Web::Data::Session->set_config(
        session_id => $session_id,
        type       => $_->{'type'},
        code       => $_->{'code'},
        data       => $_->{'data'},
      );
    } else {
      $self->purge_data(type => $_->{'type'}, code => $_->{'code'});
    }
  }
  
  $self->save_das;
}

sub apply_to_view_config {
  my ($self, $view_config, $type, $cache_code, $config_code) = @_;
  $self->apply_to_config('view_config', $view_config, $type, $cache_code, $config_code);
}

sub apply_to_image_config {
  my ($self, $image_config, $type, $cache_code) = @_;
  $self->apply_to_config('image_config', $image_config, $type, $cache_code, $type); # $cache_code is optional - used when an image has multiple configs. Defaults to $type.
}

sub apply_to_config {
  ### Adds session data to a view or image config

  my ($self, $config_type, $config, $type, $cache_code, $config_code) = @_;
  my $session_id = $self->session_id;
  
  EnsEMBL::Web::Data::Session->propagate_cache_tags(
    session_id => $session_id,
    type       => $type,
    code       => $cache_code
  );
  
  if ($session_id && $config->storable) {
    # Let us see if there is an entry in the database and load it into the script config and store any other data which comes back
    my $session_data = EnsEMBL::Web::Data::Session->get_config(
      session_id => $session_id,
      type       => $config_type,
      code       => $config_code
    );
    
    $config->set_user_settings($session_data->data) if $session_data && $session_data->data;
  }
  
  $self->{$config_type . 's'}->{$cache_code} = $config;
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
  
  EnsEMBL::Web::Data::Session->propagate_cache_tags(
    session_id => $session_id,
    type       => $args{'type'},
    code       => $args{'code'},
  );
  
  return $self->get_cached_data(%args) if $self->get_cached_data(%args);
  
  my @entries = EnsEMBL::Web::Data::Session->get_config(session_id => $session_id, %args);
  
  $self->{'data'}{$args{'type'}} ||= {};
  $self->{'data'}{$args{'type'}}{$_->code} = { type => $args{'type'}, code => $_->code, %{$_->data} } for @entries;

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
  my (@success, @failure);
  
  foreach my $share_ref (@share_refs) {
    my $record;
    
    if ($share_ref =~ /^(\d+)-(\w+)$/) {
      # User record:
      my $id       = $1;
      my $checksum = $2;
      
      die 'Sharing violation' unless checksum($id) ne $checksum;
      
      $record = new EnsEMBL::Web::Data::Record::Upload::User($id) || new EnsEMBL::Web::Data::Record::URL::User($id);
    } else {
      # Session record:
      $record = 
        EnsEMBL::Web::Data::Session->retrieve(session_id => [ split '_', $share_ref ]->[1], type => 'upload', code => $share_ref) ||
        EnsEMBL::Web::Data::Session->retrieve(session_id => [ split '_', $share_ref ]->[1], type => 'url',    code => $share_ref);
    }
    
    if ($record) {
      my $user = $self->hub->user;
      
      if (!($record->{'session_id'} == $self->session_id) && !($record->{'user_id'} && $user && $record->{'user_id'} == $user->id)) {
        $self->add_data(type => $record->{'type'}, code => $share_ref, %{$record->data});
        push @success, $record->data->{'name'};
      }
    } else {
      push @failure, $share_ref;
    }
  }
  
  if (@failure) {
    my $n   = scalar @failure;
    my $msg = "The data has been removed from $n of the shared sets that you are looking for.";
    
    $self->add_data(
      type     => 'message', 
      code     => 'no_data:' . (join ',', sort @failure), 
      message  => $msg, 
      function => '_warning'
    );
  }
  
  if (@success) {
    my $tracks = join '</li><li>', @success;
    $tracks    = "<ul><li>$tracks</li></ul>";
    
    $self->add_data(
      type     => 'message', 
      code     => 'shared_data:' . (join ',', map $_[0], @share_refs),
      message  => "The following added tracks are shared data:$tracks", 
      function => '_info'
    );
  }
}

sub das_parser {
  my $self         = shift;
  my $species_defs = $self->hub->species_defs;
  
  return $self->{'das_parser'} ||= new Bio::EnsEMBL::ExternalData::DAS::SourceParser(
    -timeout  => $species_defs->ENSEMBL_DAS_TIMEOUT,
    -proxy    => $species_defs->ENSEMBL_WWW_PROXY,
    -noproxy  => $species_defs->ENSEMBL_NO_PROXY
  );
}

# This function will make sure that a das source is attached with a unique name
# So in case when you try to attach MySource it will return undef if exactly same
# source is already attached (i.e the same url, dsn and coords).
# If it's only the name that is the same then the function will provide a unique
# name for the new source , e.g name_1
sub get_unique_das_source_name {
  my ($self, $source) = @_;
  my @sources = $self->hub->get_all_das;
  
  for (my $i = 0; 1; $i++) {
    my $test_name = $i ? $source->logic_name . "_$i" : $source->logic_name;
    my $test_url  = $i ? $source->full_url   . "_$i" : $source->full_url;
    
    my $test_source = $sources[0]->{$test_name} || $sources[1]->{$test_url};
    
    if ($test_source) {
      return if $source->equals($test_source);
      next;
    }
    
    return $test_name;
  }
}

# This method gets all configured DAS sources for the current session, i.e. all
# those either added or modified externally.
# Returns a hashref, indexed by logic_name.
sub get_all_das {
  my $self       = shift;
  my $session_id = $self->session_id;
  
  return ({}, {}) unless $session_id;
  
  my %args    = ( session_id => $session_id, type => 'das' );
  my $species = shift || $self->hub->species;
     $species = '' if $species eq 'common';
  
  EnsEMBL::Web::Data::Session->propagate_cache_tags(%args);
  
  # If the cache hasn't been initialised, do it
  if (!$self->{'das_sources'}) {
    $self->{'das_sources'} = {};
    
    # Retrieve all DAS configurations from the database
    my @configs = EnsEMBL::Web::Data::Session->get_config(%args);
    
    foreach (map $_->data || (), @configs) {
      my $das = EnsEMBL::Web::DASConfig->new_from_hashref({ %$_, category => 'session' });
      $self->{'das_sources'}{$das->logic_name} = $das;
    }
  }
  
  my @das_sources = values %{$self->{'das_sources'}};
     @das_sources = grep $_->matches_species($species), @das_sources unless $species eq 'ANY';
  my %by_name     = map { $_->logic_name => $_ } @das_sources;
  
  return \%by_name unless wantarray;
  
  my %by_url = map { $_->full_url => $_ } @das_sources;
  
  return (\%by_name, \%by_url); 
}

# Save all session-specific DAS sources back to the database
# Usage examples:
#   $session->add_das( $source1 );
#   $source2->mark_deleted;       # delete entirely
#   $source3->category( 'user' ); # move from session to user
#   $source3->mark_altered;       # mark as updated
#   $session->save_das;           # save session data
sub save_das {
  my $self       = shift;
  my $session_id = $self->create_session_id;
  
  foreach my $source (values %{$self->get_all_das('ANY')}) {
    # If the source hasn't changed in some way, skip it
    next unless $source->is_altered;
    
    # Delete moved or deleted records
    if ($source->is_deleted || !$source->is_session) {
      EnsEMBL::Web::Data::Session->reset_config(
        session_id => $session_id,
        type       => 'das',
        code       => $source->logic_name,
      );
    } else {
      # Create new source records
      EnsEMBL::Web::Data::Session->set_config(
        session_id => $session_id,
        type       => 'das',
        code       => $source->logic_name,
        data       => $source,
      );
    }
  }
}

# Add a new DAS source within the session
sub add_das {
  my ($self, $das) = @_;
  
  # If source is different to any thing added so far, add it
  if (my $new_name = $self->get_unique_das_source_name($das)) {
    $das->logic_name($new_name);
    $das->category('session');
    $das->mark_altered;
    $self->{'das_sources'}{$new_name} = $das;
    return  1;
  }
  
  # Otherwise skip it
  return 0;
}

sub add_das_from_string {
  my $self    = shift;
  my $string  = shift;
  my @existing = $self->hub->get_all_das;
  my $parser   = $self->das_parser;
  my ($server, $identifier) = $parser->parse_das_string($string);
  my $error;
  
  # If we couldn't reliably parse an identifier (i.e. string is not a URL),
  # assume it is a registry ID
  if (!$identifier) {
    $identifier = $string;
    $server     = $self->hub->species_defs->DAS_REGISTRY_URL;
  }

  # Check if the source has already been added, otherwise add it
  my $source = $existing[0]->{$identifier} || $existing[1]->{"$server/$identifier"};
  
  if (!$source) {
    # If not, parse the DAS server to get a list of sources...
    eval {
      foreach (@{$parser->fetch_Sources( -location => $server )}) { 
        # ... and look for one with a matcing URI or DSN
        if ($_->logic_name eq $identifier || $_->dsn eq $identifier) { 
        
          if (!@{$_->coord_systems}) { 
            $error = "Unable to add DAS source $identifier as it does not provide any details of its coordinate systems";
            return;  
          }
          
          $source = EnsEMBL::Web::DASConfig->new_from_hashref($_); 
          $self->add_das($source);
          last;
        }
      }
    };
    
    $error = "DAS error: $@" if $@;
  }

  if ($source) {
    # so long as the source is 'suitable' for this view, turn it on
    $self->configure_das_views($source, @_) unless $error;
  } else { 
    $error ||= "Unable to find a DAS source named $identifier on $server";
  }
  
  if ($error) {
    $self->add_data(
      type     => 'message',
      function => '_warning',
      code     => 'das:' . md5_hex($string),
      message  => sprintf('You attempted to attach a DAS source with DSN: %s, unfortunately we were unable to attach this source (%s).', encode_entities($string), encode_entities($error))
    );
  }
  
  return $source ? $source->logic_name : undef;
}

# Switch on a DAS source for the current view/image (if it is suitable)
#
# This method has to deal with two types of configurations - those of views
# and those of images. Non-positional DAS sources are attached to views, and
# positional sources are attached to images. The source automatically becomes
# available on all the views/images it is -suitable for-, and this method
# switches it on for the current view/image provided it is suitable.
#
# The DASConfig "is_on" method gives a way to test whether a source is
# suitable for a view (e.g. Gene/ExternalData) or image (e.g contigviewbottom).
#
# Find images on the current view that support DAS and for which the DAS
# source is suitable, optionally filtered with
# an override. But don't trust the override to always indentify an image that
# supports DAS!
sub configure_das_views {
  my ($self, $das, $image, $track_options) = @_;
  my $hub     = $self->hub;
  my $referer = $hub->referer;
  my $type    = $referer->{'ENSEMBL_TYPE'}   || $hub->type;
  my $action  = $referer->{'ENSEMBL_ACTION'} || $hub->action;
  
  $track_options->{'display'} ||= 'normal';
  
  foreach (@{$hub->components}) {
    my $view_config  = $hub->get_viewconfig($_, $type);
    my $image_config = $view_config->image_config;
    my $logic_name   = $das->logic_name;
    
    # If source is suitable for this VIEW (i.e. not image) - Gene/Protein DAS
    if ($das->is_on("$type/$_")) {
      # Need to set default to 'no' before we can set it to 'yes'
      $view_config->set_defaults({ $logic_name => 'no' }) unless $view_config->get($logic_name);
      $view_config->set($logic_name, 'yes');
      $view_config->altered = $logic_name;
    }
    
    next unless $view_config->image_config_das eq 'das'; # DAS-compatible image
    next if     $image && $image ne $image_config;       # optional override
    next unless $das->is_on($image_config);              # DAS source is suitable for this image
    
    $image_config = $hub->get_imageconfig($image_config);
    
    # Only attach user requested DAS source to images which have a configuration menu for them.
    next unless $image_config->get_node('user_data');
    
    # For IMAGES the source needs to be turned on for
    my $node = $image_config->get_node("das_$logic_name");
    
    if (!$node) {
      my %default_keys = map { $_ => '' } keys %$track_options, @{$self->{'das_image_defaults'}};
      $node = $image_config->tree->create_node("das_$logic_name", \%default_keys);
      $image_config->get_node('user_data')->append($node);
    }
    
    $node->set_user($_, $track_options->{$_}) for keys %$track_options;
    $image_config->altered = 1;
  }
}

sub configure_user_data {
  my ($self, $track_type, $track) = @_;
  my $hub = $self->hub;

  return unless $track->{'species'} eq $hub->species;
  
  my $type = $hub->referer->{'ENSEMBL_TYPE'} || $hub->type;
  
  foreach my $view_config (map { $hub->get_viewconfig($_, $type) || () } @{$hub->components}) {
    my $ic_code = $view_config->image_config;
    
    next unless $ic_code;
    
    my $image_config = $hub->get_imageconfig($ic_code);
    my $node         = $image_config->get_node("${track_type}_$track->{'code'}");
    
    if ($node) {
      $node->set_user('display', $node->get('renderers')->[2]);
      $image_config->altered = 1;
      $view_config->altered  = 1;
    }
  }
  
  $self->store;
}


1;
