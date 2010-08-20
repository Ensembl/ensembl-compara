package EnsEMBL::Web::Hub;

### NAME: EnsEMBL::Web::Hub 
### A centralised object giving access to data connections and the web environment 

### STATUS: Under development
### Currently being developed, along with its associated moduled E::W::Resource,
### as a replacement for Proxy/Proxiable code

### DESCRIPTION:
### Hub is intended as a replacement for both the non-object-specific
### portions of Proxiable and the global variable ENSEMBL_WEB_REGISTRY
### It uses the Flyweight design pattern to create a single object that is 
### passed around between all other objects that require data connectivity.
### The Hub stores information about the current web page and its environment, 
### including cgi parameters, settings parsed from the URL, browser session, 
### database connections, and so on.

use strict;

use Carp;
use CGI;
use CGI::Cookie;
use URI::Escape qw(uri_escape);

use EnsEMBL::Web::Cache;
use EnsEMBL::Web::DBSQL::DBConnection;
use EnsEMBL::Web::Problem;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::ExtIndex;
use EnsEMBL::Web::ExtURL;

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, %args) = @_;

  my $type = $args{'_type'} || $ENV{'ENSEMBL_TYPE'}; # Parsed from URL:  Gene, UserData, etc

  ## Normally CGI is created in Model, however static pages have no access to the module
  ## but still ought to be able to create a valid Hub
  my $input = $args{'_input'} || new CGI;

  ## The following may seem a little clumsy, but it allows the Hub to be created
  ## by a command-line script with no access to CGI parameters
  my $factorytype = $ENV{'ENSEMBL_FACTORY'} || ($input && $input->param('factorytype') ? $input->param('factorytype') : $type);
  
  my ($session, $user, $timer);
  
  if ($ENSEMBL_WEB_REGISTRY) {
    $session = $ENSEMBL_WEB_REGISTRY->get_session;
    $user    = $args{'_user'}  || $ENSEMBL_WEB_REGISTRY->get_user;
    $timer   = $args{'_timer'} || $ENSEMBL_WEB_REGISTRY->timer;
  }

  my $self = {
    _apache_handle => $args{'_apache_handle'} || undef,
    _input         => $args{'_input'}         || $input,
    _species       => $args{'_species'}       || $ENV{'ENSEMBL_SPECIES'},    
    _type          => $type,
    _action        => $args{'_action'}        || $ENV{'ENSEMBL_ACTION'},       # View, Summary etc
    _function      => $args{'_function'}      || $ENV{'ENSEMBL_FUNCTION'},     # Extra path info
    _script        => $args{'_script'}        || $ENV{'ENSEMBL_SCRIPT'},       # name of script in this case action
    _factorytype   => $factorytype,
    _species_defs  => $args{'_species_defs'}  || new EnsEMBL::Web::SpeciesDefs, 
    _cache         => $args{'_cache'}         || new EnsEMBL::Web::Cache(enable_compress => 1, compress_threshold => 10000),
    _problem       => $args{'_problem'}       || {},    
    _view_configs  => $args{'_view_configs_'} || {},
    _user_details  => $args{'_user_details'}  || 1,
    _object_types  => $args{'_object_types'}  || {},
    _core_objects  => {},
    _core_params   => {},
    _session       => $session,
    _user          => $user,                    
    _timer         => $timer, 
  };

  bless $self, $class;
  
  $self->{'_cookies'} = $args{'_apache_handle'} ? CGI::Cookie->parse($args{'_apache_handle'}->headers_in->{'Cookie'}) : {};
  
  ## Get database connections 
  my $api_connection = $self->species ne 'common' ? new EnsEMBL::Web::DBSQL::DBConnection($self->species, $self->species_defs) : undef;
  $self->{'_databases'} = $api_connection;
  
  $self->_set_core_params;

  $self->{'_ext_url'} = $args{'_ext_url'} || new EnsEMBL::Web::ExtURL($self->species, $self->species_defs); 
  $self->species_defs->{'timer'} = $args{'_timer'};
  
  $self->{'_parent'} = $self->_parse_referer;
  
  return $self;
}

# Accessor functionality
sub species     :lvalue { $_[0]{'_species'};     }
sub script      :lvalue { $_[0]{'_script'};      }
sub type        :lvalue { $_[0]{'_type'};        }
sub action      :lvalue { $_[0]{'_action'};      }
sub function    :lvalue { $_[0]{'_function'};    }
sub factorytype :lvalue { $_[0]{'_factorytype'}; }
sub parent      :lvalue { $_[0]{'_parent'};      }
sub session     :lvalue { $_[0]{'_session'};     }
sub databases   :lvalue { $_[0]{'_databases'};   } 
sub cache       :lvalue { $_[0]{'_cache'};       }
sub user        :lvalue { $_[0]{'_user'};        }

sub input         { return $_[0]{'_input'};         }
sub cookies       { return $_[0]{'_cookies'};       }
sub object_types  { return $_[0]{'_object_types'};  }
sub core_params   { return $_[0]{'_core_params'};   }
sub apache_handle { return $_[0]{'_apache_handle'}; }
sub ExtURL        { return $_[0]{'_ext_url'};       }
sub timer         { return $_[0]{'_timer'};         }
sub user_details  { return $_[0]{'_user_details'};  }
sub species_defs  { return $_[0]{'_species_defs'};  }
sub species_path  { return shift->species_defs->species_path(@_); }
sub timer_push    { return ref $_[0]->timer eq 'EnsEMBL::Web::Timer' ? $_[0]->timer->push(@_) : undef; }

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

sub database {
  my $self = shift;

  if ($_[0] =~ /compara/) {
    return Bio::EnsEMBL::Registry->get_DBAdaptor('multi', $_[0]);
  } else {
    return $self->{'_databases'}->get_DBAdaptor(@_);
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

sub _set_core_params {
  ### Initialises core parameter hash from CGI parameters

  my $self = shift;
  my $core_params = {};

  foreach (@{$self->species_defs->core_params}) {
    my @param = $self->param($_);
    $core_params->{$_} = scalar @param == 1 ? $param[0] : \@param if scalar @param;
  }

  $self->{'_core_params'} = $core_params;
}

# Does an ordinary redirect
sub redirect {
  my ($self, $url) = @_;
  $self->input->redirect($url);
}

sub url {
  my $self   = shift;
  my $params = shift || {};

  Carp::croak("Not a hashref while calling _url ($params @_)") unless ref $params eq 'HASH';

  my $species = exists $params->{'species'}  ? $params->{'species'}  : $self->species;
  my $type    = exists $params->{'type'}     ? $params->{'type'}     : $self->type;
  my $action  = exists $params->{'action'}   ? $params->{'action'}   : $self->action;
  my $fn      = exists $params->{'function'} ? $params->{'function'} : $action eq $self->action ? $self->function : undef;
  my %pars    = %{$self->core_params};

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

  my $url  = join '/', map $_ || (), $self->species_defs->species_path($species), $type, $action, $fn;
  my $flag = shift;

  return [ $url, \%pars ] if $flag;

  $url .= '?' if scalar keys %pars;

  # Sort the keys so that the url is the same for a given set of parameters
  foreach my $p (sort keys %pars) {
    next unless defined $pars{$p};

    # Don't escape :
    $url .= sprintf '%s=%s;', uri_escape($p), uri_escape($_, "^A-Za-z0-9\-_.!~*'():") for ref $pars{$p} ? @{$pars{$p}} : $pars{$p};
  }

  $url =~ s/;$//;

  return $url;
}

sub param {
  my $self = shift;
  
  return unless $self->input;

  if (@_) {
    my @T = map _sanitize($_), $self->input->param(@_);
    return wantarray ? @T : $T[0] if @T;
    return wantarray ? () : undef;
  } else {
    my @params = map _sanitize($_), $self->input->param;
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
  return $url ? qq(<a href="$url">$text</a>) : $text;
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
    my $list = join ' ', @$seq_ary;
    return $list =~ /no match/i ? '' : $list;
  }
}

### VIEW / IMAGE CONFIGS

# Returns the named (or one based on script) {{EnsEMBL::Web::ViewConfig}} object
sub get_viewconfig {
  my ($self, $type, $action) = @_;
  my $session = $self->session;
  
  return undef unless $session;
  
  return $session->getViewConfig($type || $self->type, $action || $self->action);
}

# Returns the named (or one based on script) {{EnsEMBL::Web::ImageConfig}} object
sub get_imageconfig {
  my $self    = shift;
  my $type    = shift;
  my $session = $self->session;
  
  return undef unless $session;
  
  $_[0] ||= $type if scalar @_;
  
  my $image_config = $session->getImageConfig($type, @_);
  
  return unless $image_config;
  
  $image_config->_set_core($self->core_objects);
  
  return $image_config;
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
          chr     => $feature->seqname,
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
        map  {[ $_, $_->{'region'} =~ /^(\d+)/ ? $1 : 1e20 , $_->{'region'}, $_->{'start'} ]}
        @{$track->{'features'}}
      ) {
        my $data_row = {
          chr     => $f->{'region'},
          start   => $f->{'start'},
          end     => $f->{'end'},
          length  => $f->{'length'},
          label   => $f->{'label'},
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
  } else {
    my $user = $self->user;
    
    return unless $user;
    
    my $fa      = $self->database('userdata', $self->species)->get_DnaAlignFeatureAdaptor;
    my @records = $user->uploads($record_id);
    my $record  = $records[0];

    if ($record) {
      my @analyses = ($record->analyses);

      foreach (@analyses) {
        next unless $_;
        $data->{$_} = { features => $fa->fetch_all_by_logic_name($_), config => { name => $_ } };
      }
    }
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
