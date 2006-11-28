package EnsEMBL::Web::Session;

use EnsEMBL::Web::Cookie;
use EnsEMBL::Web::ExtURL;
use EnsEMBL::Web::ScriptConfig;
use EnsEMBL::Web::UserConfig;
use Storable qw(nfreeze thaw);
use Bio::EnsEMBL::ColourMap;
use Data::Dumper qw(Dumper);
use strict;
use Class::Std;
use EnsEMBL::Web::Root;
our @ISA = qw(EnsEMBL::Web::Root);

{
## Standard initialized attributes...
  my %Cookie_of        :ATTR( :name<cookie>       );
  my %Adaptor_of       :ATTR( :name<adaptor>      );
  my %Input_of         :ATTR( :name<input>        );
  my %SpeciesDef_of    :ATTR( :name<species_defs> );
  my %Request_of       :ATTR( :get<request>       :set<request>);
  my %Session_id_of    :ATTR( :name<session_id>   );
## Modified parameters built in BUILD fnuction...
  my %Configs_of       :ATTR;
  my %ImageConfigs_of  :ATTR;
  my %Path_of          :ATTR( :get<path> );
## Lazy loaded objects....
  my %ExtURL_of        :ATTR( :name<exturl>       );
  my %Species_of       :ATTR( :name<species>      );
  my %ColourMap_of     :ATTR;

### New Session object - passed around inside the data object to handle storage of
### ScriptConfigs/UserConfigs in the web_user_db
###
### How it is used...
###
### The session object is "lazily" attached to {{EnsEMBL::Web::Proxiable}} objects and is
### accessed via {{EnsEMBL::Web::Proxiable::get_session}} method. You usually won't need
### to do this explicitly - because it is done implicitly by methods such as:
###
### {{EnsEMBL::Web::Proxiable::get_userconfig}},
### {{EnsEMBL::Web::Proxiable::user_config_hash}},
### {{EnsEMBL::Web::Proxiable::get_scriptconfig}},
### {{EnsEMBL::Web::Proxiable::attach_image_config}} all of which create either
### {{EnsEMBL::Web::ScriptConfig}} or {{EnsEMBL::Web::UserConfig}} objects.
###
### These commands in turn access the database if we already have a session (whose is
### accessible by {{session_id}}) and if the appropriate scriptconfig is defined as
### storable. (In this way it replaces the ScriptConfigAdaptor/UserConfigAdaptor modules
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
  $Path_of{         $ident } = ['EnsEMBL::Web', reverse @{$arg_ref->{'path'}||[]}];
}

sub input {
### Wrapper accessor to keep code simple...
  my $self = shift;
  return $self->get_input(@_);
}

sub colourmap {
### Gets the colour map
  my $self = shift;
  return $ColourMap_of{ident $self} ||= Bio::EnsEMBL::ColourMap->new( $self->get_species_defs );
}

sub create_session_id {
### Gets session ID if the session ID doesn't exist
### a new one is grabbed and added to the users cookies
  my $self = shift;
  my $session_id = $self->get_session_id;
  return $session_id if $session_id;
  $session_id = $self->get_adaptor->create_session_id({$self->get_request});
  $self->set_session_id( $session_id );
  return $session_id;
}

sub _temp_store {
  my( $self, $name, $code ) = @_;
### At any point can copy back value from image_config into the temporary storage space for the config!!
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
  my $self = shift;
  foreach my $config_key ( keys %{$Configs_of{ ident $self }{'script_configs'}||{}} ) {
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
    foreach my $image_config_key ( keys %{$sc_hash_ref->{'image_configs'}} ) {
      my $image_config = $self->{'image_configs'}{$image_config_key};
      next          unless $image_config->storable; ## Cannot store unless told to do so by image config
      $to_store = 1 if     $image_config->altered;  ## Only store if image config has changed...
      $data->{'image_configs'}{$image_config_key}  = $image_config->get_user_settings();
    }
    if( $to_store ) {
      my $d =  Data::Dumper->new( [$data], [qw(data)] );
         $d->Indent(0);
      $self->get_adaptor->setConfigByName( $self->create_session_id, "new::$config_key", $d->Dump );
    }
  }
}

sub get_das {
  my $self = shift;
  return unles $self->get_session_id;
  my $data;
  my $TEMP = $self->get_adaptor->getConfigByName( $self->session_id, 'externaldas' );
  $TEMP = eval( $TEMP );
  return $TEMP || {};
}

sub save_das {
### Save das configuration
  my $self = shift;
  my $data = shift;
  my $d = Data::Dumper->new( [$data], [qw(data)] );
     $d->Indent(0);
  $self->get_adaptor->setConfigByName( $self->create_session_id, 'externaldas', $d->Dump );
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
warn "ATTACHING to $script $image_config ...";
    $Configs_of{ ident $self }{$script}{'image_configs'}{$image_config}=1;
  }
}

sub getScriptConfig {
### Create a new {{EnsEMBL::Web::ScriptConfig}} object for the script passed
### Loops through core and all plugins looking for a EnsEMBL::*::ScriptConfig::$script
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
  my $script = shift;

  unless( $Configs_of{ ident $self }{$script} ) {
    my $script_config = EnsEMBL::Web::ScriptConfig->new( $script, $self );

    foreach my $root ( @{$self->get_path} ) {
      my $classname = $root."::ScriptConfig::$script";
      unless( $self->dynamic_use( $classname ) ) {
## If the module can't be required thro and error and return undef;
        (my $message = "Can't locate $classname\.pm in" ) =~ s/::/\//g;
        my $error = $self->dynamic_use_failure($classname);
        warn qq(ScriptConfigAdaptor failed to require $classname:\n  $error) unless $error=~/$message/;
        next;
      }
      my $method_name = $classname."::init";
      eval {
        no strict 'refs';
        &$method_name( $script_config );
      };
      if( $@ ) {
        my $message = "Undefined subroutine &$method_name called";
        if( $@ =~ /$message/ ) {
          warn qq(ScriptConfigAdaptor: init not defined in $classname\n);
        } else {
          warn qq(ScriptConfigAdaptor init call on $classname failed:\n$@);
        }
      }
    }
    my $TEMP;
    my $image_config_data = {};
    if( $self->get_session_id && $script_config->storable ) {
## Let us see if there is an entry in the database and load it into the script config!
## and store any other data which comes back....
      $TEMP = $self->adaptor->getConfigByName( $self->session_id, "new::$script" );
      my $data;
      $TEMP = eval($TEMP);
      if( $TEMP ) {
        $script_config->set_user_settings( $TEMP->{'diffs'} );
        $image_config_data = $TEMP->{'image_configs'};
      }
    }
    $script_config->update_from_input( $self->input ); ## Needs access to the CGI.pm object...
    $Configs_of{ ident $self }{$script} = {
      'config'            => $script_config,       ## List of attached
      'image_configs'     => {},                   ## List of attached image configs
      'image_config_data' => $image_config_data    ## Data retrieved from database to define image config settings.
    };
  }
  return $Configs_of{ ident  $self }{$script}{'config'};
}

sub getImageConfig {
### Returns an image Config object...
### If passed one parameter then it loads the data (and doesn't cache it)
### If passed two parameters it loads the data (and caches it against the second name - NOTE you must use the
### second name version IF you want the configuration to be saved by the session - otherwise it will be lost
  my( $self, $type, $key ) = @_;
## If key is not set we aren't worried about caching it!
warn "$self - $type - $key";
  return $ImageConfigs_of{ ident $self }{$key} if $key && exists $ImageConfigs_of{ ident $self }{$key};
  my $user_config = $self->getUserConfig( $type ); # $ImageConfigs_of{ ident $self }{ $type };
  foreach my $script ( keys %{$Configs_of{ ident $self }||{}} ) {
warn "$script - $type";
    if( $Configs_of{ ident $self }{$script}{'image_config_data'}{$type} ) {
      $user_config->{'user'} = $self->deepcopy( $Configs_of{ ident $self }{$script}{'image_config_data'}{$type} );
    }
  }
## Store if $key is set!
  $ImageConfigs_of{ ident $self }{ $key } = $user_config if $key;
warn $user_config;
  return $user_config;
}

sub getUserConfig {
### Return a new image config object...
  my $self = shift;
  my $type = shift;
  my $classname = '';
## Let us hack this for the moment....
## If a site is defined in the configuration look for
## an the user config object in the namespace EnsEMBL::Web::UserConfig::{$site}::{$type}
## Otherwise fall back on the module EnsEMBL::Web::UserConfig::{$type}
  $type = 'contigviewbottom' if $type eq 'contigview'; # since there is no contigview config use contigviewbottom

  if( $self->get_site ) {
    $classname = "EnsEMBL::Web::UserConfig::".$self->get_site."::$type";
    eval "require $classname";
  }
  if($@ || !$self->get_site ) {
    my $classname_old = $classname;
    $classname = "EnsEMBL::Web::UserConfig::$type";
    eval "require $classname";
## If the module can't be required throw and error and return undef;
    if($@) {
      warn(qq(UserConfigAdaptor failed to require $classname_old OR $classname: $@\n));
      return undef;
    }
  }
## Import the module
  $classname->import();
  $self->colourmap;
  my $user_config = eval { $classname->new( $self, @_ ); };
  if( $@ || !$user_config ) { warn(qq(UserConfigAdaptor failed to create new $classname: $@\n)); }
## Return the respectiv config.
  return $user_config;
}

}
1;

