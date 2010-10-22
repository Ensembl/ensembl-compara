package EnsEMBL::Web::Hub;

### NAME: EnsEMBL::Web::Hub 
### A centralised object giving access to data connections and the web environment 

### DESCRIPTION:
### Hub uses the Flyweight design pattern to create a single object that is 
### passed around between all other objects that require data connectivity.
### The Hub stores information about the current web page and its environment, 
### including cgi parameters, settings parsed from the URL, browser session, 
### database connections, and so on.

use strict;

use Carp;
use CGI;
use CGI::Cookie;
use URI::Escape qw(uri_escape uri_unescape);

use Bio::EnsEMBL::ColourMap;

use EnsEMBL::Web::Cache;
use EnsEMBL::Web::DBSQL::DBConnection;
use EnsEMBL::Web::ExtIndex;
use EnsEMBL::Web::ExtURL;
use EnsEMBL::Web::Problem;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Session;
use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::Text::FeatureParser;
use EnsEMBL::Web::TmpFile::Text;
use EnsEMBL::Web::ViewConfig;

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $args) = @_;

  my $type         = $args->{'type'}         || $ENV{'ENSEMBL_TYPE'}; # Parsed from URL: Gene, UserData, etc
  my $species      = $args->{'species'}      || $ENV{'ENSEMBL_SPECIES'};
  my $input        = $args->{'input'}        || new CGI;
  my $species_defs = $args->{'species_defs'} || new EnsEMBL::Web::SpeciesDefs;
  my $factorytype  = $ENV{'ENSEMBL_FACTORY'}  || ($input && $input->param('factorytype') ? $input->param('factorytype') : $type);
  my $cookies      = $args->{'apache_handle'} ? CGI::Cookie->parse($args->{'apache_handle'}->headers_in->{'Cookie'}) : {};
  
  $species_defs->{'timer'} = $args->{'timer'};
  
  my $self = {
    _input         => $input,
    _species       => $species,    
    _species_defs  => $species_defs, 
    _factorytype   => $factorytype,
    _type          => $type,
    _action        => $args->{'action'}        || $ENV{'ENSEMBL_ACTION'},   # View, Summary etc
    _function      => $args->{'function'}      || $ENV{'ENSEMBL_FUNCTION'}, # Extra path info
    _script        => $args->{'script'}        || $ENV{'ENSEMBL_SCRIPT'},   # Page, Component, Config etc
    _cache         => $args->{'cache'}         || new EnsEMBL::Web::Cache(enable_compress => 1, compress_threshold => 10000),
    _ext_url       => $args->{'ext_url'}       || new EnsEMBL::Web::ExtURL($species, $species_defs),
    _problem       => $args->{'problem'}       || {},    
    _view_configs  => $args->{'view_configs_'} || {},
    _user_details  => $args->{'user_details'}  || 1,
    _object_types  => $args->{'object_types'}  || {},
    _apache_handle => $args->{'apache_handle'} || undef,
    _user          => $args->{'user'}          || undef,
    _timer         => $args->{'timer'}         || undef,
    _databases     => $species ne 'common'      ?  new EnsEMBL::Web::DBSQL::DBConnection($species, $species_defs) : undef,
    _cookies       => $cookies,
    _core_objects  => {},
    _core_params   => {},
  };

  bless $self, $class;
  
  $self->session = new EnsEMBL::Web::Session($self, $args->{'session_cookie'});
  
  if ($ENSEMBL_WEB_REGISTRY) {
    $self->user  ||= $ENSEMBL_WEB_REGISTRY->user;
    $self->timer ||= $ENSEMBL_WEB_REGISTRY->timer;
  }
  
  $self->set_core_params;
  
  return $self;
}

# Accessor functionality
sub species     :lvalue { $_[0]{'_species'};     }
sub script      :lvalue { $_[0]{'_script'};      }
sub type        :lvalue { $_[0]{'_type'};        }
sub action      :lvalue { $_[0]{'_action'};      }
sub function    :lvalue { $_[0]{'_function'};    }
sub factorytype :lvalue { $_[0]{'_factorytype'}; }
sub session     :lvalue { $_[0]{'_session'};     }
sub cache       :lvalue { $_[0]{'_cache'};       }
sub user        :lvalue { $_[0]{'_user'};        }
sub timer       :lvalue { $_[0]{'_timer'};       }

sub input         { return $_[0]{'_input'};         }
sub cookies       { return $_[0]{'_cookies'};       }
sub databases     { return $_[0]{'_databases'};     }
sub object_types  { return $_[0]{'_object_types'};  }
sub core_params   { return $_[0]{'_core_params'};   }
sub apache_handle { return $_[0]{'_apache_handle'}; }
sub ExtURL        { return $_[0]{'_ext_url'};       }
sub user_details  { return $_[0]{'_user_details'};  }
sub species_defs  { return $_[0]{'_species_defs'};  }

sub timer_push        { return ref $_[0]->timer eq 'EnsEMBL::Web::Timer' ? shift->timer->push(@_) : undef; }
sub check_ajax        { return $_[0]{'check_ajax'} ||= $_[0]->get_cookies('ENSEMBL_AJAX') eq 'enabled';    }
sub referer           { return $_[0]{'referer'}    ||= $_[0]->_parse_referer;                              }
sub colourmap         { return $_[0]{'colourmap'}  ||= new Bio::EnsEMBL::ColourMap($_[0]->species_defs);   }
sub viewconfig        { return $_[0]{'viewconfig'} ||= $_[0]->get_viewconfig;                              } # Store default viewconfig so we don't have to keep getting it from session

sub species_path      { return shift->species_defs->species_path(@_);       }
sub table_info        { return shift->species_defs->table_info(@_);         }
sub get_databases     { return shift->databases->get_databases(@_);         }
sub databases_species { return shift->databases->get_databases_species(@_); }
sub delete_param      { shift->input->delete(@_); }

sub has_a_problem      { return scalar keys %{$_[0]{'_problem'}}; }
sub has_fatal_problem  { return scalar @{$_[0]{'_problem'}{'fatal'}||[]}; }
sub has_problem_type   { return scalar @{$_[0]{'_problem'}{$_[1]}||[]}; }
sub get_problem_type   { return @{$_[0]{'_problem'}{$_[1]}||[]}; }
sub clear_problem_type { $_[0]{'_problem'}{$_[1]} = []; }
sub clear_problems     { $_[0]{'_problem'} = {}; }

# Returns the values of cookies
# If only one cookie name is given, returns the value as a scalar
# If more than one cookie name is given, returns a hash of name => value
sub get_cookies {
  my $self     = shift;
  my %cookies  = %{$self->cookies};
  %cookies     = map { exists $cookies{$_} ? ($_ => $cookies{$_}) : () } @_ if @_;
  $cookies{$_} = $cookies{$_}->value for grep exists $cookies{$_}, @_;
  return scalar keys %cookies > 1 ? \%cookies : [ values %cookies ]->[0];
}

sub problem {
  my $self = shift;
  push @{$self->{'_problem'}{$_[0]}}, new EnsEMBL::Web::Problem(@_) if @_;
  return $self->{'_problem'};
}

sub get_adaptor {
  my ($self, $method, $db, $species) = @_;
  
  $db      ||= 'core';
  $species ||= $self->species;
  
  my $adaptor;
  eval { $adaptor = $self->database($db, $species)->$method(); };

  if ($@) {
    warn $@;
    $self->problem('fatal', "Sorry, can't retrieve required information.", $@);
  }
  
  return $adaptor;
}

sub database {
  my $self = shift;

  if ($_[0] =~ /compara/) {
    return Bio::EnsEMBL::Registry->get_DBAdaptor('multi', $_[0]);
  } else {
    return $self->databases->get_DBAdaptor(@_);
  }
}

sub core_objects {
  my $self = shift;
  my $core_objects = shift;
  $self->{'_core_objects'}->{lc $_}        = $core_objects->{$_} for keys %{$core_objects || {}};
  $self->{'_core_objects'}->{'parameters'} = $self->core_params if $core_objects;
  $self->{'_core_objects'}->{'parameters'}->{'db'} ||= 'core';
  return $self->{'_core_objects'};
}

sub core_param { 
  my $self = shift;
  my $name = shift;
  return unless $name;
  $self->{'_core_params'}->{$name} = @_ if @_;
  return $self->{'_core_params'}->{$name};
}

sub set_core_params {
  ### Initialises core parameter hash from CGI parameters

  my $self = shift;
  my $core_params = {};

  foreach (@{$self->species_defs->core_params}) {
    my @param = $self->param($_, 'no_cache');
    $core_params->{$_} = scalar @param == 1 ? $param[0] : \@param if scalar @param;
  }

  $self->{'_core_params'} = $core_params;
}

# Determines the species for userdata pages (mandatory, since userdata databases are species-specific)
sub data_species {
  my $self    = shift;
  my $species = $self->species;
  $species    = $self->species_defs->ENSEMBL_PRIMARY_SPECIES if !$species || $species eq 'common';
  return $species;
}

# Does an ordinary redirect
sub redirect {
  my ($self, $url) = @_;
  $self->input->redirect($url);
}

sub url {
  my $self   = shift;
  my $extra  = $_[0] && !ref $_[0] ? shift : undef;
  my $params = shift || {};
  my ($flag, $all_params) = @_;

  Carp::croak("Not a hashref while calling _url ($params @_)") unless ref $params eq 'HASH';

  my $species = exists $params->{'species'}  ? $params->{'species'}  : $self->species;
  my $type    = exists $params->{'type'}     ? $params->{'type'}     : $self->type;
  my $action  = exists $params->{'action'}   ? $params->{'action'}   : $self->action;
  my $fn      = exists $params->{'function'} ? $params->{'function'} : $action eq $self->action ? $self->function : undef;
  my %pars;
  
  if ($all_params) {
    %pars = map { /^time=/ ? () : split /=/ } split /;|&/, uri_unescape($self->input->query_string);
  } else {
    %pars = %{$self->core_params};

    # Remove any unused params
    foreach (keys %pars) {
      delete $pars{$_} unless $pars{$_};
    }
    
    if ($params->{'__clear'}) {
      %pars = ();
      delete $params->{'__clear'};
    }

    delete $pars{'t'}  if $params->{'pt'};
    delete $pars{'pt'} if $params->{'t'};
    delete $pars{'t'}  if $params->{'g'} && $params->{'g'} ne $pars{'g'};
    delete $pars{'time'};

    foreach (keys %$params) {
      next if $_ =~ /^(species|type|action|function)$/;

      if (defined $params->{$_}) {
        $pars{$_} = $params->{$_};
      } else {
        delete $pars{$_};
      }
    }
  }

  my $url = join '/', map $_ || (), $self->species_defs->species_path($species), $extra, $type, $action, $fn;
  
  return [ $url, \%pars ] if $flag;

  $url .= '?' if scalar keys %pars;

  # Sort the keys so that the url is the same for a given set of parameters
  foreach my $p (sort keys %pars) {
    next unless defined $pars{$p};

    # Don't escape :
    $url .= sprintf '%s=%s;', uri_escape($p), uri_escape($_, "^A-Za-z0-9\-_.!~*'():\/") for ref $pars{$p} ? @{$pars{$p}} : $pars{$p};

  }

  $url =~ s/;$//;

  return $url;
}

sub param {
  my $self     = shift;
  my $no_cache = scalar @_ > 1 && $_[-1] eq 'no_cache';
  pop @_ if $no_cache;
  
  if (@_) {
    my @T = map _sanitize($_), $self->input->param(@_);
    return wantarray ? @T : $T[0] if @T;
    my $view_config = $no_cache ? $self->get_viewconfig : $self->viewconfig;
    
    if ($view_config) {
      $view_config->set(@_) if @_ > 1;
      my @val = $view_config->get(@_);
      return wantarray ? @val : $val[0];
    }
    
    return wantarray ? () : undef;
  } else {
    my @params = map _sanitize($_), $self->input->param;
    my $view_config = $no_cache ? $self->get_viewconfig : $self->viewconfig;
    push @params, $view_config->options if $view_config;
    my %params = map { $_, 1 } @params; # Remove duplicates
    
    return keys %params;
  }
}

sub input_param  {
  my $self = shift;
  return _sanitize($self->param(@_));
}

sub multi_params {
  my $self = shift;
  my $realign = shift;

  my $input = $self->input;

  my %params = defined $realign ?
    map { $_ => $input->param($_) } grep { $realign ? /^([srg]\d*|pop\d+|align)$/ && !/^[rg]$realign$/ : /^(s\d+|r|pop\d+|align)$/ && $input->param($_) } $input->param :
    map { $_ => $input->param($_) } grep { /^([srg]\d*|pop\d+|align)$/ && $input->param($_) } $input->param;

  return \%params;
}

sub _sanitize {
  my $T = shift;
  $T =~ s/<script(.*?)>/[script$1]/igsm;
  $T =~ s/\s+on(\w+)\s*=/ on_$1=/igsm;
  return $T;
} 

sub get_ExtURL {
  my $self = shift;
  my $new_url = $self->ExtURL || return;
  return $new_url->get_url(@_);
}

sub get_ExtURL_link {
  my $self = shift;
  my $text = shift;
  my $url = $self->get_ExtURL(@_);
  return $url ? qq(<a href="$url" rel="external">$text</a>) : $text;
}

# use PFETCH etc to get description and sequence of an external record
sub get_ext_seq {
  my ($self, $id, $ext_db) = @_;
  my $indexer = new EnsEMBL::Web::ExtIndex($self->species_defs);
  
  return unless $indexer;
  
  my $seq_ary;
  my %args;
  $args{'ID'} = $id;
  $args{'DB'} = $ext_db ? $ext_db : 'DEFAULT';

  eval { $seq_ary = $indexer->get_seq_by_id(\%args); };
  
  if (!$seq_ary) {
    warn "The $ext_db server is unavailable: $@";
    return '';
  } else {
    my ($list, $l);
    
    foreach (@$seq_ary) {
      if (!/^>/) {
        $l += length;
        $l-- if /\n/; # don't count carriage returns
      }
      
      $list .= $_;
    }
    
    return $list =~ /no match/i ? [] : [ $list, $l ];
  }
}

# This method gets all configured DAS sources for the current species.
# Source configurations are retrieved first from SpeciesDefs, then additions and
# modifications are added from the User and Session.
# Returns a hashref, indexed by logic_name.
sub get_all_das {
  my $self     = shift;
  my $species  = shift || $self->species;
  $species     = '' if $species eq 'common';
  my @spec_das = $self->species_defs->get_all_das($species);
  my @sess_das = $self->session->get_all_das($species);
  my @user_das = $self->user ? $self->user->get_all_das($species) : ({}, {});

  # TODO: group data??

  # First hash is keyed by logic_name, second is keyed by full_url
  my %by_name = ( %{$spec_das[0]},       %{$user_das[0]},       %{$sess_das[0]}       );
  my %by_url  = ( %{$spec_das[1] || {}}, %{$user_das[1] || {}}, %{$sess_das[1] || {}} );
  
  return wantarray ? (\%by_name, \%by_url) : \%by_name;
}

# This method gets a single named DAS source for the current species.
# The source's configuration is an amalgam of species, user and session data.
sub get_das_by_logic_name {
  my ($self, $name) = @_;
  return $self->get_all_das->{$name};
}

# VIEW / IMAGE CONFIGS

sub get_viewconfig {
  ### Create a new EnsEMBL::Web::ViewConfig object for the type and action passed
  
  my $self    = shift;
  my $type    = shift || $self->type;
  my $action  = shift || $self->action;
  my $session = $self->session;
  my $key     = "${type}::$action";
  
  return undef unless $session;
  return $session->view_configs->{$key}{'config'} if $session->view_configs->{$key};
  
  my $view_config = new EnsEMBL::Web::ViewConfig($type, $action, $self);
  
  $session->apply_to_view_config($view_config, $type, $key);
  
  return $view_config;
}

sub get_imageconfig {
  ### Returns an EnsEMBL::Web::ImageConfig object
  ### If passed one parameter then it loads the data (and doesn't cache it)
  ### If passed two parameters it loads the data (and caches it against the second name - NOTE you must use the
  ### second name version IF you want the configuration to be saved by the session - otherwise it will be lost
  
  my $self    = shift;
  my $type    = shift;
  my $key     = shift;
  my $species = shift;
  my $session = $self->session;
  
  return undef if $type eq '_page' || $type eq 'cell_page';
  return undef unless $session;
  return $session->image_configs->{$key} if $key && $session->image_configs->{$key};
  
  my $module_name  = "EnsEMBL::Web::ImageConfig::$type";
  my $image_config = $self->dynamic_use($module_name) ? $module_name->new($self, $species) : undef;
  
  if ($image_config) {
    $session->apply_to_image_config($image_config, $type, $key);
    
    return $image_config;
  } else {
    $self->dynamic_use_failure($module_name);
  }
}

sub get_tracks {
  my ($self, $key) = @_;
  my $data   = $self->fetch_userdata_by_id($key);
  my $tracks = {};
 
  if (my $parser = $data->{'parser'}) {
    while (my ($type, $track) = each (%{$parser->get_all_tracks})) {
      my @rows;
      
      foreach my $feature (@{$track->{'features'}}) {
        my $data_row = {
          chr     => $feature->seqname || $feature->slice->name,
          start   => $feature->rawstart,
          end     => $feature->rawend,
          label   => $feature->id,
          gene_id => $feature->id,
        };
        
        push @rows, $data_row;
      }
      
      $track->{'config'}{'name'} = $data->{'name'};
      $tracks->{$type} = { features => \@rows, config => $track->{'config'} };
    }
  } else {
    while (my ($analysis, $track) = each(%{$data})) {
      my @rows;
     
      foreach my $f (
        map  { $_->[0] }
        sort { $a->[1] <=> $b->[1] || $a->[2] cmp $b->[2] || $a->[3] <=> $b->[3] }
        map  {[ $_, $_->{'slice'}->seq_region_name, $_->{'start'}, $_->{'end'} ]}
        @{$track->{'features'}}
      ) {
        my $data_row = {
          chr     => $f->{'slice'}->seq_region_name,
          start   => $f->{'start'},
          end     => $f->{'end'},
          length  => $f->{'length'},
          label   => $f->{'start'}.'-'.$f->{'end'},
          gene_id => $f->{'gene_id'},
        };
        
        push @rows, $data_row;
      }
      
      $tracks->{$analysis} = {'features' => \@rows, 'config' => $track->{'config'}};
    }
  }

  return $tracks;
}

sub fetch_userdata_by_id {
  my ($self, $record_id) = @_;
  return unless $record_id;

  my $data = {};
  my ($status, $type, $id) = split '-', $record_id;

  if ($type eq 'url' || ($type eq 'upload' && $status eq 'temp')) {
    $data = $self->get_data_from_session($status, $type, $id);
  } 
  else {
    my $user = $self->user;
    my ($type, $user_id, $track_id) = split '_', $record_id;
    return unless $user && $user->id == $user_id;
    
    my $fa        = $self->database('userdata', $self->species)->get_DnaAlignFeatureAdaptor;
    my $aa        = $self->database('userdata', $self->species)->get_AnalysisAdaptor;
    my $features  = $fa->fetch_all_by_logic_name($record_id);
    my $analysis  = $aa->fetch_by_logic_name($record_id);
    my $config    = $analysis->web_data;
    $config->{'track_name'} = $analysis->description || $record_id;
    $config->{'track_label'} = $analysis->display_label || $analysis->description || $record_id;
    $data->{$record_id} = { features => $features, config => $config };
  }
  
  return $data;
}

sub get_data_from_session {
  my ($self, $status, $type, $id) = @_;
  my ($content, $format, $name);
  my $tempdata = {};

  if ($status eq 'temp') {
    $tempdata = $self->session->get_data('type' => $type, 'code' => $id);
    $name     = $tempdata->{'name'};
  } else {
    my $user   = $self->user;
    my $record = $user->urls($id);
    $tempdata  = { url => $record->url };
    $name      = $record->url;
  }

  # NB this used to be new EnsEMBL::Web... etc but this does not work with the
  # FeatureParser module for some reason, so have to use FeatureParser->new()
  my $parser = EnsEMBL::Web::Text::FeatureParser->new($self->species_defs);

  if ($type eq 'url') {
    my $response = get_url_content($tempdata->{'url'});
    $content     = $response->{'content'};
  } else {
    my $file = new EnsEMBL::Web::TmpFile::Text(filename => $tempdata->{'filename'});
    $content = $file->retrieve;
    
    return {} unless $content;
  }
   
  $parser->parse($content, $tempdata->{'format'});

  return { 'parser' => $parser, 'name' => $name };
}

1;
