=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
use URI::Escape qw(uri_escape uri_unescape);
use HTML::Entities qw(encode_entities);

use EnsEMBL::Draw::Utils::ColourMap;

use EnsEMBL::Web::Cache;
use EnsEMBL::Web::Cookie;
use EnsEMBL::Web::DBSQL::DBConnection;
use EnsEMBL::Web::DBSQL::ConfigAdaptor;
use EnsEMBL::Web::Exceptions;
use EnsEMBL::Web::ExtURL;
use EnsEMBL::Web::Problem;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Session;
use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::Text::FeatureParser;
use EnsEMBL::Web::File::User;
use EnsEMBL::Web::ViewConfig;
use EnsEMBL::Web::Tools::Misc qw(get_url_content);

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $args) = @_;

  my $type         = $args->{'type'}         || $ENV{'ENSEMBL_TYPE'}; # Parsed from URL: Gene, UserData, etc
  my $species      = $args->{'species'}      || $ENV{'ENSEMBL_SPECIES'};
  my $input        = $args->{'input'}        || CGI->new;
  my $species_defs = $args->{'species_defs'} || EnsEMBL::Web::SpeciesDefs->new;
  my $factorytype  = $ENV{'ENSEMBL_FACTORY'} || ($input && $input->param('factorytype') ? $input->param('factorytype') : $type);
  my $cookies      = $args->{'apache_handle'} ? EnsEMBL::Web::Cookie->fetch($args->{'apache_handle'}) : {};

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
    _cache         => $args->{'cache'}         || EnsEMBL::Web::Cache->new(enable_compress => 1, compress_threshold => 10000),
    _ext_url       => $args->{'ext_url'}       || EnsEMBL::Web::ExtURL->new($species, $species_defs),
    _problem       => $args->{'problem'}       || {},
    _user_details  => $args->{'user_details'}  || 1,
    _object_types  => $args->{'object_types'}  || {},
    _apache_handle => $args->{'apache_handle'} || undef,
    _user          => $args->{'user'}          || undef,
    _timer         => $args->{'timer'}         || undef,
    _databases     => EnsEMBL::Web::DBSQL::DBConnection->new($species, $species_defs),
    _cookies       => $cookies,
    _ext_indexers  => {},
    _builder       => undef,
    _core_params   => {},
    _core_params   => {},
    _species_info  => {},
    _components    => [],
    _req_cache     => {},
  };

  bless $self, $class;
  
  $self->session = EnsEMBL::Web::Session->new($self, $args->{'session_cookie'});
  $self->timer ||= $ENSEMBL_WEB_REGISTRY->timer if $ENSEMBL_WEB_REGISTRY;
  
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
sub components  :lvalue { $_[0]{'_components'};  }
sub viewconfig  :lvalue { $_[0]{'_viewconfig'};  } # Store viewconfig so we don't have to keep getting it from session

sub input          { return $_[0]{'_input'};          }
sub cookies        { return $_[0]{'_cookies'};        }
sub databases      { return $_[0]{'_databases'};      }
sub object_types   { return $_[0]{'_object_types'};   }
sub core_params    { return $_[0]{'_core_params'};    }
sub apache_handle  { return $_[0]{'_apache_handle'};  }
sub ExtURL         { return $_[0]{'_ext_url'};        }
sub user_details   { return $_[0]{'_user_details'};   }
sub species_defs   { return $_[0]{'_species_defs'};   }
sub config_adaptor { return $_[0]{'_config_adaptor'} ||= EnsEMBL::Web::DBSQL::ConfigAdaptor->new($_[0]); }

sub timer_push        { return ref $_[0]->timer eq 'EnsEMBL::Web::Timer' ? shift->timer->push(@_) : undef;    }
sub referer           { return $_[0]{'referer'}   ||= $_[0]->parse_referer;                                  }
sub colourmap         { return $_[0]{'colourmap'} ||= EnsEMBL::Draw::Utils::ColourMap->new($_[0]->species_defs);      }
sub is_ajax_request   { return $_[0]{'is_ajax'}   //= $_[0]{'_apache_handle'}->headers_in->{'X-Requested-With'} eq 'XMLHttpRequest'; }

sub species_path      { return shift->species_defs->species_path(@_);       }
sub table_info        { return shift->species_defs->table_info(@_);         }
sub get_databases     { return shift->databases->get_databases(@_);         }
sub databases_species { return shift->databases->get_databases_species(@_); }
sub delete_param      { shift->input->delete(@_); }

sub users_available   { return 0; } # overridden in users plugin

sub has_a_problem      { return scalar keys %{$_[0]{'_problem'}}; }
sub has_fatal_problem  { return scalar @{$_[0]{'_problem'}{'fatal'}||[]}; }
sub has_problem_type   { return scalar @{$_[0]{'_problem'}{$_[1]}||[]}; }
sub get_problem_type   { return @{$_[0]{'_problem'}{$_[1]}||[]}; }
sub clear_problem_type { delete $_[0]{'_problem'}{$_[1]}; }
sub clear_problems     { $_[0]{'_problem'} = {}; }


## Cookie methods
sub get_cookie_value {
  my $self    = shift;
  my $cookie  = $self->get_cookie(@_);
  return $cookie ? $cookie->value : '';
}

sub get_cookie {
  my ($self, $name, $is_encrypted) = @_;
  my $cookies = $self->cookies;
  $cookies->{$name} = EnsEMBL::Web::Cookie->retrieve($self->apache_handle, {'name' => $name, 'encrypted' => $is_encrypted}) if $cookies->{$name} && $cookies->{$name}->encrypted eq !$is_encrypted;
  return $cookies->{$name};
}

sub set_cookie {
  my ($self, $name, $value, $is_encrypted) = @_;
  return $self->cookies->{$name} = EnsEMBL::Web::Cookie->bake($self->apache_handle, {'name' => $name, 'value' => $value, 'encrypted' => $is_encrypted});
}

sub clear_cookie {
  my ($self, $name) = @_;
  EnsEMBL::Web::Cookie->clear($self->apache_handle, {'name' => $name});
  return $self->cookies->{$name} = undef;
}

sub new_cookie {
  ## Creates a new EnsEMBL::Web::Cookie object
  ## @param Hashref as accepted by EnsEMBL::Web::Cookie->new
  ## @return EnsEMBL::Web::Cookie
  my ($self, $params) = @_;
  return EnsEMBL::Web::Cookie->new($self->apache_handle, $params);
}

sub problem {
  my $self = shift;
  push @{$self->{'_problem'}{$_[0]}}, EnsEMBL::Web::Problem->new(@_) if @_;
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
    return Bio::EnsEMBL::Registry->get_DBAdaptor('multi', $_[0], 1);
  } else {
    return $self->databases->get_DBAdaptor(@_);
  }
}

# Gets the database name used to create the object
sub get_db {
  my $self = shift;
  my $db = $self->param('db') || 'core';
  return $db eq 'est' ? 'otherfeatures' : $db;
}

sub set_builder {
  my ($self,$builder) = @_;

  $self->{'_builder'} = $builder;
  $self->{'_core_params'} = $self->core_params;
  $self->{'_core_params'}{'db'} ||= 'core';
}

sub core_object {
  my $self = shift;
  my $name = shift;

  if($name eq 'parameters') {
    return $self->{'_core_params'};
  }
  return $self->{'_builder'} ? $self->{'_builder'}->object(ucfirst $name) : undef;
}

sub core_param { 
  my $self = shift;
  my $name = shift;
  return unless $name;
  $self->{'_core_params'}->{$name} = shift if @_;
  return $self->{'_core_params'}->{$name};
}

sub set_core_params {
  ### Initialises core parameter hash from CGI parameters

  my $self = shift;
  my $core_params = { db => 'core' };

  foreach (@{$self->species_defs->core_params}) {
    my @param = $self->param($_);
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

# TODO: Needs moving to viewconfig so we don't have to work it out each time
sub otherspecies {
  my $self         = shift;

  return $self->param('otherspecies') if $self->param('otherspecies');
  return $self->param('species') if $self->param('species');

  my $species_defs = $self->species_defs;
  my $species      = $self->species;
  my $primary_sp   = $species_defs->ENSEMBL_PRIMARY_SPECIES;
  my $secondary_sp = $species_defs->ENSEMBL_SECONDARY_SPECIES;
  my %synteny      = $species_defs->multi('DATABASE_COMPARA', 'SYNTENY');

  return $primary_sp if  ($synteny{$species}->{$primary_sp} and $primary_sp ne $species);

  return $secondary_sp if  ($synteny{$species}->{$secondary_sp} and $secondary_sp ne $species);

  my @has_synteny  = grep { $_ ne $species } sort keys %{$synteny{$species}};
  return $has_synteny[0];
}

sub get_species_info {
  ## Gets info about all valid species or an individual species if url name provided
  ## @param URL name for a species (String) (optional)
  ## @return Hashref with keys: key, name, common, scientific and group for single species, OR hashref of hashrefs for { species url name => { species info } .. }
  my ($self, $species) = @_;

  unless ($self->{'_species_info_loaded'} || $species && $self->{'_species_info'}{$species}) {

    my $species_defs      = $self->species_defs;
    my @required_species  = $species_defs->valid_species;
       @required_species  = grep {$species eq $_} @required_species if $species;

    for (@required_species) {
      $self->{'_species_info'}{$_} = {
        'key'               => $_,
        'name'              => $species_defs->get_config($_, 'SPECIES_BIO_NAME'),
        'common'            => $species_defs->get_config($_, 'SPECIES_COMMON_NAME'),
        'scientific'        => $species_defs->get_config($_, 'SPECIES_SCIENTIFIC_NAME'),
        'assembly'          => $species_defs->get_config($_, 'ASSEMBLY_NAME'),
        'assembly_version'  => $species_defs->get_config($_, 'ASSEMBLY_VERSION'),
        'group'             => $species_defs->get_config($_, 'SPECIES_GROUP')
      } unless exists $self->{'_species_info'}{$_};
    }

    $self->{'_species_info_loaded'} = !$species;
  }

  return $species ? $self->{'_species_info'}{$species} : $self->{'_species_info'};
}

sub order_species_by_clade {
### Read the site-wide configuration variables TAXON_LABEL and TAXON_ORDER
### and sort all the SpeciesTreeNode objects given in $species
### @param  : arrayref of SpeciesTreeNode objects
### @return : arrayref of SpeciesTreeNode objects

  my ($self, $species) = @_;

  my $species_defs  = $self->species_defs;
  my $species_info  = $self->get_species_info;
  my $labels        = $species_defs->TAXON_LABEL; ## sort out labels

  my (@group_order, %label_check);
  foreach my $taxon (@{$species_defs->TAXON_ORDER || []}) {
    my $label = $labels->{$taxon} || $taxon;
    push @group_order, $label unless $label_check{$label}++;
  }

  my %stn_by_name = ();
  foreach my $stn (@$species) {
    $stn_by_name{$stn->genome_db->name} = $stn;
  };

  ## Sort species into desired groups
  my %phylo_tree;

  foreach (keys %$species_info) {
    my $group = $species_info->{$_}->{'group'};
    my $group_name = $group ? $labels->{$group} || $group : 'no_group';
    push @{$phylo_tree{$group_name}}, $_;
  }

  my @final_sets;

  my $favourites    = $self->get_favourite_species;
  if (scalar @$favourites) {
    push @final_sets, ['Favourite species', [map {encode_entities($stn_by_name{lc $_})} @$favourites]];
  }

  ## Output in taxonomic groups, ordered by common name
  foreach my $group_name (@group_order) {
    my $species_list = $phylo_tree{$group_name};

    if ($species_list && ref $species_list eq 'ARRAY' && scalar @$species_list) {
      my $name_to_use = ($group_name eq 'no_group') ? (scalar(@group_order) > 1 ? 'Other species' : 'All species') : encode_entities($group_name);
      my @sorted_by_common = sort { $species_info->{$a}->{'common'} cmp $species_info->{$b}->{'common'} } @$species_list;
      push @final_sets, [$name_to_use, [map {encode_entities($stn_by_name{lc $_})} @sorted_by_common]];
    }
  }

  return \@final_sets;
}

# Does an ordinary redirect
sub redirect {
  my ($self, $url) = @_;
  $url = $self->url($url) if $url && ref $url;
  $self->input->redirect($url || $self->current_url);
}

sub current_url { return $_[0]->url(undef, undef, 1); }

sub url {
  ## Gets the current or modified url
  ## If no argument provided, gets the current url after removing unwanted params, and sorting remaining ones
  ## @param Extra string that goes in the url path just after Species name and before type (optional)
  ## @param Hashref of new params that will be added, or will override the existing params in the current url - can have following keys:
  ##  - species, type, action, funtion: Overrides the existing corresponding values in the url path
  ##  - __species, __action, __type, __function: Will add 'species', 'action', 'type', 'function' GET param to the url (since these keys are reserved)
  ##  - __clear: Flag if on, prevents the core params to be added to the url
  ##  - any other keys (not starting with __): will get serialised and joined to the url as query string
  ## @param Flag if on, returns url as an arrayref [url path, hashref of name-value pair of GET params] - off by default
  ## @param Flag if on, adds existing GET params to the new given GET params - off by default
  ## @return URL string or ArrayRef of path and params
  my $self   = shift;
  my $extra  = $_[0] && !ref $_[0] ? shift : undef;
  my $params = shift || {};
  my ($flag, $all_params) = @_;

  Carp::croak("Not a hashref while calling _url ($params @_)") unless ref $params eq 'HASH';

  my $species = exists $params->{'species'}  ? $params->{'species'}  : $self->species;
  my $type    = exists $params->{'type'}     ? $params->{'type'}     : $self->type;
  my $action  = exists $params->{'action'}   ? $params->{'action'}   : $self->action;
  my $fn      = exists $params->{'function'} ? $params->{'function'} : $action eq $self->action ? $self->function : undef;
  my $c_pars  = $self->core_params;
  my %pars;
  
  if ($all_params) {
    my $input   = $self->input;
    my $is_post = $input->request_method eq 'POST';
    my $method  = $is_post ? 'url_param' : 'param';

    $pars{$_} = $input->$method($_) for $input->$method;                # In case of a POST request, ignore the POST params while adding params to the URL,
    $pars{$_} = $input->param($_)   for $is_post ? keys %$c_pars : ();  # except if the param is a core param

  } elsif (!$params->{'__clear'}) { # add the core params only if clear flag is not on
    %pars = %$c_pars;

    # Remove any unused params
    foreach (keys %pars) {
      delete $pars{$_} unless $pars{$_};
    }
  }

  delete $pars{'t'}  if $params->{'pt'};
  delete $pars{'pt'} if $params->{'t'};
  delete $pars{'t'}  if $params->{'g'} && $params->{'g'} ne $pars{'g'};
  delete $pars{'time'};
  delete $pars{'expand'};

  # add the requested GET params to the query string
  foreach (keys %$params) {
    $_ =~ /^(__)?(species|type|action|function)?(.*)$/;

    # ignore keys 'species|type|action|function' or any key starting with __ but is not __(species|type|action|function)
    next if $1 && $3 || $1 && !$2 || !$1 && $2 && !$3;

    if (defined $params->{$_}) {
      $pars{$1 ? $2 : $_} = $params->{$_}; # remove '__' from any param like '__species', '__type' etc
    } else {
      delete $pars{$_};
    }
  }

  my $url = join '/', map $_ || (), $self->species_defs->species_path($species), $extra, $type, $action, $fn;
  
  return [ $url, \%pars ] if $flag;

  $url .= '?' if scalar keys %pars;

  # Sort the keys so that the url is the same for a given set of parameters
  foreach my $p (sort keys %pars) {
    next unless defined $pars{$p};
    
    # Don't escape colon or space
    $url .= sprintf '%s=%s;', uri_escape($p), uri_escape($_, "^A-Za-z0-9\-_ .!~*'():\/") for ref $pars{$p} ? @{$pars{$p}} : $pars{$p};
  }

  $url =~ s/;$//;

  return $url;
}

sub param {
  my $self = shift;
  
  if (@_) {
    my @T = map _sanitize($_), $self->input->param(@_);
    return wantarray ? @T : $T[0] if @T;
    
    my $view_config = $self->viewconfig;
    
    if ($view_config) {
      $view_config->set(@_) if @_ > 1;
      my @val = $view_config->get(@_);
      return wantarray ? @val : $val[0];
    }
    
    return wantarray ? () : undef;
  } else {
    my @params      = map _sanitize($_), $self->input->param;
    my $view_config = $self->viewconfig;
    
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

sub parse_referer {
  my $self         = shift;
  my $species_defs = $self->species_defs;
  my $servername   = $species_defs->ENSEMBL_SERVERNAME;
  my $server       = $species_defs->ENSEMBL_SERVER;
  my $uri          = $ENV{'HTTP_REFERER'};
     $uri          =~ s/^(https?:\/\/.*?)?\///i;
     $uri          =~ s/[;&]$//;
     
  my ($url, $query_string) = split /\?/, $uri;

  my $info = { absolute_url => $ENV{'HTTP_REFERER'} };
  my @path = split /\//, $url;
  
  unshift @path, 'common' unless $path[0] =~ /(Multi|common)/ || $species_defs->valid_species($path[0]);

  if ($ENV{'HTTP_REFERER'} !~ /$servername/i && $ENV{'HTTP_REFERER'} !~ /$server/ && $ENV{'HTTP_REFERER'} !~ m!/Tools/!) {
    $info->{'external'} = 1;
  } else {
    $info->{'external'} = 0;
    $info->{'uri'}      = "/$uri";
  }

  my @pairs  = split /[&;]/, $query_string;
  my $params = {};

  foreach (@pairs) {
    my ($param, $value) = split '=', $_, 2;

    next unless defined $param;

    $value = '' unless defined $value;
    $param = uri_unescape($param);
    $value = uri_unescape($value);

    push @{$params->{$param}}, $value unless $param eq 'time'; # don't copy time
  }
  $info->{'params'} = $params;

  ## Local dynamic page
  if ($species_defs->OBJECT_TO_SCRIPT->{$path[1]} && !$info->{'external'}) {
    my ($species, $type, $action, $function) = @path;
    $info->{'ENSEMBL_SPECIES'}  = $species;
    $info->{'ENSEMBL_TYPE'}     = $type;
    $info->{'ENSEMBL_ACTION'}   = $action;
    $info->{'ENSEMBL_FUNCTION'} = $function;
  }

  if ($species_defs->ENSEMBL_DEBUG_FLAGS & $species_defs->ENSEMBL_DEBUG_REFERER) {
    warn "\n";
    warn "------------------------------------------------------------------------------\n";
    warn "\n";
    warn "  SPECIES:  $info->{'species'}\n";
    warn "  TYPE:     $info->{'type'}\n";
    warn "  ACTION:   $info->{'action'}\n";
    warn "  FUNCTION: $info->{'function'}\n";
    warn "  QS:       $query_string\n";

    foreach my $param (sort keys %$params) {
      warn sprintf '%20s = %s\n', $param, $_ for sort @{$params->{$param}};
    }

    warn "\n";
    warn "  URI:      $uri\n";
    warn "\n";
    warn "------------------------------------------------------------------------------\n";
  }
 
  return $info;
}

sub filename {
  my ($self, $object) = @_;
  
  my $name = sprintf('%s-%s-%s-%d',
    $self->species,
    $self->type,
    $self->action,
    $self->species_defs->ENSEMBL_VERSION
  );
  
  $name .= '-' . $object->stable_id if $object && $object->can('stable_id');
  $name  =~ s/[^-\w\.]/_/g;
  
  return $name;
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
  return $url ? qq(<a href="$url" rel="external" class="constant">$text</a>) : $text;
}

sub get_ext_seq {
  ## Uses PFETCH etc to get description and sequence of an external record
  ## @param External DB type (has to match ENSEMBL_EXTERNAL_DATABASES variable in SiteDefs)
  ## @param Hashref with keys to be passed to get_sequence method of the required indexer (see EnsEMBL::Web::ExtIndex subclasses)
  ## @return Hashref (or possibly a list of similar hashrefs for multiple sequences) with keys:
  ##  - id        Stable ID of the object
  ##  - sequence  Resultant fasta sequence
  ##  - length    Length of the sequence
  ##  - error     Error message if any
  my ($self, $external_db, $params) = @_;

  $external_db  ||= 'DEFAULT';
  $params       ||= {};
  my $indexers    = $self->{'_ext_indexers'};

  unless (exists $indexers->{'databases'}{$external_db}) {
    my ($indexer, $exe);

    # get data from e! databases
    if ($external_db =~ /^ENS/) {
      $indexer = 'ENSEMBL_RETRIEVE';
      $exe     = 1;
    } else {
      $indexer = $self->{'_species_defs'}->ENSEMBL_EXTERNAL_DATABASES->{$external_db} || $self->{'_species_defs'}->ENSEMBL_EXTERNAL_DATABASES->{'DEFAULT'} || 'PFETCH';
      $exe     = $self->{'_species_defs'}->ENSEMBL_EXTERNAL_INDEXERS->{$indexer};
    }
    if ($exe) {
      my $classname = "EnsEMBL::Web::ExtIndex::$indexer";
      $indexers->{'indexers'}{$classname}  ||= $self->dynamic_use($classname) ? $classname->new($self) : undef; # cache the indexer as it can be shared among different databases
      $indexers->{'databases'}{$external_db} = { 'indexer' => $indexers->{'indexers'}{$classname}, 'exe' => $exe };
    } else {
      $indexers->{'databases'}{$external_db} = {};
    }
  }

  my $indexer = $indexers->{'databases'}{$external_db}{'indexer'};

  return { 'error' => "Could not get an indexer for '$external_db'" } unless $indexer;

  my (@sequences, $error);

  try {
    @sequences = $indexer->get_sequence({ %$params,
      'exe' => $indexers->{'databases'}{$external_db}{'exe'},
      'db'  => $external_db
    });
  } catch {
    $error = $_->message;
  };

  return { 'error' => $error             } if $error;
  return { 'error' => 'No entries found' } if !@sequences;

  return wantarray ? @sequences : $sequences[0];
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
  ### Create a new EnsEMBL::Web::ViewConfig object for the component and type passed.
  ### Stores the ViewConfig as $self->viewconfig if a third argument of "cache" is passed.

  my $self       = shift;
  my $component  = shift;
  my $type       = shift || $self->type;
  my $cache      = shift eq 'cache';
  my $session    = $self->session;
  my $cache_code = "${type}::$component";
  
  return undef unless $session;
  
  my $view_config = $session->view_configs->{$cache_code};
  
  if (!$view_config) {
    my $module_name = $self->get_module_names('ViewConfig', $type, $component);
    
    return unless $module_name;
    
    $view_config = $module_name->new($type, $component, $self);
    
    $session->apply_to_view_config($view_config, $cache_code); # $view_config->code and $cache_code can be different
  }
  
  $self->viewconfig = $view_config if $cache;
  
  return $view_config;
}

sub get_imageconfig {
  ### Returns an EnsEMBL::Web::ImageConfig object
  ### If passed one parameter then it loads the data (and doesn't cache it)
  ### If passed two parameters it loads the data (and caches it against the second name - NOTE you must use the
  ### second name version IF you want the configuration to be saved by the session - otherwise it will be lost
  
  my $self       = shift;
  my $type       = shift;
  my $cache_code = shift || $type;
  my $species    = shift;
  my $session    = $self->session;
  
  return undef unless $session;
  return $session->image_configs->{$cache_code} if $session->image_configs->{$cache_code};
  
  my $module_name  = "EnsEMBL::Web::ImageConfig::$type";
  my $image_config = $self->dynamic_use($module_name) ? $module_name->new($self, $species, $cache_code) : undef;
  
  if ($image_config) {
    $session->apply_to_image_config($image_config, $cache_code);
    $image_config->initialize;
    $image_config->attach_das if $image_config->has_das;
  } else {
    $self->dynamic_use_failure($module_name);
  }
  
  return $image_config;
}

sub fetch_userdata_by_id {
  my ($self, $record_id) = @_;
  
  return unless $record_id;
  
  my ($type, $code) = split '_', $record_id, 2;
  my $data = {};
  
  if ($type eq 'user') {
    my $user    = $self->user;
    my $user_id = [ split '_', $record_id ]->[1];
    
    return unless $user && $user->id == $user_id;
  } else {
    $data = $self->get_data_from_session($type, $code);
  }
  
  if (!scalar keys %$data) {
    my $fa       = $self->get_adaptor('get_DnaAlignFeatureAdaptor', 'userdata');
    my $aa       = $self->get_adaptor('get_AnalysisAdaptor',        'userdata');
    my $features = $fa->fetch_all_by_logic_name($record_id);
    my $analysis = $aa->fetch_by_logic_name($record_id);
    if ($analysis) {
      my $config   = $analysis->web_data;
    
      $config->{'track_name'}  = $analysis->description   || $record_id;
      $config->{'track_label'} = $analysis->display_label || $analysis->description || $record_id;
    
      $data->{$record_id} = { features => $features, config => $config };
    }
  }
  
  return $data;
}

sub get_data_from_session {
  my ($self, $type, $code) = @_;
  my $species  = $self->param('species') || $self->species;
  my $tempdata = $self->session->get_data(type => $type, code => $code);
  my $name     = $tempdata->{'name'};

  # NB this used to be new EnsEMBL::Web... etc but this does not work with the
  # FeatureParser module for some reason, so have to use FeatureParser->new()
  my $parser = EnsEMBL::Web::Text::FeatureParser->new($self->species_defs, undef, $species);
 
  my %file_params = (
                      'hub' => $self,
                    );
 
  ## Build in some backwards compatiblity with old file paths
  if ($type eq 'url') {
    $file_params{'input_drivers'} = ['URL'];
    $file_params{'file'} = $tempdata->{'file'} || $tempdata->{'url'};
  }
  else {
    $file_params{'file'} = $tempdata->{'file'};
    unless ($file_params{'file'}) {
      $file_params{'file'} = join('/', $tempdata->{'prefix'}, $tempdata->{'filename'});
    }
  }

  my $file = EnsEMBL::Web::File::User->new(%file_params);
  my $result = $file->read;
  if ($result->{'error'}) {
    ## TODO - do something useful with the error!
    warn ">>> ERROR READING FILE: ".$result->{'error'};
    return {};
  }
  else {
    my $content = $result->{'content'};

    $parser->parse($content, $tempdata->{'format'});

    return { parser => $parser, name => $name };
  }
}

sub get_favourite_species {
  my $self         = shift;
  my $species_defs = $self->species_defs;
  my @favourites   = @{$species_defs->DEFAULT_FAVOURITES || []};
     @favourites   = ($species_defs->ENSEMBL_PRIMARY_SPECIES, $species_defs->ENSEMBL_SECONDARY_SPECIES) unless scalar @favourites;
  return \@favourites;
}

# The request cache explicitly and deliberately has the lifetime of a
# request. You can therefore use keys which are only guraranteed unique
# for a request. This cache is designed for communicating data which we
# are pretty sure will be useful later but which is at a very different
# part of the call tree. For example, features on stranded pairs of tracks.

sub req_cache_set {
  my ($self,$key,$value) = @_;

  $self->{'_req_cache'}{$key} = $value;
}

sub req_cache_get {
  my ($self,$key) = @_;

  return $self->{'_req_cache'}{$key};
}

sub is_new_regulation_pipeline { # Regulation rewrote their pipeline
  my ($self) = @_;

  return $self->{'is_new_pipeline'} if defined $self->{'is_new_pipeline'};
  my $fg = $self->database('funcgen');
  my $new = 0;
  if($fg) {
    my $mca = $fg->get_MetaContainer;
    my $date = $mca->single_value_by_key('regbuild.last_annotation_update');
    my ($year,$month) = split('-',$date);
    $new = 1;
    $new = 0 if $year < 2014 or $year == 2014 and $month < 6;
  }
  $self->{'is_new_pipeline'} = $new;
  return $new;
}

1;
