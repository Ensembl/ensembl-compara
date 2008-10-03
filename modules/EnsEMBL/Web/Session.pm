package EnsEMBL::Web::Session;

use strict;
use Storable qw(nfreeze thaw);
use Bio::EnsEMBL::ColourMap;
use Apache2::RequestUtil;
use Data::Dumper qw(Dumper);
use Class::Std;

use EnsEMBL::Web::Tools::Encryption;
use EnsEMBL::Web::Cookie;
use EnsEMBL::Web::ExtURL;
use EnsEMBL::Web::ViewConfig;
use EnsEMBL::Web::ImageConfig;
use EnsEMBL::Web::DASConfig;
use EnsEMBL::Web::Data::Session;

use EnsEMBL::Web::Root;
our @ISA = qw(EnsEMBL::Web::Root);

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
  my %ImageConfigs_of  :ATTR;
  my %Path_of          :ATTR( :get<path> );
## Lazy loaded objects....
  my %ExtURL_of        :ATTR( :get<exturl> :set<exturl>  );
  my %Species_of       :ATTR( :name<species>      );
  my %ColourMap_of     :ATTR;
## User temporary data...
  my %TmpData_of       :ATTR( :get<tmp> :set<tmp>  );
## User shared data...
  my %SharedData_of    :ATTR( :get<shared> :set<sharedp>  );


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
  $Configs_of{      $ident } = {}; # Initialize empty hash!
  $ImageConfigs_of{ $ident } = {}; # Initialize emtpy hash!
  $TmpData_of{      $ident } = {}; # Initialize empty hash!
  $Path_of{         $ident } = ['EnsEMBL::Web', reverse @{$arg_ref->{'path'}||[]}];
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

sub get_tmp_data {
### TMP
### Retrieve all temporary data
  my ($self, $code) = @_; 

  $code ||= 'common';

  ## This is cached so return it unless "force" is set
  ## return $TmpData_of{ ident $self }{$code} if $TmpData_of{ ident $self }{$code};

  ## No session so cannot have anything configured!
  return unless $self->get_session_id;

  ## Get all TMP data from database!
  my @entries = EnsEMBL::Web::Data::Session->get_config(
    session_id => $self->get_session_id,
    type       => 'tmp',
  );
  
  foreach my $entry (@entries) {
    $TmpData_of{ ident $self }{$entry->code} = {
      %{ $TmpData_of{ ident $self }{$entry->code} || {} },
      %{ $entry->data || {} },
    };
  }

  return $TmpData_of{ ident $self }{$code};
}

sub set_tmp_data {
### TMP
### $object->get_session->set_tmp_data( $key => $value, ... ); - which will use 'common' for `code`
### or $object->get_session->set_tmp_data( $code => { $key => $value, ... } );
  my $self = shift; 
  my %args = ref $_[1] ? %{ $_[1] } : @_; 
  my $code = ref $_[1] ? $_[0] : 'common'; 

  $self->get_tmp_data($code)
    unless $TmpData_of{ ident $self }{$code};

  $TmpData_of{ ident $self }{$code} = {
    %{ $TmpData_of{ ident $self }{$code} || {} },
    %args,
  };
}

sub save_tmp_data {
### TMP Data
### Save all temporary data back to the database
  my ($self, $r) = @_;
  $self->create_session_id($r);
  
  while (my ($key, $value) = each %{$TmpData_of{ ident $self }}) {
    EnsEMBL::Web::Data::Session->set_config(
      session_id => $self->get_session_id,
      type       => 'tmp',
      code       => $key,
      data       => $value,
    );    
  }
}


###################################################################################################
##
## Share tmp and other data stuff
##
###################################################################################################

## TODO: whar about sharing non-tmp data?
sub share_tmp_data {
### Share
  my ($self, $code) = @_; 

  $code ||= 'common';
  return unless $self->get_session_id;

  ## Get TMP data from the database
  my $entry = EnsEMBL::Web::Data::Session->get_config(
    session_id => $self->get_session_id,
    type       => 'tmp',
    code       => $code,
  );

  my $share = $entry->share if $entry;
  return $share->data;
}

sub get_shared_data {
### Share
  my ($self, $id, $checksum) = @_; 
  return unless $self->get_session_id;

  ## TODO: error excemption
  die "Share violation."
    unless EnsEMBL::Web::Tools::Encryption::validate_checksum($id, $checksum);

  my $share = EnsEMBL::Web::Data::Session->new($id);

  ## Type??? (e.g. {type}{code} ) ???
  $SharedData_of{ ident $self }{$share->code} = {
    %{ $SharedData_of{ ident $self }{$share->code} || {} },
    $share->data,
  };
  
  return $share->data if $share;
}

# This method gets all configured DAS sources for the current session, i.e. all
# those either added or modified externally.
# Returns a hashref, indexed by logic_name.
sub get_all_das {
  my( $self, $species ) = @_;
  
  # If there is no session, there are no configs
  return {} unless $self->get_session_id;
  
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
      $das->category( 'session' );
      $Das_sources_of{ ident $self }{ $das->logic_name } = $das;
    }
  }
  
  if ( $species ) {
    return { map {
      $_->logic_name => $_
    } grep {
      $_->matches_species( $species )
    } values %{ $Das_sources_of{ ident $self } }};
  }
  
  return $Das_sources_of{ ident $self };
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
    next unless $source->is_altered;
    if( $source->is_deleted || !$source->is_session ) {
      EnsEMBL::Web::Data::Session->reset_config(
        session_id => $self->create_session_id,
        type       => 'das',
        code       => $source->logic_name,
      );
    } else {
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
  
  my $sources = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_all_das;
  for ( my $i = 0; 1; $i++ ) {
    my $test_name = $i ? $source->logic_name . "_$i" : $source->logic_name;
    if ( my $test_source = $sources->{$test_name} ) {
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
  
  if ( my $new_name = $self->_get_unique_source_name($das) ) {
    $das->logic_name( $new_name );
    $das->category  ( 'session' );
    $das->mark_altered;
    # Attach the DAS source..
    $Das_sources_of{ ident $self }{ $new_name } = $das;
    $self->update_configs_for_das( $das, qw(contigview geneview cytoview protview) );
  } else {
    return 0;
  }
  
  return 1;
}

# TODO: rework interface with drawing code
sub update_configs_for_das {
  my( $self, $DAS, @configs ) = @_;

  warn "....    @configs   .... DAS!!!!!!!!!!!!!!!!!!!!!!!!!!!";
  my %map = qw(
    enable    enable
    labelflag lflag
    depth     dep
    color     col
  );
  my $N = $DAS->logic_name;
  my %scripts  = map {($_=>1)} @{$DAS->enable||[]};
  foreach my $sc_name (@configs) {
    my $sc = $self->getViewConfig( $sc_name, 1 );
    foreach my $ic_name ( keys %{$sc->{'_image_config_names'}} ) {
      next  unless $sc->{'_image_config_names'}{$ic_name} eq 'das';
      $self->attachImageConfig( $sc_name, $ic_name );
      my $T = $self->getImageConfig( $ic_name, $ic_name );
      if( $scripts{ $sc_name } ) {
        $T->set( "managed_extdas_$N", 'on' ,      'on' , 1);
        $T->set( "managed_extdas_$N", 'manager' , 'das', 1);
        foreach my $K (keys %map) {
          $T->set( "managed_extdas_$N", $map{$K}, $DAS->$K, 1 );
        }
      } elsif( exists( $T->{'user'}->{$ic_name}->{$N} ) ) {
        $T->reset( "managed_extdas_$N" );
      }
    }
    my @das_tracks = $sc->get('das_sources');
    my %das_tracks = map {$_=>1} @das_tracks;
    ## NOW GENEVIEW / PROTVIEW saving
    if( $scripts{$sc_name} && !$das_tracks{$N} ) {
      $sc->set('das_sources',[@das_tracks,$N],1);
    } elsif( ! $scripts{$sc_name} && $das_tracks{$N} ) {
      delete $das_tracks{$N};
      $sc->set('das_sources',[keys %das_tracks],1);
    }
  }
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

  unless ($Configs_of{ ident $self }{$key} ) {
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
      if ($config && $config->data) {
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

