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
### {{EnsEMBL::Web::Hub::image_config_hash}},
### {{EnsEMBL::Web::Hub::get_viewconfig}},
### {{EnsEMBL::Web::Hub::attach_image_config}} all of which create either
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

use warnings;
no warnings 'uninitialized';
use strict;

use Storable qw(nfreeze thaw);
use Bio::EnsEMBL::ColourMap;
use Apache2::RequestUtil;
use Data::Dumper qw(Dumper);
use Time::HiRes qw(time);

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Tools::Encryption 'checksum';
use EnsEMBL::Web::Cookie;
use EnsEMBL::Web::ExtURL;
use EnsEMBL::Web::ViewConfig;
use EnsEMBL::Web::ImageConfig;
use EnsEMBL::Web::DASConfig;
use EnsEMBL::Web::Data::Session;
use Bio::EnsEMBL::ExternalData::DAS::SourceParser;

use base qw(EnsEMBL::Web::Root);

sub new {
  my( $class, $args ) = @_;
  my $self = {
    'adaptor'            => $args->{'adaptor'},
    'configs'            => {},
    'cookie'             => $args->{'cookie'},
    'colourmap'          => $args->{'colourmap'},
    'das_parser'         => $args->{'das_parser'},
    'das_sources'        => $args->{'das_sources'},
    'data'               => {},
    'exturl'             => $args->{'exturl'},
    'image_configs'      => {},
    'input'              => $args->{'input'},
    'path'               => ['EnsEMBL::Web', reverse @{$args->{'path'}||[]}],
    'request'            => $args->{'request'},
    'session_id'         => $args->{'session_id'},
    'species'            => $args->{'species'},
    'species_defs'       => $args->{'species_defs'},
    'das_image_defaults' => [ 'display', 'off' ],
  };

  bless $self, $class;
  return $self;
}

sub get_adaptor { return $_[0]->{'adaptor'}; }
sub set_adaptor { $_[0]->{'adaptor'} = $_[1]; }

sub get_input { return $_[0]->{'input'}; }
sub set_input { $_[0]->{'input'} = $_[1]; }

sub get_request { return $_[0]->{'request'}; }
sub set_request { $_[0]->{'request'} = $_[1]; }

sub get_species_defs { return $_[0]->{'species_defs'}; }
sub set_species_defs { $_[0]->{'species_defs'} = $_[1]; }

sub get_session_id { return $_[0]->{'session_id'}; }
sub set_session_id { $_[0]->{'session_id'} = $_[1]; }

sub get_configs { return $_[0]->{'configs'}; }
sub set_configs { $_[0]->{'configs'} = $_[1]; }

sub get_das_sources { return $_[0]->{'das_sources'}; }

sub get_image_configs { return $_[0]->{'image_configs'}; }
sub set_image_configs { $_[0]->{'image_configs'} = $_[1]; }

sub get_path { return $_[0]->{'path'}; }

sub get_species { return $_[0]->{'species'}; }
sub set_species { $_[0]->{'species'} = $_[1]; }

sub get_site { return ''; }

sub input {
### Wrapper accessor to keep code simple...
  my $self = shift;
  if (@_) {
    $self->{'input'} = @_;
  }
  return $self->{'input'};
}

sub exturl {
  my $self = shift;
  my $exturl = $self->{'exturl'};
  unless ($exturl) {
    $self->{'exturl'} = EnsEMBL::Web::ExtURL->new( $self->get_species, $self->get_species_defs );
    $exturl = $self->{'exturl'};
  }
  return $exturl;
}

sub colourmap {
### Gets the colour map
  my $self = shift;
  my $colourmap = $self->{'colourmap'};
  unless ($colourmap) {
    $self->{'colourmap'} = Bio::EnsEMBL::ColourMap->new( $self->get_species_defs );
    $colourmap = $self->{'colourmap'};
  }
  return $colourmap;
}

sub create_session_id {
### Gets session ID if the session ID doesn't exist
### a new one is grabbed and added to the users cookies
  my ($self, $r) = @_;
  $r = (!$r && Apache2::RequestUtil->can('request')) ? Apache2::RequestUtil->request() : undef;
  my $session_id = $self->get_session_id;
  return $session_id if $session_id;
  $session_id = EnsEMBL::Web::Data::Session->create_session_id;
  $self->set_session_id( $session_id );
  $self->get_cookie->create( $r, $session_id ) if $r;  
  return $session_id;
}

sub _temp_store {
  my( $self, $name, $code ) = @_;
### At any point can copy back value from image_config into the temporary storage space for the config!!
  $self->{'configs'}{$name}{'image_config_data'}{$code} =
    $self->{'configs'}{$name}{'user'}{'image_configs'}{$code} =
      $self->deepcopy( $self->{'image_configs'}{$code}{'user'} );
# warn Dumper( $self->{'configs'}{$name}{'user'}{'image_configs'}{$code} );
}

sub reset_config {
### Reset the config given by $config name in the storage hash
  my( $self, $configname ) = @_;
  return unless exists $self->{'configs'}{ $configname };
  $self->{'configs'}{ $configname }{ 'config' }->reset();
}

sub store {
### Write session back to the database if required...
### Only work with storable configs and only if they or attached
### image configs have been altered!
### 
### Comment: not really, we also have das and tmp data which needs
### to be stored as well
  my ($self, $r) = @_;
  my @storables = @{ $self->storable_data($r) };
  foreach my $storable (@storables) {
    EnsEMBL::Web::Data::Session->set_config(
      session_id => $self->create_session_id($r),
      type       => 'script',
      code       => $storable->{config_key},
      data       => $storable->{data},
    ) if $storable->{config_key};
  }
  $self->save_das;
}

sub storable_data {
  ### Returns an array ref of hashes suitable for dumping to a database record. 
  my($self,$r) = @_;
  my $return_data = [];
  foreach my $config_key ( keys %{$self->{'configs'}||{}} ) {
    my $sc_hash_ref = $self->{'configs'}{$config_key}||{};
    ## Cannot store unless told to do so by script config
    next unless $sc_hash_ref->{'config'}->storable;
    ## Start by setting the to store flag to 1 if the script config has been updated!
    my $to_store = $sc_hash_ref->{'config'}->altered;
    my $data = {
      'diffs'         => $sc_hash_ref->{'config'}->get_user_settings(),
      'image_configs' => {}
    };

    ## get the script config diffs
    foreach my $image_config_key ( keys %{$sc_hash_ref->{'config'}->{'_image_config_names'}||{} }) {
      my $image_config = $self->{'image_configs'}{$image_config_key};
      $image_config = $self->getImageConfig($image_config_key,$image_config_key) unless $image_config;
      next          unless $image_config->storable; ## Cannot store unless told to do so by image config
      $to_store = 1 if     $image_config->altered;  ## Only store if image config has changed...
      $data->{'image_configs'}{$image_config_key}  = $image_config->get_user_settings();
    }
    push @{ $return_data }, { config_key => $config_key, data => $data } if $to_store;
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
  my %args = (
    type => 'tmp',
    @_,
  );

  if ($args{code}) {
    ## Code is spcified
    $self->{'data'}{$args{type}}{$args{code}}
      if $self->{'data'}{$args{type}}{$args{code}};
  } elsif ($self->{'data'}{$args{type}}) {
    ## Code is not spcified // wantarray or not?
    my ($code) = keys %{ $self->{'data'}{$args{type}} };
    return wantarray ? values %{ $self->{'data'}{$args{type}} }
                     : $self->{'data'}{$args{type}}{$code};
  }

}

sub get_data {
### Retrieve the data
  my $self = shift;
  my %args = (
    type => 'upload',
    @_,
  );

  EnsEMBL::Web::Data::Session->propagate_cache_tags(
    session_id => $self->get_session_id,
    type       => $args{type},
    code       => $args{code},
  );

  ## No session so cannot have anything configured!
  return unless $self->get_session_id;

  ## Have a look in the cache
  return $self->get_cached_data(%args)
      if $self->get_cached_data(%args);

  $self->{'data'}{$args{type}} ||= {};

  ## Get all data of the given type from the database!
  my @entries = EnsEMBL::Web::Data::Session->get_config(
    session_id => $self->get_session_id,
    %args,
  );
  
  $self->{'data'}{$args{type}}{$_->code} = $_->data for @entries;

  return $self->get_cached_data(%args);
}

sub set_data {
  my $self = shift; 
  my %args = (
    type => 'upload',
    @_,
  );

  return unless $args{type} && $args{code};

  my $data = $self->get_data(
    type => $args{type},
    code => $args{code},
  );

  $self->{'data'}{$args{type}}{$args{code}} = {
    %{ $data || {} },
    type => $args{type},
    code => $args{code},
    %args,
  };
  
  $self->save_data(
    type => $args{type},
    code => $args{code},
  );
}

sub purge_data {
### $object->get_session->purge_data()
  my $self = shift; 
  my %args = (
    type => 'upload',
    @_,
  );
  
  if ($args{code}) {
    delete $self->{'data'}{$args{type}}{$args{code}};
  } else {
    $self->{'data'}{$args{type}} = {};
  }
  
  $self->save_data(%args);
}

## For multiple objects, such as upload or urls
sub add_data {
### $object->get_session->add_data()
  my $self = shift; 
  my %args = (
    type => 'upload',
    @_,
  );
  
  ## Unique code
  $args{code} ||= time;
  $self->set_data(%args);

  return $self->get_data(type => $args{type}, code => $args{code});
}

sub save_data {
### Save all data back to the database
  my $self = shift;
  my %args = (
    type => 'upload',
    @_,
  );
  $self->create_session_id;
  
  EnsEMBL::Web::Data::Session->reset_config(
    %args,
    session_id => $self->get_session_id,
  );
  
  foreach my $data ($self->get_data(%args)) {
    next unless $data && %$data;
    
    EnsEMBL::Web::Data::Session->set_config(
      session_id => $self->get_session_id,
      type       => $args{type},
      code       => $data->{code},
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
  # Share
  my ($self, @share_refs) = @_; 
  
  my (@success, @failure);
  
  foreach my $share_ref (@share_refs) {
    my $record;
    
    if ($share_ref =~ /^(\d+)-(\w+)$/) {
      # User record:
      my $id = $1;
      my $checksum = $2;
      
      die 'Sharing violation' unless checksum($id) ne $checksum;
      
      $record = EnsEMBL::Web::Data::Record::Upload::User->new($id);
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
    my $n = scalar @failure;
    my $msg = "The data has been removed from $n of the shared sets that you are looking for.";
    
    $self->add_data(
      type => 'message', 
      code => 'no_data:' . (join ',', sort @failure), 
      message => $msg, 
      function => '_warning'
    );
  }
  
  if (@success) {
    my $tracks = join '</li><li>', @success;
    $tracks = "<ul><li>$tracks</li></ul>";
    
    $self->add_data(
      type => 'message', 
      code => 'shared_data:' . (join ',', map $_[0], @share_refs),
      message => "The following added tracks displayed in the image below are shared data:$tracks", 
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
  
  if ( $species eq 'common' ) {
    $species = '';
  }
  
  ## TODO: get rid of session getters,
  EnsEMBL::Web::Data::Session->propagate_cache_tags(
    session_id => $self->get_session_id,
    type       => 'das',
  );  

  # If there is no session, there are no configs
  return ({},{}) unless $self->get_session_id;
  
  # If the cache hasn't been initialised, do it
  if ( ! $self->{'das_sources'} ) {
    
    $self->{'das_sources'} = {};
    
    # Retrieve all DAS configurations from the database
    my @configs = EnsEMBL::Web::Data::Session->get_config(
      session_id => $self->get_session_id,
      type       => 'das'
    );
    
    foreach my $config (@configs) {
      $config->data || next;
      # Create new DAS source from value in database...
      my $das = EnsEMBL::Web::DASConfig->new_from_hashref( $config->data );
      $das->category( 'session' ); # paranoia...
      $self->{'das_sources'}{ $das->logic_name } = $das;
    }
  }
  
  my %by_name = ();
  my %by_url  = ();
  for my $das ( values %{ $self->{'das_sources'}} ) {
    unless ($species eq 'ANY') {
      $das->matches_species( $species ) || next;
    }
    $by_name{$das->logic_name} = $das;
    $by_url {$das->full_url  } = $das;
  }
  
  return wantarray ? ( \%by_name, \%by_url ) : \%by_name;
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
  
  foreach my $source ( values %{ $self->get_all_das('ANY') } ) {
    # If the source hasn't changed in some way, skip it
    next unless $source->is_altered;
    # Delete moved or deleted records
    if( $source->is_deleted || !$source->is_session ) {
      EnsEMBL::Web::Data::Session->reset_config(
        session_id => $self->create_session_id,
        type       => 'das',
        code       => $source->logic_name,
      );
    }
    # Create new source records
    else {
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
  my( $self, $source ) = @_;
  
  my @sources = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_all_das;
  for ( my $i = 0; 1; $i++ ) {
    my $test_name = $i ? $source->logic_name . "_$i" : $source->logic_name;
    my $test_url  = $i ? $source->full_url   . "_$i" : $source->full_url;
    
    my $test_source = $sources[0]->{$test_name} || $sources[1]->{$test_url};
    if ( $test_source ) {
      if ( $source->equals( $test_source ) ) {
        return;
      }
      next;
    }
    
    return $test_name;
  }
  
}

# Add a new DAS source within the session
sub add_das {
  my ( $self, $das ) = @_;
  
  # If source is different to any thing added so far, add it
warn "ADD $das...";
  if( my $new_name = $self->_get_unique_source_name($das) ) {
warn ">> $new_name <<";
    $das->logic_name( $new_name );
    $das->category  ( 'session' );
    $das->mark_altered;
    $self->{'das_sources'}{ $new_name } = $das;
    return  1;
  }
  
  # Otherwise skip it
  return 0;
}

# Switch on a DAS source for the current view/image (if it is suitable)
sub configure_das_views {
  my ($self, $das, $referer_hash, $track_options) = @_;
  my $this_type   = $referer_hash->{'ENSEMBL_TYPE'  } || $ENV{'ENSEMBL_TYPE'};
  my $this_action = $referer_hash->{'ENSEMBL_ACTION'} || $ENV{'ENSEMBL_ACTION'};
  my $this_image  = $referer_hash->{'ENSEMBL_IMAGE'};
  $track_options->{'display'} ||= 'normal';
  my $this_vc     = $self->getViewConfig( $this_type, $this_action );
  my %this_ics    = $this_vc->image_configs();
  
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
    $this_ics{$_} eq 'das' && # DAS-compatible image
    (!$this_image || $this_image eq $_) && # optional override
    $das->is_on( $_ ) # DAS source is suitable for this image
  } keys %this_ics;
    
  # If source is suitable for this VIEW (i.e. not image) - Gene/Protein DAS
  if ( $das->is_on( "$this_type/$this_action" ) ) {
    # Need to set default to 'no' before we can set it to 'yes'
    if ( !$this_vc->is_option( $das->logic_name ) ) {
      $this_vc->_set_defaults( $das->logic_name, 'no'  );
    }
    $this_vc->set( $das->logic_name, 'yes' );
  }
  # For all IMAGES the source needs to be turned on for
  for my $image ( @this_images ) {
    my $ic = $self->getImageConfig( $image, $image );
    my $n = $ic->get_node( 'das_' . $das->logic_name );
    if( !$n ) {
      my %tmp = ( map( { ($_=>'') } keys %$track_options ), @{$self->{'das_image_defaults'}} );
      $n = $ic->tree->create_node( 'das_' . $das->logic_name, \%tmp );
    }
    $n->set_user( %{ $track_options } );
    $ic->altered = 1;
  }
  
  return;
}

sub get_das_parser {
  my $self = shift;
  $self->{'das_parser'} ||= Bio::EnsEMBL::ExternalData::DAS::SourceParser->new(
    -timeout  => $self->get_species_defs->ENSEMBL_DAS_TIMEOUT,
    -proxy    => $self->get_species_defs->ENSEMBL_WWW_PROXY,
    -noproxy  => $self->get_species_defs->ENSEMBL_NO_PROXY,
  );
  return $self->{'das_parser'};
}

sub add_das_from_string {
  my ( $self, $string, $view_details, $track_options ) = @_;

  my @existing = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_all_das();
  my $parser = $self->get_das_parser();
  my ($server, $identifier) = $parser->parse_das_string( $string );
  # If we couldn't reliably parse an identifier (i.e. string is not a URL),
  # assume it is a registry ID
#warn "... $string - $server - $identifier";
  if ( !$identifier ) {
    $identifier = $string;
    $server     = $self->get_species_defs->DAS_REGISTRY_URL;
  }

  # Check if the source has already been added, otherwise add it
  my $source = $existing[0]->{$identifier} || $existing[1]->{"$server/$identifier"};

  unless ($source) {
    # If not, parse the DAS server to get a list of sources...
    eval {
      for ( @{ $parser->fetch_Sources( -location => $server ) } ) {
        # ... and look for one with a matcing URI or DSN
        if ( $_->logic_name eq $identifier || $_->dsn eq $identifier ) {
          if (!@{ $_->coord_systems }) {
            return "Unable to add DAS source $identifier as it does not provide any details of its coordinate systems";
          }
          $source = EnsEMBL::Web::DASConfig->new_from_hashref( $_ );
          $self->add_das( $source );
          last;
        }
      }
    };
    if ($@) {
      return "DAS error: $@";
    }
  }

  if( $source ) {
    # so long as the source is 'suitable' for this view, turn it on
    $self->configure_das_views( $source, $view_details, $track_options );
  } else {
    return "Unable to find a DAS source named $identifier on $server";
  }

  return;
}

sub attachImageConfig {
  my $self   = shift;
  my $script = shift;
  return unless $self->{'configs'}{$script};
  foreach my $image_config (@_) {
    $self->{'configs'}{$script}{'image_configs'}{$image_config} = 1;
  }
  return;
}

sub getViewConfig {
  ### Create a new {{EnsEMBL::Web::ViewConfig}} object for the script passed
  ### Loops through core and all plugins looking for a EnsEMBL::*::ViewConfig::$script
  ### package and if it exists calls the function init() on the package to set
  ### (a) the default values, (b) whether or not the user can over-ride these settings
  ### loaded in the order: core first, followed each of the plugin directories
  ### (from bottom to top in the list in conf/Plugins.pm)
  ###
  ### If a session exists and the code is storable connect to the database and retrieve
  ### the data from the session_data table
  ###
  ### Then loop through the {{EnsEMBL::Web::Input}} object and set anything in this
  ### Keep a record of what the user has changed
  
  my $self   = shift;
  my $type   = shift;
  my $action = shift;
  my $key    = "${type}::$action";

  # TODO: get rid of session getters,
  EnsEMBL::Web::Data::Session->propagate_cache_tags(
    session_id => $self->get_session_id,
    type       => $type,
    code       => $key
  );  

  if (!$self->{'configs'}{$key}) {
    my $view_config = new EnsEMBL::Web::ViewConfig($type, $action, $self);
    
    foreach my $root (@{$self->get_path}) {
      $view_config->add_class("${root}::ViewConfig::$key");
    }
    
    my $image_config_data = {};
    
    if ($self->get_session_id && $view_config->storable) {
      # Let us see if there is an entry in the database and load it into the script config and store any other data which comes back
      my $config = EnsEMBL::Web::Data::Session->get_config(
        session_id => $self->get_session_id,
        type       => 'script',
        code       => $key,
      );
      
      if ($config && $config->data) {
        $view_config->set_user_settings($config->data->{'diffs'});
        $image_config_data = $config->data->{'image_configs'};
      }
    }
    
    $self->{'configs'}{$key} = {
      config            => $view_config,
      image_configs     => {},                # List of attached image configs
      image_config_data => $image_config_data # Data retrieved from database to define image config settings.
    };
  }
  
  return $self->{'configs'}{$key}{'config'};
}

sub get_view_config_as_string {
  my ($self, $type, $action ) = @_;

  if( $self->get_session_id ) {
    my $config = EnsEMBL::Web::Data::Session->get_config(
      session_id => $self->get_session_id,
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
    session_id => $self->get_session_id,
    type       => 'view',
    code       => $type.'::'.$action,
    data       => $string,
  );
}

sub getImageConfig {
### Returns an image Config object...
### If passed one parameter then it loads the data (and doesn't cache it)
### If passed two parameters it loads the data (and caches it against the second name - NOTE you must use the
### second name version IF you want the configuration to be saved by the session - otherwise it will be lost
  my( $self, $type, $key, @species ) = @_;

### Third parameter is the species! if passed this gets pushed through to new ImageConfig call
### via the call get_ImageConfig below...

  ## TODO: get rid of session getters,
  EnsEMBL::Web::Data::Session->propagate_cache_tags(
    session_id => $self->get_session_id,
    type       => $type,
    code       => $key,
  );  
  
## If key is not set we aren't worried about caching it!
  if( $key && exists $self->{'image_configs'}{$key} ) {
    return $self->{'image_configs'}{$key};
  }
  my $image_config = $self->get_ImageConfig( $type, @species ) ;

  foreach my $script ( keys %{$self->{'configs'}||{}} ) {
    if( $self->{'configs'}{$script}{'image_config_data'}{$type} ) {
      my $T = $self->{'configs'}{$script}{'image_config_data'}{$type}||{};
      foreach (keys %$T) {
        $image_config->tree->{_user_data}{$_} = $self->deepcopy( $T->{$_} );
      }
    }
  }
## Store if $key is set!
  $self->{'image_configs'}{ $key } = $image_config if $key;
  return $image_config;
}

sub get_ImageConfig {
### Return a new image config object...
  my( $self, $type, @species ) = @_; ## @species is a optional scalar!!!

  return undef if $type eq '_page';
  my $classname = '';
## Let us hack this for the moment....
## If a site is defined in the configuration look for
## an the user config object in the namespace EnsEMBL::Web::ImageConfig::{$site}::{$type}
## Otherwise fall back on the module EnsEMBL::Web::ImageConfig::{$type}

  if( $self->get_site ) {
    $classname = "EnsEMBL::Web::ImageConfig::".$self->get_site."::$type";
    eval "require $classname";
  }
  if($@ || !$self->get_site ) {
    my $classname_old = $classname;
    $classname = "EnsEMBL::Web::ImageConfig::$type";
    eval "require $classname";
## If the module can't be required throw and error and return undef;
    if($@) {
      warn(qq(ImageConfigAdaptor failed to require $classname_old OR $classname: $@\n));
      return undef;
    }
  }
## Import the module
  $classname->import();
  $self->colourmap;
  my $image_config = eval { $classname->new( $self, @species ); };
  if( $@ || !$image_config ) { warn(qq(ImageConfigAdaptor failed to create new $classname: $@\n)); }
## Return the respectiv config.
  return $image_config;
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

