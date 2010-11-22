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
### The session object is "lazily" attached to {{EnsEMBL::Web::Hub}} objects and is
### accessed via the {{EnsEMBL::Web::Hub::session}} method. You usually won't need
### to do this explicitly - because it is done implicitly by methods such as:
###
### {{EnsEMBL::Web::Hub::get_imageconfig}},
### {{EnsEMBL::Web::Hub::get_viewconfig}} which create either
### {{EnsEMBL::Web::ViewConfig}} or {{EnsEMBL::Web::ImageConfig}} objects.
###
### These commands in turn access the database if we already have a session (whose is
### accessible by {{session_id}}) and if the appropriate viewconfig is defined as
### storable. (In this way it replaces the ViewConfigAdaptor/ImageConfigAdaptor modules
###
### At the end of the configuration section of the webpage if any data needs to be
### saved to the session this is done so (and if required a session cookie set and
### stored in the users browser. (See {{EnsEMBL::Web::Controller}} to see
### where this is done (by the {{EnsEMBL::Web::Hub::fix_session}} method.
###

use strict;

use Apache2::RequestUtil;
use Time::HiRes qw(time);
use Digest::MD5 qw(md5_hex);

use Bio::EnsEMBL::ExternalData::DAS::SourceParser;

use EnsEMBL::Web::DASConfig;
use EnsEMBL::Web::Data::Session;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::ImageConfig;
use EnsEMBL::Web::Tools::Encryption 'checksum';
use EnsEMBL::Web::ViewConfig;

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

sub DEPRECATED {
  my @caller = caller(1);
  my $warn   = "$caller[3] is deprecated and will be removed in release 61. ";
  my $func   = shift || [split '::', $caller[3]]->[-1];
  $warn     .= "Use EnsEMBL::Web::Hub::$func instead - $caller[1] line $caller[2]\n";
  warn $warn;
}

sub getImageConfig { DEPRECATED('get_imageconfig'); return shift->hub->get_imageconfig(@_); }
sub getViewConfig  { DEPRECATED('get_viewconfig');  return shift->hub->get_viewconfig(@_);  }

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

sub das_parser {
  my $self         = shift;
  my $species_defs = $self->hub->species_defs;
  
  return $self->{'das_parser'} ||= new Bio::EnsEMBL::ExternalData::DAS::SourceParser(
    -timeout  => $species_defs->ENSEMBL_DAS_TIMEOUT,
    -proxy    => $species_defs->ENSEMBL_WWW_PROXY,
    -noproxy  => $species_defs->ENSEMBL_NO_PROXY
  );
}

# TODO: Doesn't seem to be used. Delete? 
sub reset_config {
  ### Reset the config given by $config name in the storage hash
  
  my ($self, $configname) = @_;
  
  return unless exists $self->{'view_configs'}{$configname};
  $self->{'view_configs'}{$configname}{'config'}->reset;
}

sub store {
  ### Write session back to the database if required...
  ### Only work with storable configs and only if they or attached
  ### image configs have been altered!
  ### 
  ### Comment: not really, we also have das and tmp data which needs
  ### to be stored as well
  
  my $self = shift;
  
  foreach my $storable (grep $_->{'config_key'}, @{$self->storable_data}) {
    EnsEMBL::Web::Data::Session->set_config(
      session_id => $self->create_session_id,
      type       => 'script',
      code       => $storable->{'config_key'},
      data       => $storable->{'data'},
    );
  }
  
  $self->save_das;
}

sub storable_data {
  ### Returns an array ref of hashes suitable for dumping to a database record. 
  
  my $self        = shift;
  my $hub         = $self->hub;
  my $return_data = [];
  
  foreach my $config_key (keys %{$self->{'view_configs'} || {}}) {
    my $sc_hash_ref = $self->{'view_configs'}{$config_key} || {};
    
    ## Cannot store unless told to do so by script config
    next unless $sc_hash_ref->{'config'}->storable;
    
    ## Start by setting the to store flag to 1 if the script config has been updated!
    my $to_store = $sc_hash_ref->{'config'}->altered;
    
    my $data = {
      diffs         => $sc_hash_ref->{'config'}->get_user_settings,
      image_configs => {}
    };
    
    ## get the script config diffs
    foreach my $image_config_key (keys %{$sc_hash_ref->{'config'}->{'_image_config_names'} || {}}) {
      my $image_config = $self->{'image_configs'}{$image_config_key} || $hub->get_imageconfig($image_config_key, $image_config_key);
      
      next unless $image_config->storable;      ## Cannot store unless told to do so by image config
      
      $to_store = 1 if $image_config->altered;  ## Only store if image config has changed
      
      $data->{'image_configs'}{$image_config_key} = $image_config->get_user_settings;
    }
    
    push @$return_data, { config_key => $config_key, data => $data } if $to_store;
  }
  
  return $return_data; 
}

###################################################################################################
##
## Tmp data stuff
##
###################################################################################################

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
  
  my $self = shift;
  my %args = ( type => 'upload', @_ );

  EnsEMBL::Web::Data::Session->propagate_cache_tags(
    session_id => $self->session_id,
    type       => $args{'type'},
    code       => $args{'code'},
  );

  ## No session so cannot have anything configured!
  return unless $self->session_id;

  ## Have a look in the cache
  return $self->get_cached_data(%args) if $self->get_cached_data(%args);

  $self->{'data'}{$args{'type'}} ||= {};

  ## Get all data of the given type from the database!
  my @entries = EnsEMBL::Web::Data::Session->get_config(
    session_id => $self->session_id,
    %args,
  );
  
  $self->{'data'}{$args{'type'}}{$_->code} = $_->data for @entries;

  return $self->get_cached_data(%args);
}

sub set_data {
  my $self = shift; 
  my %args = ( type => 'upload', @_ );

  return unless $args{'type'} && $args{'code'};

  my $data = $self->get_data(
    type => $args{'type'},
    code => $args{'code'},
  );

  $self->{'data'}{$args{'type'}}{$args{'code'}} = {
    %{$data || {}},
    type => $args{'type'},
    code => $args{'code'},
    %args,
  };
  
  $self->save_data(
    type => $args{'type'},
    code => $args{'code'},
  );
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

  return $self->get_data(type => $args{'type'}, code => $args{'code'});
}

sub save_data {
  ### Save all data back to the database
  
  my $self = shift;
  my %args = ( type => 'upload', @_ );
  
  $self->create_session_id;
  
  EnsEMBL::Web::Data::Session->reset_config(
    %args,
    session_id => $self->session_id,
  );
  
  foreach my $data ($self->get_data(%args)) {
    next unless $data && %$data;
    
    EnsEMBL::Web::Data::Session->set_config(
      session_id => $self->session_id,
      type       => $args{'type'},
      code       => $data->{'code'},
      data       => $data,
    );    
  }

}

###################################################################################################
##
## Share upload data
##
###################################################################################################

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
      
      $record = new EnsEMBL::Web::Data::Record::Upload::User($id);
    } else {
      # Session record:
      $record = EnsEMBL::Web::Data::Session->retrieve(code => $share_ref);
    }
    
    if ($record) {
      $self->add_data(%{$record->data});
      push @success, $record->data->{'name'};
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
      message  => "The following added tracks displayed in the image below are shared data:$tracks", 
      function => '_info'
    );
  }
}

###################################################################################################

# This method gets all configured DAS sources for the current session, i.e. all
# those either added or modified externally.
# Returns a hashref, indexed by logic_name.
sub get_all_das {
  my $self    = shift;
  my $species = shift || $ENV{'ENSEMBL_SPECIES'};
  $species    = '' if $species eq 'common';
  
  ## TODO: get rid of session getters,
  EnsEMBL::Web::Data::Session->propagate_cache_tags(
    session_id => $self->session_id,
    type       => 'das',
  );  

  # If there is no session, there are no configs
  return ({}, {}) unless $self->session_id;
  
  # If the cache hasn't been initialised, do it
  if (!$self->{'das_sources'}) {
    $self->{'das_sources'} = {};
    
    # Retrieve all DAS configurations from the database
    my @configs = EnsEMBL::Web::Data::Session->get_config(
      session_id => $self->session_id,
      type       => 'das'
    );
    
    foreach my $config (@configs) {
      $config->data || next;
      # Create new DAS source from value in database
      my $das = EnsEMBL::Web::DASConfig->new_from_hashref($config->data);
      $das->category('session');
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
  my $self = shift;
  
  foreach my $source (values %{$self->get_all_das('ANY')}) {
    # If the source hasn't changed in some way, skip it
    next unless $source->is_altered;
    
    # Delete moved or deleted records
    if ($source->is_deleted || !$source->is_session) {
      EnsEMBL::Web::Data::Session->reset_config(
        session_id => $self->create_session_id,
        type       => 'das',
        code       => $source->logic_name,
      );
    } else {
      # Create new source records
      EnsEMBL::Web::Data::Session->set_config(
        session_id => $self->create_session_id,
        type       => 'das',
        code       => $source->logic_name,
        data       => $source,
      );
    }
  }
}

# This function will make sure that a das source is attached with a unique name
# So in case when you try to attach MySource it will return undef if exactly same
# source is already attached (i.e the same url, dsn and coords).
# If it's only the name that is the same then the function will provide a unique
# name for the new source , e.g name_1
sub _get_unique_source_name {
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

# Add a new DAS source within the session
sub add_das {
  my ($self, $das) = @_;
  
  # If source is different to any thing added so far, add it
  if (my $new_name = $self->_get_unique_source_name($das)) {
    $das->logic_name($new_name);
    $das->category('session');
    $das->mark_altered;
    $self->{'das_sources'}{$new_name} = $das;
    return  1;
  }
  
  # Otherwise skip it
  return 0;
}


sub configure_bam_views {
  my ($self, $bam, $track_options) = @_;
  my $hub         = $self->hub;
  my $referer     = $hub->referer;
  my $this_type   = $referer->{'ENSEMBL_TYPE'}   || $ENV{'ENSEMBL_TYPE'};
  my $this_action = $referer->{'ENSEMBL_ACTION'} || $ENV{'ENSEMBL_ACTION'};
  my $this_image  = $referer->{'ENSEMBL_IMAGE'};
  my $this_vc     = $hub->get_viewconfig($this_type, $this_action, $hub);
  my %this_ics    = $this_vc->image_configs;

  $track_options->{'display'} ||= 'normal';

  my @this_images = grep {
    (!$this_image || $this_image eq $_)  # optional override
  } keys %this_ics;

  foreach my $image (@this_images) {
    my $ic = $hub->get_imageconfig($image, $image);
    if ($bam->{species} eq $ic->{species}) {
      my $n  = $ic->get_node('bam_' . $bam->{name} . '_' . md5_hex($bam->{species} . ':' . $bam->{url}));

      if ($n) {
        $n->set_user(%$track_options);
        $ic->altered = 1;
      }
    }
  }

  return;
}

# Switch on a DAS source for the current view/image (if it is suitable)
sub configure_das_views {
  my ($self, $das, $track_options) = @_;
  my $hub         = $self->hub;
  my $referer     = $hub->referer;
  my $this_type   = $referer->{'ENSEMBL_TYPE'}   || $ENV{'ENSEMBL_TYPE'};
  my $this_action = $referer->{'ENSEMBL_ACTION'} || $ENV{'ENSEMBL_ACTION'};
  my $this_image  = $referer->{'ENSEMBL_IMAGE'};
  my $this_vc     = $hub->get_viewconfig($this_type, $this_action, $hub);
  my %this_ics    = $this_vc->image_configs;
  
  $track_options->{'display'} ||= 'normal';
  
  # This method has to deal with two types of configurations - those of views
  # and those of images. Non-positional DAS sources are attached to views, and
  # positional sources are attached to images. The source automatically becomes
  # available on all the views/images it is -suitable for-, and this method
  # switches it on for the current view/image provided it is suitable.
  
  # The DASConfig "is_on" method gives a way to test whether a source is
  # suitable for a view (e.g. Gene/ExternalData) or image (e.g contigview).
  
  # Find images on the current view that support DAS and for which the DAS
  # source is suitable, optionally filtered with
  # an override. But don't trust the override to always indentify an image that
  # supports DAS!
  my @this_images = grep {
    $this_ics{$_} eq 'das'              && # DAS-compatible image
    (!$this_image || $this_image eq $_) && # optional override
    $das->is_on($_)                        # DAS source is suitable for this image
  } keys %this_ics;
    
  # If source is suitable for this VIEW (i.e. not image) - Gene/Protein DAS
  if ($das->is_on($this_type)) {
    # Need to set default to 'no' before we can set it to 'yes'
    $this_vc->_set_defaults($das->logic_name, 'no') unless $this_vc->is_option($das->logic_name);
    $this_vc->set($das->logic_name, 'yes');
  }
  
  # For all IMAGES the source needs to be turned on for
  foreach my $image (@this_images) {
    my $ic = $hub->get_imageconfig($image, $image);
    my $n  = $ic->get_node('das_' . $das->logic_name);
    
    if (!$n) {
      my %tmp = ( map( { $_ => '' } keys %$track_options ), @{$self->{'das_image_defaults'}} );
      $n = $ic->tree->create_node('das_' . $das->logic_name, \%tmp);
    }
    
    $n->set_user(%$track_options);
    $ic->altered = 1;
  }
  
  return;
}

sub add_das_from_string {
  my ($self, $string, $view_details, $track_options) = @_;

  my @existing = $self->hub->get_all_das;
  my $parser   = $self->das_parser;
  my ($server, $identifier) = $parser->parse_das_string($string);
  
  # If we couldn't reliably parse an identifier (i.e. string is not a URL),
  # assume it is a registry ID
  if (!$identifier) {
    $identifier = $string;
    $server     = $self->hub->species_defs->DAS_REGISTRY_URL;
  }

  # Check if the source has already been added, otherwise add it
  my $source = $existing[0]->{$identifier} || $existing[1]->{"$server/$identifier"};
  my $no_coord_system;
  
  if (!$source) {
    # If not, parse the DAS server to get a list of sources...
    eval { 
      foreach (@{$parser->fetch_Sources( -location => $server )}) { 
        # ... and look for one with a matcing URI or DSN
        if ($_->logic_name eq $identifier || $_->dsn eq $identifier) { 
        
          if (!@{$_->coord_systems}) { 
            $no_coord_system =  "Unable to add DAS source $identifier as it does not provide any details of its coordinate systems";
            return;  
          }
          
          $source = EnsEMBL::Web::DASConfig->new_from_hashref($_); 
          $self->add_das($source);
          last;
        }
      }
    };
    
    return "DAS error: $@" if $@;
  }

  if ($source) {
    # so long as the source is 'suitable' for this view, turn it on
    $self->configure_das_views($source, $view_details, $track_options);
  } elsif ($no_coord_system) {
    return $no_coord_system;
  } else { 
    return "Unable to find a DAS source named $identifier on $server";
  }
  
  return;
}

sub apply_to_view_config {
  ### Adds session data to a view config
  
  my ($self, $view_config, $type, $key) = @_;
  
  EnsEMBL::Web::Data::Session->propagate_cache_tags(
    session_id => $self->session_id,
    type       => $type,
    code       => $key
  );  
  
  $view_config->init;
  
  my $image_config_data = {};
  
  if ($self->session_id && $view_config->storable) {
    # Let us see if there is an entry in the database and load it into the script config and store any other data which comes back
    my $config = EnsEMBL::Web::Data::Session->get_config(
      session_id => $self->session_id,
      type       => 'script',
      code       => $key,
    );
    
    if ($config && $config->data) {
      $view_config->set_user_settings($config->data->{'diffs'});
      $image_config_data = $config->data->{'image_configs'};
    }
  }
  
  $self->{'view_configs'}{$key} = {
    config            => $view_config,
    image_configs     => {},                # List of attached image configs
    image_config_data => $image_config_data # Data retrieved from database to define image config settings.
  };
}

sub apply_to_image_config {
  ### Adds session data to an image config
  
  my ($self, $image_config, $type, $key) = @_;
  
  EnsEMBL::Web::Data::Session->propagate_cache_tags(
    session_id => $self->session_id,
    type       => $type,
    code       => $key || $type,
  );
  
  foreach my $script (keys %{$self->{'view_configs'} || {}}) {
    my $ic = $self->{'view_configs'}{$script}{'image_config_data'}{$type} || {};
    
    $image_config->tree->{'_user_data'}{$_} = $self->deepcopy($ic->{$_}) for keys %$ic;
  }
  
  ## Store if $key is set
  $self->{'image_configs'}{$key} = $image_config if $key;
}

sub get_view_config_as_string {
  my ($self, $type, $action ) = @_;

  if( $self->session_id ) {
    my $config = EnsEMBL::Web::Data::Session->get_config(
      session_id => $self->session_id,
      type       => 'view',
      code       => $type.'::'.$action,
    );
    return $config->as_string if $config;
  }
  
  return undef; 
}

sub set_view_config_from_string {
  my ($self, $type, $action, $string) = @_;
  EnsEMBL::Web::Data::Session->set_config(
    session_id => $self->session_id,
    type       => 'view',
    code       => $type.'::'.$action,
    data       => $string,
  );
}

sub save_custom_page {
  my ($self, $code, $components) = @_;
  
  $self->add_data(
    type       => 'custom_page', 
    code       => $code,
    components => $components
  );
}

sub custom_page_config {
  my ($self, $code) = @_;
  
  my $config = $self->get_data(
    type => 'custom_page',
    code => $code,
  );
  
  return $config->{'components'} || [];
}

1;
