package EnsEMBL::Web::Session;

use strict;
use Storable qw(nfreeze thaw);
use Bio::EnsEMBL::ColourMap;
use Apache2::RequestUtil;
use Data::Dumper qw(Dumper);
use Class::Std;

use EnsEMBL::Web::Cookie;
use EnsEMBL::Web::ExtURL;
use EnsEMBL::Web::ScriptConfig;
use EnsEMBL::Web::UserConfig;
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
  my %Internal_das_of  :ATTR;
  my %Das_sources_of   :ATTR( :get<das_sources>  );
  my %ImageConfigs_of  :ATTR;
  my %Path_of          :ATTR( :get<path> );
## Lazy loaded objects....
  my %ExtURL_of        :ATTR( :get<exturl> :set<exturl>  );
  my %Species_of       :ATTR( :name<species>      );
  my %ColourMap_of     :ATTR;
## User temporary data...
  my %TmpData_of       :ATTR( :get<tmp> :set<tmp>  );


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
  $Das_sources_of{  $ident } = {}; # Initialize emtpy hash!
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
      data       => $storable->{data}->Dump,
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
    foreach my $image_config_key ( keys %{$Configs_of{ ident $self }{$config_key}{'image_configs'}||{} } ) {
      my $image_config = $ImageConfigs_of{ ident $self }{$image_config_key};
      next          unless $image_config->storable; ## Cannot store unless told to do so by image config
      $to_store = 1 if     $image_config->altered;  ## Only store if image config has changed...
      $data->{'image_configs'}{$image_config_key}  = $image_config->get_user_settings();
    }
    if( $to_store ) {
      my $d =  Data::Dumper->new( [$data], [qw($data)] );
         $d->Indent(1);
      push @{ $return_data }, { config_key => $config_key, data => $d };
    }
  }
  return $return_data; 
}

sub get_internal_das {
  my( $self, $force ) = @_;
  return $Internal_das_of{ ident $self } if keys %{ $Internal_das_of{ ident $self } } && ! $force;
  my $data;
  my $ini_confdata = $self->get_species_defs->ENSEMBL_INTERNAL_DAS_SOURCES;
  return {} unless ref( $ini_confdata ) eq 'HASH';
  foreach my $source ( keys %$ini_confdata ){
    my $source_confdata = $ini_confdata->{$source};
    next unless $source_confdata && ref($source_confdata) eq 'HASH';
    unless( defined $source_confdata->{enable} ) {
      @{ $source_confdata->{enable} } = @{ $source_confdata->{on}||[] } ;
    }
    my $dsn = $source_confdata->{dsn};
    $source_confdata->{url} .= "/$dsn" if ($source_confdata->{url} !~ /$dsn$/);
    my $DAS = EnsEMBL::Web::DASConfig->new;
    $DAS->load( $source_confdata );
    $DAS->set_internal();
    $Internal_das_of{ ident $self }{ $source } = $DAS;
  }
  return $Internal_das_of{ ident $self };
}
## DAS functionality - most of this is moved from EnsEMBL::Web::ExternalDAS which
## will be deprecated - and now stores each source in the database separately
## currently only works with External DAS sources - not Internally configured DAS
## sources, making these changes should make the re-work to use registry more
## useful - as we can add an "add_das_source_from_registry" call as well as
## the add_das_source_from_URL and add_das_source_from_hashref

sub get_tmp_data {
### TMP
### Retrieve all temporary data
  my ($self, $code) = @_; 

  $code ||= 'generic';

  ## This is cached so return it unless "force" is set
  ## return $TmpData_of{ ident $self }{$code} if $TmpData_of{ ident $self }{$code};

  ## No session so cannot have anything configured!
  return unless $self->get_session_id;

  ## Get all TMP data from database!
  my @entries = EnsEMBL::Web::Data::Session->get_config(
    session_id => $self->get_session_id,
    type       => 'tmp',
  );
  
  my $TEMP;
  foreach my $entry (@entries) {
    $TEMP = $entry->data;
    $TEMP = eval( $TEMP );
    $TmpData_of{ ident $self }{$entry->code} = $TEMP
      unless $@;
  }

  $TmpData_of{ ident $self }{$code} ||= {};
  
  return $TmpData_of{ ident $self }{$code};
}

sub set_tmp_data {
### TMP
### e.g. $object->get_session->set_tmp_data( $key => $value );
  my $self = shift; 
  my %args = ref $_[0] ? %{ $_[0] } : @_; 

  $TmpData_of{ ident $self }{'generic'} ||= {};
  $TmpData_of{ ident $self }{'generic'} = {
    %{ $TmpData_of{ ident $self }{'generic'} },
    %args,
  };
}

sub get_das {
### DAS
### Retrieve all externally configured DAS sources
### An optional "true" value forces the re-retrival of das sources, otherwise
### retrieved from the session hash...
  my( $self, $force ) = @_; 
  ## This is cached so return it unless "Force" is set to load in other stuff
  return $Das_sources_of{ ident $self } if keys %{ $Das_sources_of{ ident $self } } && ! $force;
  ## No session so cannot have anything configured!
  return unless $self->get_session_id;
  my $data;
  ## Get all DAS configurations from database!
  my @configs = EnsEMBL::Web::Data::Session->get_config(
    session_id => $self->get_session_id,
    type       => 'das'
  );
  my $TEMP;
  foreach my $config (@configs) {
    next if exists $Das_sources_of{ ident $self }{ $config->code };
    $TEMP = $config->data;
    $TEMP = eval( $TEMP );
    next unless $TEMP;
    ## Create new DAS source and load from value in database...
    my $DAS = EnsEMBL::Web::DASConfig->new;
    $DAS->load( $TEMP );
    $Das_sources_of{ ident $self }{$config->code} = $DAS;
  }
  return $Das_sources_of{ ident $self };
}

#sub get_das_filtered_and_sorted {
#  my( $self, $species ) = @_;
#  my $T = $self->get_das;# "GET DAS...", warn $T;
#  my @T =  
#    map  { $_->[1] }
#    sort { $a->[0] cmp $b->[0] }
#    map  { [ $_->get_data->{'label'}, $_ ] }
#    grep { !( exists $_->get_data->{'species'} && $_->get_data->{'species'} ne $self->{'species'} )} 
#    values %{ $T||{} };
#  return \@T;
#}

sub get_das_config {
### DAS
### Retrieve an individual externally configured DAS source
  my( $self, $key )  = @_;
  return $Das_sources_of{ ident $self }{$key} if exists $Das_sources_of{ ident $self }{$key};
  my $config = EnsEMBL::Web::Data::Session->get_config(
    session_id => $self->get_session_id,
    type       => 'das',
    code       => $key,
  );
  if ($config) {
    my $TEMP = eval( $config->data );
    next unless $TEMP;
    my $DAS = EnsEMBL::Web::DASConfig->new;
    $DAS->load( $TEMP );
    $Das_sources_of{ ident $self }{$key} = $DAS;
  }
  return $Das_sources_of{ ident $self }{$key};
}

sub save_das {
### DAS
### Save all externally configured DAS sources back to the database
  my ($self, $r) = @_;
  foreach my $source ( values %{$Das_sources_of{ ident $self }} ) {
    next unless $source->is_altered;
    if( $source->is_deleted ) {
      EnsEMBL::Web::Data::Session->reset_config(
        session_id => $self->get_session_id,
        type       => 'das',
        code       => $source->get_name,
      );
    } else {
      my $d =  Data::Dumper->new( [$source->get_data], [qw($data)] );
      $d->Indent(1);
      EnsEMBL::Web::Data::Session->set_config(
        session_id => $self->get_session_id,
        type       => 'das',
        code       => $source->get_name,
        data       => $d->Dump,
      );
    }
  }
  
}

sub save_tmp_data {
### TMP Data
### Save all temporary data back to the database
  my ($self, $r) = @_;
  $self->create_session_id($r);
  
  while (my ($key, $value) = each %{$TmpData_of{ ident $self }}) {
      my $d =  Data::Dumper->new( [$value], [qw($data)] );
      $d->Indent(1);
      EnsEMBL::Web::Data::Session->set_config(
        session_id => $self->get_session_id,
        type       => 'tmp',
        code       => $key,
        data       => $d->Dump,
      );    
  }
}


# This function will make sure that a das source is attached with a unique name
# So in case when you try to attach MySource it will return undef if exactly same source is already attached (
# i.e the same name, url, dsn and type) If it's only the name that is the same then the function will provide a unique name
# for the new source , e.g MySource_1
# NOTE: THhe function would be much simpler if get_das_config worked for internal sources as well ;)

sub get_unique_source_name {
  my( $self, $hash_ref ) = @_;
  my $URL = $hash_ref; 
  $URL =~ s/[\(|\)]//g;
  my @das_keys = split(/\s/, $URL);                    # break on spaces...
  my %das_data = map { split (/\=/, $_,2) } @das_keys; # split each entry on spaces
  my $key = $das_data{'name'};

  my $isrc = $self->get_internal_das();
  if (exists ($isrc->{$key})) {
    if (join('*',$isrc->{url}, $isrc->{dsn}, $isrc->{type}) eq join('*', $das_data{url}, $das_data{dsn}, $das_data{type})) {
      warn("WARNING: DAS source $key has not been added: It is already attached");
      return;
    }
    my $das_name_ori = $key;

    for( my $i = 1; 1; $i++ ){
      $key = $das_name_ori ."_$i";
       if (my $esrc = $self->get_das_config($key)) {
         if (join('*',$esrc->{_data}->{url}, $esrc->{_data}->{dsn}, $esrc->{_data}->{type}) eq join('*', $das_data{url}, $das_data{dsn}, $das_data{type})) {
           warn("WARNING: DAS source $key has not been added: It is already attached");
           return;
         }
	 next;
       }
       return $key;
    }
  }

  if (my $esrc = $self->get_das_config($key)) {
    if (join('*',$esrc->{_data}->{url}, $esrc->{_data}->{dsn}, $esrc->{_data}->{type}) eq join('*', $das_data{url}, $das_data{dsn}, $das_data{type})) {
      warn("WARNING: DAS source $key has not been added: It is already attached");
      return;
    }
    my $das_name_ori = $key;

    for( my $i = 1; 1; $i++ ){
      $key = $das_name_ori ."_$i";
       if (my $esrc = $self->get_das_config($key)) {
         if (join('*',$esrc->{_data}->{url}, $esrc->{_data}->{dsn}, $esrc->{_data}->{type}) eq join('*', $das_data{url}, $das_data{dsn}, $das_data{type})) {
           warn("WARNING: DAS source $key has not been added: It is already attached");
           return;
         }
         next;
       }
       return $key;
    }
  }
	
  return $key;
}

sub add_das_source_from_URL {
### DAS
### Create a new DAS source from a configuration hashref
  my( $self, $hash_ref ) = @_;
  
  my $uname = $self->get_unique_source_name($hash_ref);
  return unless $uname;
  $hash_ref =~ s/name=(\w)+ /name=$uname /;

  my $DAS = EnsEMBL::Web::DASConfig->new;
  $DAS->create_from_URL( $hash_ref );
## We have a duplicate so need to do something clever!
  if( exists $Das_sources_of{ ident $self }{$DAS->get_key} ) {
    if( $Das_sources_of{ ident $self }{$DAS->get_key}->unique_string ne $DAS->unique_string ) {
## If not same URL touch the "key"
      $DAS->touch_key;
    }
    $DAS->touch_key; ## Lets try again to see if there is duplicate!!
    $DAS->mark_altered;
  }
## Attach the DAS source..
  $Das_sources_of{ ident $self }{ $DAS->get_key } = $DAS;
  $self->update_configs_for_das( $DAS, qw(contigview geneview cytoview protview) );
}

sub add_das_source_from_hashref {
### DAS
### Create a new DAS source from a hash_ref
  my( $self, $hash_ref ) = @_;
  my $DAS = EnsEMBL::Web::DASConfig->new;
  $DAS->create_from_hash_ref( $hash_ref );
## We have a duplicate so need to do something clever!
  if( exists $Das_sources_of{ ident $self }{$DAS->get_key} ) {
## If not same URL touch the "key"
    if( $Das_sources_of{ ident $self }{$DAS->get_key}->unique_string ne $DAS->unique_string ) {
      $DAS->touch_key;
    }
    $DAS->mark_altered;
  }
## Attach the DAS source..
  $Das_sources_of{ ident $self }{ $DAS->get_key } = $DAS;
  $self->update_configs_for_das( $DAS, qw(contigview geneview cytoview protview) );
}
 
sub update_configs_for_das {
  my( $self, $DAS, @configs ) = @_;
  my %map = qw(
    enable    enable
    mapping   mapping
    group     group
    strand    str
    labelflag lflag
    depth     dep
    color     col
    stylesheet stylesheet
  );
  my $N = $DAS->get_name;
  my %scripts  = map {($_=>1)} @{$DAS->get_data->{'enable'}||[]};
  foreach my $sc_name (@configs) {
    my $sc = $self->getScriptConfig( $sc_name, 1 );
    foreach my $ic_name ( keys %{$sc->{'_user_config_names'}} ) {
      next  unless $sc->{'_user_config_names'}{$ic_name} eq 'das';
      $self->attachImageConfig( $sc_name, $ic_name );
      my $T = $self->getImageConfig( $ic_name, $ic_name );
      if( $scripts{ $sc_name } ) {
        $T->set( "managed_extdas_$N", 'on' ,      'on' , 1);
        $T->set( "managed_extdas_$N", 'manager' , 'das', 1);
        foreach my $K (keys %map) {
          $T->set( "managed_extdas_$N", $map{$K}, $DAS->get_data->{$K}, 1 );
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
sub remove_das_source {
### DAS
### Remove a DAS source from the configuration 
  my( $self, $key ) = @_;
  if( exists $Das_sources_of{ ident $self }{ $key } ) {
    $Das_sources_of{ ident $self }{ $key }->delete;
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
  my $do_not_pop_from_params = shift;

  unless ($Configs_of{ ident $self }{$script}) {
    my $script_config = EnsEMBL::Web::ScriptConfig->new( $script, $self );

    foreach my $root ( @{$self->get_path} ) {
      my $classname = $root."::ScriptConfig::$script";
      unless( $self->dynamic_use( $classname ) ) {
## If the module can't be required throw an error and return undef;
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

    my $image_config_data = {};
    if( $self->get_session_id && $script_config->storable ) {
      ## Let us see if there is an entry in the database and load it into the script config!
      ## and store any other data which comes back....
      my $config = EnsEMBL::Web::Data::Session->get_config(
        session_id => $self->get_session_id,
        type       => 'script',
        code       => $script,
      );

      if ($config) {
        my $TEMP = $config->data;
        $TEMP =~ s/\n|\r|\f|\\//g;
        $TEMP = eval($TEMP);
        if ($TEMP) {
          $script_config->set_user_settings( $TEMP->{'diffs'} );
          $image_config_data = $TEMP->{'image_configs'};
        } else {
          warn "ERROR: $@" if $@;
        }
      }
    }
    unless( $do_not_pop_from_params ) {
      $script_config->update_from_input( $self->input ); ## Needs access to the CGI.pm object...
    }

    $Configs_of{ ident $self }{$script} = {
      'config'            => $script_config,       ## List of attached
      'image_configs'     => {},                   ## List of attached image configs
      'image_config_data' => $image_config_data    ## Data retrieved from database to define image config settings.
    };
  }
  return $Configs_of{ ident  $self }{$script}{'config'};
}

sub get_script_config_as_string {
  my ($self, $script) = @_;

  if( $self->get_session_id ) {
    my $config = EnsEMBL::Web::Data::Session->get_config(
      session_id => $self->get_session_id,
      type       => 'script',
      code       => $script,
    );
    return $config->data if $config;
  }
  
  return undef; 
}

sub set_script_config_from_string {
  my ($self, $script, $string) = @_;
  EnsEMBL::Web::Data::Session->set_config(
    session_id => $self->get_session_id,
    type       => 'script',
    code       => $script,
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
  my $user_config = $self->getUserConfig( $type ); # $ImageConfigs_of{ ident $self }{ $type };
  foreach my $script ( keys %{$Configs_of{ ident $self }||{}} ) {
    if( $Configs_of{ ident $self }{$script}{'image_config_data'}{$type} ) {
      $user_config->{'user'} = $self->deepcopy( $Configs_of{ ident $self }{$script}{'image_config_data'}{$type} );
    }
  }
## Store if $key is set!
  $ImageConfigs_of{ ident $self }{ $key } = $user_config if $key;
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

