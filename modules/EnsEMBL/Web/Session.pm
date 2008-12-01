package EnsEMBL::Web::Session;

use strict;
use Storable qw(nfreeze thaw);
use Bio::EnsEMBL::ColourMap;
use Apache2::RequestUtil;
use Data::Dumper qw(Dumper);
use Time::HiRes qw(time);
use Class::Std;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Tools::Encryption 'checksum';
use EnsEMBL::Web::Cookie;
use EnsEMBL::Web::ExtURL;
use EnsEMBL::Web::ViewConfig;
use EnsEMBL::Web::ImageConfig;
use EnsEMBL::Web::DASConfig;
use EnsEMBL::Web::Data::Session;
use Bio::EnsEMBL::ExternalData::DAS::SourceParser;

use EnsEMBL::Web::Root;
our @ISA = qw(EnsEMBL::Web::Root);
our %DAS_IMAGE_DEFAULTS = ( 'display' => 'off' );

{
## Standard initialized attributes...
  my %Cookie_of        :ATTR( :name<cookie>       );
  my %Adaptor_of       :ATTR( :name<adaptor>      );
  my %Input_of         :ATTR( :get<input>    :set<input>    );
  my %Request_of       :ATTR( :get<request>  :set<request>  );
  my %SpeciesDef_of    :ATTR( :name<species_defs> );
  my %Session_id_of    :ATTR( :name<session_id>   );
## Modified parameters built in BUILD fnuction...
  my %Configs_of       :ATTR;
  my %Das_sources_of   :ATTR( :get<das_sources>  );
  my %Das_parser_of    :ATTR;
  my %ImageConfigs_of  :ATTR;
  my %Path_of          :ATTR( :get<path> );
## Lazy loaded objects....
  my %ExtURL_of        :ATTR( :get<exturl> :set<exturl>  );
  my %Species_of       :ATTR( :name<species>      );
  my %ColourMap_of     :ATTR;

## Common data (tmp upload, upload, url, etc) ...
  my %Data_of       :ATTR( :get<tmp> :set<tmp>  );


### New Session object - passed around inside the data object to handle storage of
### ViewConfigs/ImageConfigs in the web_user_db
###
### How it is used...
###
### The session object is "lazily" attached to {{EnsEMBL::Web::Proxiable}} objects and is
### accessed via {{EnsEMBL::Web::Proxiable::get_session}} method. You usually won't need
### to do this explicitly - because it is done implicitly by methods such as:
###
### {{EnsEMBL::Web::Proxiable::get_imageconfig}},
### {{EnsEMBL::Web::Proxiable::image_config_hash}},
### {{EnsEMBL::Web::Proxiable::get_viewconfig}},
### {{EnsEMBL::Web::Proxiable::attach_image_config}} all of which create either
### {{EnsEMBL::Web::ViewConfig}} or {{EnsEMBL::Web::ImageConfig}} objects.
###
### These commands in turn access the database if we already have a session (whose is
### accessible by {{session_id}}) and if the appropriate viewconfig is defined as
### storable. (In this way it replaces the ViewConfigAdaptor/ImageConfigAdaptor modules
###
### At the end of the configuration section of the webpage if any data needs to be
### saved to the session this is done so (and if required a session cookie set and
### stored in the users browser. (See {{EnsEMBL::Web::Document::WebPage}} to see
### where this is done (by the {{EnsEMBL::Web::Proxiable::fix_session}} method.
###

sub get_site { return ''; }

sub BUILD {
  my( $class, $ident,  $arg_ref ) = @_;
### Most of the build functions is done automagically by Class::Std, two unusual ones
### are the path and Cookie object..
  $Configs_of      { $ident } = {}; # Initialize empty hash!
  $ImageConfigs_of { $ident } = {}; # Initialize emtpy hash!
  $Data_of         { $ident } = {}; # Initialize empty hash!
  $Path_of         { $ident } = ['EnsEMBL::Web', reverse @{$arg_ref->{'path'}||[]}];
}

sub input {
### Wrapper accessor to keep code simple...
  my $self = shift;
  return $self->get_input(@_);
}

sub exturl {
  my $self = shift;
  return $ExtURL_of{ident $self} ||= EnsEMBL::Web::ExtURL->new( $self->get_species, $self->get_species_defs );
}

sub colourmap {
### Gets the colour map
  my $self = shift;
  return $ColourMap_of{ident $self} ||= Bio::EnsEMBL::ColourMap->new( $self->get_species_defs );
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
#warn "$name .... ", $Configs_of{ ident $self }{$name}," ... ",
#   $Configs_of{ ident $self }{$name}{'image_config_data'}{$code}," ... ",
#   $ImageConfigs_of{ident $self}{$code}{'user'};
  $Configs_of{ ident $self }{$name}{'image_config_data'}{$code} =
  $Configs_of{ ident $self }{$name}{'user'}{'image_configs'}{$code} =
    $self->deepcopy( $ImageConfigs_of{ident $self}{$code}{'user'} );
# warn Dumper( $self->{'configs'}{$name}{'user'}{'image_configs'}{$code} );
}

sub reset_config {
### Reset the config given by $config name in the storage hash
  my( $self, $configname ) = @_;
  return unless exists $Configs_of{ ident $self }{ $configname };
  $Configs_of{ ident $self }{ $configname }{ 'config' }->reset();
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
  foreach my $config_key ( keys %{$Configs_of{ ident $self }||{}} ) {
    my $sc_hash_ref = $Configs_of{ ident $self }{$config_key}||{};
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
      my $image_config = $ImageConfigs_of{ ident $self }{$image_config_key};
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
    return $Data_of{ ident $self }{$args{type}}{$args{code}}
      if $Data_of{ ident $self }{$args{type}}{$args{code}};
  } elsif ($Data_of{ ident $self }{$args{type}}) {
    ## Code is not spcified // wantarray or not?
    my ($code) = keys %{ $Data_of{ ident $self }{$args{type}} };
    return wantarray ? values %{ $Data_of{ ident $self }{$args{type}} }
                     : $Data_of{ ident $self }{$args{type}}{$code};
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

  $Data_of{ ident $self }{$args{type}} ||= {};

  ## Get all data of the given type from the database!
  my @entries = EnsEMBL::Web::Data::Session->get_config(
    session_id => $self->get_session_id,
    %args,
  );
  
  $Data_of{ ident $self }{$args{type}}{$_->code} = $_->data for @entries;

###  use Data::Dumper; warn Dumper($Data_of{ ident $self });

  ## Make empty {} if none found
  #$Data_of{ ident $self }{$args{type}}{$args{code}} ||= {} if $args{code};

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

  $Data_of{ ident $self }{$args{type}}{$args{code}} = {
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
    delete $Data_of{ ident $self }{$args{type}}{$args{code}};
  } else {
    $Data_of{ ident $self }{$args{type}} = {};
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
### Share
  my ($self, @share_refs) = @_; 

  foreach my $share_ref (@share_refs) {
    if ($share_ref =~ /^(\d+)-(\w+)$/) {
    ## User record:
      my $id = $1;
      my $checksum = $2;
      die 'Sharing violation'
        unless checksum($id) ne $checksum;
      my $record = EnsEMBL::Web::Data::Record::Upload::User->new($id);
      $self->add_data(%{ $record->data }) if $record;
    } else {
    ## Session record:
      my $record = EnsEMBL::Web::Data::Session->retrieve(code => $share_ref);
      $self->add_data(%{ $record->data }) if $record;
    }
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
  if ( ! $Das_sources_of{ ident $self } ) {
    
    $Das_sources_of{ ident $self } = {};
    
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
      $Das_sources_of{ ident $self }{ $das->logic_name } = $das;
    }
  }
  
  my %by_name = ();
  my %by_url  = ();
  for my $das ( values %{ $Das_sources_of{ ident $self } } ) {
    $das->matches_species( $species ) || next;
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
  
  foreach my $source ( values %{ $self->get_all_das } ) {
    # If the source hasn't changed in some way, skip it
#warn "$source -> $source->is_altered";
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
#warn "ADD $das...";
  if( my $new_name = $self->_get_unique_source_name($das) ) {
#warn ">> $new_name <<";
    $das->logic_name( $new_name );
    $das->category  ( 'session' );
    $das->mark_altered;
    $Das_sources_of{ ident $self }{ $new_name } = $das;
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
  $track_options->{'display'} ||= 'labels';
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
      my %tmp = ( map( { ($_=>'') } keys %$track_options ), %DAS_IMAGE_DEFAULTS );
      $n = $ic->tree->create_node( 'das_' . $das->logic_name, \%tmp );
    }
    $n->set_user( %{ $track_options } );
    $ic->altered = 1;
  }
  
  return;
}

sub get_das_parser {
  my $self = shift;
  $Das_parser_of{ ident $self } ||= Bio::EnsEMBL::ExternalData::DAS::SourceParser->new(
    -timeout  => $self->get_species_defs->ENSEMBL_DAS_TIMEOUT,
    -proxy    => $self->get_species_defs->ENSEMBL_WWW_PROXY,
    -noproxy  => $self->get_species_defs->ENSEMBL_NO_PROXY,
  );
  return $Das_parser_of{ ident $self };
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
          $source = EnsEMBL::Web::DASConfig->new_from_hashref( $_ );
          $self->add_das( $source );
          $self->save_das();
          last;
        }
      }
    };
  }

  if( $source ) {
    # so long as the source is 'suitable' for this view, turn it on
    $self->configure_das_views( $source, $view_details, $track_options );
  } else {
    return "Unable to find a source named $identifier on $server";
  }

  return;
}

sub deepcopy {
### Recursive deep copy of hashrefs/arrayrefs...
  my $self = shift;
  if (ref $_[0] eq 'HASH') {
    return { map( {$self->deepcopy($_)} %{$_[0]}) };
  } elsif (ref $_[0] eq 'ARRAY') {
    return [ map( {$self->deepcopy($_)} @{$_[0]}) ];
  }
  return $_[0];
}

sub attachImageConfig {
  my $self   = shift;
  my $script = shift;
  return unless $Configs_of{ ident $self }{$script};
  foreach my $image_config (@_) {
    $Configs_of{ ident $self }{$script}{'image_configs'}{$image_config}=1;
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
### Keep a record of what the user has changed!!
  my $self   = shift;
  my $type   = shift;
  my $action = shift;
  my $do_not_pop_from_params = shift;

  my $key = $type.'::'.$action;

  ## TODO: get rid of session getters,
  EnsEMBL::Web::Data::Session->propagate_cache_tags(
    session_id => $self->get_session_id,
    type       => $type,
    code       => $key,
  );  

  unless ($Configs_of{ ident $self }{$key} ) {
    my $flag = 0;
    my $view_config = EnsEMBL::Web::ViewConfig->new( $type, $action, $self );
    foreach my $root ( @{$self->get_path} ) {
      my $classname = $root."::ViewConfig::$key";
      unless( $self->dynamic_use( $classname ) ) {
        ## If the module can't be required throw an error and return undef;
        (my $message = "Can't locate $classname\.pm in" ) =~ s/::/\//g;
        my $error = $self->dynamic_use_failure($classname);
        warn qq(ViewConfig: failed to require $classname:\n  $error) unless $error=~/$message/;
        next;
      }
      $view_config->push_class( $classname );
      foreach my $part (qw(init)) {
        my $method_name = $classname."::".$part;
        eval { no strict 'refs'; &$method_name( $view_config ); };
        if( $@ ) {
          my $message = "Undefined subroutine &$method_name called";
          if( $@ =~ /$message/ ) {
            warn qq(ViewConfig: init not defined in $classname\n);
          } else {
            warn qq(ViewConfig: init call on $classname failed:\n$@);
          }
        } else {
          $view_config->real = 1;
        }
      }
    }
    my $image_config_data = {};
    if( $self->get_session_id && $view_config->storable ) {
      ## Let us see if there is an entry in the database and load it into the script config!
      ## and store any other data which comes back....
      my $config = EnsEMBL::Web::Data::Session->get_config(
        session_id => $self->get_session_id,
        type       => 'script',
        code       => $key,
      );
      if( $config && $config->data ) {
        $view_config->set_user_settings( $config->data->{'diffs'} );
        $image_config_data = $config->data->{'image_configs'};
      }
    }
#   unless( $do_not_pop_from_params ) {
#     warn "CALLED... update_from_input...";
#      $view_config->update_from_input( $self->input ); ## Needs access to the CGI.pm object...
#   }

    $Configs_of{ ident $self }{$key} = {
      'config'            => $view_config,         ## List of attached
      'image_configs'     => {},                   ## List of attached image configs
      'image_config_data' => $image_config_data    ## Data retrieved from database to define image config settings.
    };
  }
  return $Configs_of{ ident  $self }{$key}{'config'};
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
  my( $self, $type, $key ) = @_;

  ## TODO: get rid of session getters,
  EnsEMBL::Web::Data::Session->propagate_cache_tags(
    session_id => $self->get_session_id,
    type       => $type,
    code       => $key,
  );  
  
## If key is not set we aren't worried about caching it!
  if( $key && exists $ImageConfigs_of{ ident $self }{$key} ) {
    return $ImageConfigs_of{ ident $self }{$key};
  }
  my $image_config = $self->get_ImageConfig( $type ); # $ImageConfigs_of{ ident $self }{ $type };
  foreach my $script ( keys %{$Configs_of{ ident $self }||{}} ) {
    if( $Configs_of{ ident $self }{$script}{'image_config_data'}{$type} ) {
      my $T = $Configs_of{ ident $self }{$script}{'image_config_data'}{$type}||{};
      foreach (keys %$T) {
        $image_config->tree->{_user_data}{$_} = $self->deepcopy( $T->{$_} );
      }
    }
  }
## Store if $key is set!
  $ImageConfigs_of{ ident $self }{ $key } = $image_config if $key;
  return $image_config;
}

sub get_ImageConfig {
### Return a new image config object...
  my $self = shift;
  my $type = shift;
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
  my $image_config = eval { $classname->new( $self, @_ ); };
  if( $@ || !$image_config ) { warn(qq(ImageConfigAdaptor failed to create new $classname: $@\n)); }
## Return the respectiv config.
  return $image_config;
}

}
1;

