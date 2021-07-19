=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

### A centralised object giving access to data connections and the web environment 
### Hub can only when created during a web request - ie. needs to have an apache request object
### Hub uses the Flyweight design pattern to create a single object that is 
### passed around between all other objects that require data connectivity.
### The Hub stores information about the current web page and its environment, 
### including cgi parameters, settings parsed from the URL, browser session, 
### database connections, and so on.

use strict;

use Carp;
use CGI;
use URI::Escape qw(uri_escape);
use HTML::Entities qw(encode_entities);

use EnsEMBL::Draw::Utils::ColourMap;

use EnsEMBL::Web::Attributes;
use EnsEMBL::Web::Cache;
use EnsEMBL::Web::Cookie;
use EnsEMBL::Web::Exceptions qw(WebException);
use EnsEMBL::Web::ExtURL;
use EnsEMBL::Web::Problem;
use EnsEMBL::Web::Session;
use EnsEMBL::Web::File::User;
use EnsEMBL::Web::ViewConfig;
use EnsEMBL::Web::Tools::Misc qw(style_by_filesize);
use EnsEMBL::Web::Tools::FailOver::SNPedia;
use EnsEMBL::Web::Tools::FailOver::AlleleRegistry;

use EnsEMBL::Web::QueryStore;
use EnsEMBL::Web::QueryStore::Cache::BookOfEnsembl;
use EnsEMBL::Web::QueryStore::Cache::PrecacheFile;
use EnsEMBL::Web::QueryStore::Cache::None;
use EnsEMBL::Web::QueryStore::Source::Adaptors;
use EnsEMBL::Web::QueryStore::Source::SpeciesDefs;
use EnsEMBL::Web::Tools::FailOver::Wasabi;
use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_require);

use parent qw(EnsEMBL::Web::DBHub);

sub viewconfig      :Accessor; # Store viewconfig for the current component being rendered (FIXME - this is done to that param method can return viewconfig param value - causes lots of problems)
sub type            :Accessor;
sub action          :Accessor;
sub function        :Accessor;
sub sub_function    :Accessor;
sub controller_name :Accessor;
sub r               :Accessor;
sub controller      :Accessor;
sub session         :Accessor;
sub user            :Accessor;
sub factorytype     :Accessor;
sub builder         :Accessor;
sub factory         :Accessor;
sub cache           :Accessor;
sub components      :Accessor;
sub input           :Accessor;
sub cookies         :Accessor;
sub core_params     :Accessor;

sub template        :AccessorMutator;

sub referer           { return shift->controller->referer; }
sub colourmap         { return $_[0]{'colourmap'} ||= EnsEMBL::Draw::Utils::ColourMap->new($_[0]->species_defs); }

sub species_path      { return shift->species_defs->species_path(@_);       }
sub table_info        { return shift->species_defs->table_info(@_);         }
sub delete_param      { shift->input->delete(@_); }


sub users_available         { 0 } # overridden in user plugin
sub users_plugin_available  { 0 } # overridden in user plugin
sub get_shared_config       { 0 } # overridden in user plugin

sub object_types    { return $_[0]{'_object_types'} ||= { map { $_->[0] => $_->[1] } @{$_[0]->controller->object_params || []} }; }
sub ordered_objects { return $_[0]{'_ordered_objs'} ||= [ map $_->[0], @{$_[0]->controller->object_params || []} ]; }

sub new {
  ## @constructor
  ## @param Controller object
  my ($class, $controller) = @_;

  my $self = $class->SUPER::new($controller->species, $controller->species_defs);

  $self->{'controller'}       = $controller;
  $self->{'r'}                = $controller->r;
  $self->{'type'}             = $ENV{'ENSEMBL_TYPE'}      = $controller->type;
  $self->{'action'}           = $ENV{'ENSEMBL_ACTION'}    = $controller->action;
  $self->{'function'}         = $ENV{'ENSEMBL_FUNCTION'}  = $controller->function;
  $self->{'controller_name'}  = $ENV{'ENSEMBL_SCRIPT'}    = [ split '::', ref($controller) ]->[-1];
  $self->{'components'}       = [];

  $self->init_cookies;
  $self->init_cache;
  $self->init_input;
  $self->query_store_setup;
  $self->set_core_params;
  $self->init_session;
  $self->init_user;

  # apply the factorytype hack for Location - TODO move this Factory::Location (use decorator pattern)
  my $factorytype   = $self->{'type'} eq 'Location' && $self->{'action'} =~ /^Multi(Ideogram.*|Top|Bottom)?$/ ? 'MultipleLocation' : undef;
     $factorytype ||= $self->input->param('factorytype') || $self->{'type'};
  $self->{'factorytype'} = $factorytype;

  return $self;
}

sub init_cookies {
  ## Initialises cookies from request header
  my $self = shift;
  $self->{'cookies'} = $self->r ? EnsEMBL::Web::Cookie->new_from_header($self->r) : {};
}

sub init_cache {
  ## Initialises cache object
  my $self = shift;
  $self->{'cache'} = EnsEMBL::Web::Cache->new(enable_compress => 1, compress_threshold => 10000, ens_debug=> 0);
}

sub init_input {
  ## Initialise CGI input
  my $self  = shift;

  $CGI::POST_MAX          = $self->controller->upload_size_limit if $self->controller; # Set max upload size
  $CGI::LIST_CONTEXT_WARN = 2; # Hack to stop perl warning about 'param' method being used in list context

  my $input = CGI->new;
  $self->{'input'}        = $input;
}

sub init_session {
  ## Initialises a session object for the current request
  my $self = shift;
  $self->{'session'} = EnsEMBL::Web::Session->new($self);
}

sub init_user {
  ## Initialise user - to be implemented in user plugin
  $_[0]->{'user'} = undef;
}

sub session_id {
  ## Gets session id of the current session
  ## @return Integer session id
  return shift->session->session_id;
}

sub web_proxy {
  ## Gets the http and https proxy address
  return $SiteDefs::HTTP_PROXY || '';
}

sub https_proxy {
  ## Gets the http and https proxy address
  return $SiteDefs::HTTPS_PROXY || '';
}

sub image_width {
  ## Gets image width or sets it for subsequent requests by setting a cookie
  ## @param Width in pixels (if setting)
  ## @return Width in pixels
  my ($self, $width) = @_;

  if ($width) {
    $self->{'image_width'} = $width;
    $self->set_cookie('ENSEMBL_WIDTH', $width);
  }

  return $self->{'image_width'} ||= $self->param('image_width') || $self->get_cookie_value('ENSEMBL_WIDTH') || 800;
}

sub get_cookie_value {
  ## Gets value of a cookie
  ## @param Cookie name
  ## @param Flag kept on if cookie is encrypted
  ## @return Cookie value, possibly an empty string if cookie doesn't exist
  my ($self, $name) = splice @_, 0, 2;
  my $cookie  = $self->cookies->{$name} ? $self->get_cookie($name, @_) : undef; # don't create a new cookie

  return $cookie ? $cookie->value : '';
}

sub get_cookie {
  ## Gets a cookie object (or creates a new one if one doesn't exist)
  ## @param Cookie name
  ## @param Flag kept on if cookie is encrypted
  ## @return Cookie object (possible newly created)
  my ($self, $name, $is_encrypted) = @_;
  return unless $self->r;
  my $cookie = $self->cookies->{$name} ||= EnsEMBL::Web::Cookie->new($self->r, {'name' => $name});

  $cookie->encrypted($is_encrypted || 0);

  return $cookie;
}

sub set_cookie {
  ## Sets a cookie with the given param
  ## @param Cookie name (OR hashref with keys as accepted by EnsEMBL::Web::Cookie constructor)
  ## @param Cookie value (if first argument was cookie name)
  ## @return Cookie object
  my ($self, $name, $value) = @_;

  my $params  = ref $name ? $name : { 'name' => $name, 'value' => $value };
  my $cookie  = $self->get_cookie(delete $params->{'name'}, delete $params->{'encrypted'});

  return $cookie->bake($params);
}

sub clear_cookie {
  ## Clears a cookie with the given name
  ## @param Cookie name
  ## @return Cookie object or undef if no cookie was present with that name
  my ($self, $name) = @_;

  my $cookie = delete $self->cookies->{'name'};

  return $cookie ? $cookie->clear : undef;
}

sub add_components {
  my $self = shift;
  push @{$self->{'components'}}, @_;
}

sub extURL {
  ## Gets ExtURL object
  my $self = shift;
  $self->{'extURL'} ||= EnsEMBL::Web::ExtURL->new($self->species, $self->species_defs),
}

sub get_db {
  # Gets the database name used to create the object
  my $self = shift;
  my $db = $self->param('db') || 'core';
  return $db eq 'est' ? 'otherfeatures' : $db;
}

sub set_builder {
  ## Sets the builder to generate objects for the request
  my ($self,$builder) = @_;
  $self->{'builder'} = $builder;
}

sub core_object {
  ## Gets the core Object for the request
  ## @return EnsEMBL::Web::Object subclass (or undef if no object is found)
  my $self = shift;
  my $name = shift;

  if($name eq 'parameters') { ## TODO - replace the usage with core_params method
    return $self->{'core_params'};
  }

  my $object;
  if ($self->{'builder'}) {
    ## Hack for inconsistent capitalisation of LRG
    if ($name =~ /lrg/i) { $name = 'LRG'; } else { $name = ucfirst($name); }
    $object = $self->{'builder'}->object($name); 
  }
  return $object;
}

sub create_object {
  my $self = shift;
  my $name = shift;

  my $object;
  if ($self->{'builder'}) {
    $object = $self->{'builder'}->object(ucfirst $name) || $self->{'builder'}->create_object(ucfirst $name);
  }
  return $object;
}

sub set_core_params {
  ## Initialises core parameter hash from CGI parameters
  my $self        = shift;
  my $core_params = {'db' => 'core'};

  for (@{$self->species_defs->core_params}) {
    my @param = $self->param($_);
    $core_params->{$_} = scalar @param == 1 ? $param[0] : \@param if scalar @param;
  }

  $self->{'core_params'} = $core_params;
}

sub core_param {
  ## Gets/sets value of a given core param
  ## @param Param name
  ## @param Param value (if setting)
  my $self  = shift;
  my $name  = shift;

  return unless $name;

  $self->{'core_params'}{$name} = shift if @_;

  return $self->{'core_params'}{$name};
}

sub delete_core_param { # TODO - replace the usage with __clear on hub->url
  ## Deletes a core param with given name
  ## @param Param name
  my ($self, $name) = @_;
  return unless $name;
  delete $self->{'core_params'}{$name};
}

sub get_species_info {
  ## Gets info about all valid species or an individual species if url name provided
  ## @param URL name for a species (String) (optional)
  ## @return Hashref with keys: key, name, common, scientific and group for single species, OR hashref of hashrefs for { species url name => { species info } .. }
  my ($self, $species) = @_;

  $self->{'_species_info'} ||= {};

  unless ($self->{'_species_info_loaded'} || $species && $self->{'_species_info'}{$species}) {

    my $species_defs      = $self->species_defs;
    my @required_species  = $species_defs->valid_species;
       @required_species  = grep {$species eq $_} @required_species if $species;

    for (@required_species) {
      my $strain        = $species_defs->get_config($_, 'SPECIES_STRAIN') || '';
      my $strain_group  = $species_defs->get_config($_, 'STRAIN_GROUP') || '';
                               
      $self->{'_species_info'}{$_} = {
        'key'               => $_,
        'name'              => $species_defs->get_config($_, 'SPECIES_URL'),
        'display_name'      => $species_defs->get_config($_, 'SPECIES_DISPLAY_NAME'),
        'common'            => $species_defs->get_config($_, 'SPECIES_COMMON_NAME'),
        'scientific'        => $species_defs->get_config($_, 'SPECIES_BINOMIAL')
                                || $species_defs->get_config($_, 'SPECIES_SCIENTIFIC_NAME'),
        'assembly'          => $species_defs->get_config($_, 'ASSEMBLY_NAME'),
        'assembly_version'  => $species_defs->get_config($_, 'ASSEMBLY_VERSION'),
        'assembly_accession'=> $species_defs->get_config($_, 'ASSEMBLY_ACCESSION'),
        'group'             => $species_defs->get_config($_, 'SPECIES_GROUP'),
        'image'             => $species_defs->get_config($_, 'SPECIES_IMAGE') 
                                || $species_defs->get_config($_, 'SPECIES_URL'),
        'strain'            => $strain,
        'is_reference'      => $species_defs->get_config($_, 'IS_REFERENCE'),
        'strain_group'      => $strain_group,
        'strain_type'       => $species_defs->get_config($_, 'STRAIN_TYPE'),
      } unless exists $self->{'_species_info'}{$_};
    }

    $self->{'_species_info_loaded'} = !$species;
  }

  return $species ? $self->{'_species_info'}{$species} : $self->{'_species_info'};
}

sub current_url {
  ## Gets the current url
  ## @return Relative url (String)
  return $_[0]->url(undef, undef, 1);
}

sub url {
  ## Gets the current or modified url
  ## If no argument provided, gets the current url after removing unwanted params, and sorting remaining ones
  ## @param Controller name that goes in the url path just after Species name and before type (optional)
  ## @param Hashref of new params that will be added, or will override the existing params in the current url - can have following keys:
  ##  - species, type, action, funtion: Overrides the existing corresponding values in the url path
  ##  - __species, __action, __type, __function: Will add 'species', 'action', 'type', 'function' GET param to the url (since these keys are reserved)
  ##  - __clear: Flag if on, prevents the core params to be added to the url
  ##  - any other keys (not starting with __): will get serialised and joined to the url as query string
  ## @param Flag if on, returns url as an arrayref [url path, hashref of name-value pair of GET params] - off by default
  ## @param Flag if on, adds existing GET params to the new given GET params - off by default
  ## @return URL string or ArrayRef of path and params
  my $self          = shift;
  my $controller    = $_[0] && !ref $_[0] ? shift : undef;
  my $params        = shift || {};
  my $flag          = shift;
  my $all_params    = shift;

  ## Check for illegal characters in the species name, in case
  ## someone has used a common name with weird stuff in it 
  ## (e.g. mouse strain names with slashes)
  my $illegal = '\/|\?|=';
  if ($params->{'species'} && $params->{'species'} =~ /$illegal/) {
    warn sprintf '######## ILLEGAL SPECIES NAME %s IN URL ########', $params->{'species'};
    ## Stripping these characters might still produce a 404,
    ## but at least it won't be horribly broken
    $params->{'species'} =~ s/$illegal/_/g;
  }

  my $species       = exists $params->{'species'}       ? $params->{'species'}      : $self->species;
  my $type          = exists $params->{'type'}          ? $params->{'type'}         : $self->type;
  my $action        = exists $params->{'action'}        ? $params->{'action'}       : $self->action;
  my $function      = exists $params->{'function'}      ? $params->{'function'}     : $action eq $self->action ? $self->function : undef;
  my $sub_function  = exists $params->{'sub_function'}  ? $params->{'sub_function'} : $action eq $self->action && $function eq $self->function ? $self->{'sub_function'} : undef;
  my $c_pars        = $self->core_params;
  my %pars;

  if ($all_params) {
    my $input   = $self->input;
    my $is_post = $input->request_method eq 'POST';
    my $method  = $is_post ? 'url_param' : 'param';

    $pars{$_} = $input->$method($_) for $input->$method;                # In case of a POST request, ignore the POST params while adding params to the URL,
    $pars{$_} = $input->param($_)   for $is_post ? keys %$c_pars : ();  # except if the param is a core param

  } elsif ($c_pars && !$params->{'__clear'}) { # add the core params only if clear flag is not on
    %pars = %$c_pars;

    # Remove any unused params
    foreach (keys %pars) {
      delete $pars{$_} unless $pars{$_};
    }
  }

  delete $pars{'t'}  if $params->{'pt'};
  delete $pars{'pt'} if $params->{'t'};
  delete $pars{'t'}  if $params->{'g'} && $params->{'g'} ne $pars{'g'};
  delete $pars{'v'}  if $params->{'vf'};
  delete $pars{'time'};
  delete $pars{'_'};
  # db param not required for tools (as it breaks when accessing RID view from blast results with db=otherfeatures param which gets added from search results).
  delete $pars{'db'} if $params->{'type'} eq 'Tools';
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

  ## Remove version numbers if exporting
  my $page_action = $controller || $action;
  if ($page_action =~ /[Data|Image]Export/) {
    while (my ($k, $v) = each (%pars)) {
      if ($k =~ /[g|t]\d?/) { # g, t, t1, t2, etc
        $v =~ s/\.\d+$//;
        $pars{$k} = $v;
      }
    }
  }

  my $url = join '/', grep $_, $self->species_defs->species_path($species), $controller, $type, $action, $function, $sub_function;
  
  return [ $url, \%pars ] if $flag;

  $url .= '?' if scalar keys %pars;

  # Sort the keys so that the url is the same for a given set of parameters
  foreach my $p (sort keys %pars) {
    next unless defined $pars{$p};
    
    # Don't escape colon or space
    $url .= sprintf '%s=%s;', uri_escape($p), uri_escape($_, "^A-Za-z0-9\-_ .!~*'():\/") for ref $pars{$p} eq "ARRAY" ? @{$pars{$p}} : $pars{$p};
  }

  $url =~ s/;$//;

  return $url;
}

sub get_permanent_url {
  ## Get the permanent url for the current or given url
  ## @param URL (string or hashref as expected by self->url method) (optional - takes current url as default)
  ## @param Hashref with following keys:
  ##  - ignore_archive Flag will on will not create a archive permalink
  ##  - allow_redirect Flag if on will not add params that prevent mirror/mobile redirect
  my ($self, $url, $options) = @_;

  $options ||= {};

  my $sd = $self->species_defs;

  # if url hashref provided
  $url  ||= $self->current_url;
  $url    = $self->url($url) if ref $url;

  # remove time, redirect and mobileredirect params
  $url =~ s/(\;|\&)*(time|redirect|mobileredirect)=[^\;\&]+(\;|\&)*/$1 && $3 ? q(;) : q()/eg;
  $url =~ s/\;$//;

  # add params to prevent redirect
  $url .= ($url =~ /\?/ ? ';' : '?').'redirect=no;mobileredirect=no' unless $options->{'allow_redirect'};

  return sprintf '%s/%s',
    ($options->{'ignore_archive'} ? $sd->ENSEMBL_BASE_URL : $self->_get_permanent_url_base) =~ s/\/*$//r,
    $url =~ s/^\/*//r;
}

sub _get_permanent_url_base {
  ## @private
  ## Get base url for permanent link
  my $self  = shift;
  my $sd    = $self->species_defs;

  return lc($sd->ARCHIVE_BASE_DOMAIN
    ? sprintf('//%s.%s', $sd->ARCHIVE_VERSION, $sd->ARCHIVE_BASE_DOMAIN)
    : $sd->ENSEMBL_BASE_URL
  );
}

sub param {
  # @status - being changed to not deal with viewconfig params (only CGI params)
  my $self = shift;
  return unless $self->input;  

  if (@_) {
    my @T = map _sanitize($_), $self->input->param(@_);
    return wantarray ? @T : $T[0] if @T;
    
    my $view_config = $self->viewconfig;

    if ($view_config) {

      my @caller;
      my $i = 0;
      while (1) {
        my @c = caller($i++);
        last if $c[3] !~ /::param$/;
        @caller = @c;
      }

      if (@_ > 1) {
        warn sprintf "ERROR: Setting view_config from hub at %s line %s\n", $caller[1], $caller[2];
      }
      $view_config->set(@_) if @_ > 1;
      my @val = $view_config->get(@_);

      #warn sprintf "DEPRECATED: If trying to get Component's ViewConfig specific param, use param method on component at %s line %s\n", $caller[1], $caller[2] if @val;

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

sub multi_params {
  my $self = shift;
  my $realign = shift;

  my $input = $self->input;
  return {} unless $input;

  my %params = defined $realign ?
    map { $_ => $input->param($_) } grep { $realign ? /^([srg]\d*|pop\d+|align)$/ && !/^[rg]$realign$/ : /^(s\d+|r|pop\d+|align)$/ && $input->param($_) } $input->param :
    map { $_ => $input->param($_) } grep { /^([srg]\d*|pop\d+|align)$/ && $input->param($_) } $input->param;

  return \%params;
}

sub get_alignment_id {
  my $self = shift;
  return $self->param('align') || $self->session->get_record_data({type => 'view_config', code => 'alignments_selector'})->{$self->species}->{'align'} || '';
}

sub filename {
  my ($self, $object) = @_;
  my $type = $self->type;

  my $name = sprintf('%s_%s_%s',
    $self->species,
    $type,
    $self->action,
  );

  my $identifier;
  if ($type =~ /Variation/) {
    $identifier = $self->param('v') || $self->param('sv');
  }
  elsif ($type eq 'Location') {
    ($identifier = $self->param('r')) =~ s/:|-/_/;
  }
  elsif ($object) { 
    if ($type eq 'Phenotype') {
      $identifier = $object->get_phenotype_desc;
    }
    elsif ($object->can('stable_id')) {
      $identifier = $object->stable_id;
    }
  }

  $name .= '_' . $identifier;
 
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
  my $new_url = $self->extURL || return;
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
  ## @param External DB type (has to match ENSEMBL_EXTERNAL_DATABASES variable in SiteDefs, except ENSEMBL and REST)
  ## @param Hashref with keys to be passed to get_sequence method of the required indexer (see EnsEMBL::Web::ExtIndex subclasses)
  ## @return Hashref (or possibly a list of similar hashrefs for multiple sequences) with keys:
  ##  - id        Stable ID of the object
  ##  - sequence  Resultant fasta sequence
  ##  - length    Length of the sequence
  ##  - error     Error message if any
  my ($self, $external_db, $params) = @_;

  $external_db  ||= 'DEFAULT';
  $params       ||= {};
  my $indexers    = $self->{'_ext_indexers'} ||= {};

  unless (exists $indexers->{'databases'}{$external_db}) {
    my ($indexer, $exe);

    if ($external_db eq 'REST') {
      $indexer = 'ENSEMBL_REST';
      $exe     = 1;
    } elsif ($external_db =~ /^ENS/) {
      $indexer = 'ENSEMBL_RETRIEVE';
      $exe     = 1;
    } else {
      $indexer = $self->species_defs->ENSEMBL_EXTERNAL_DATABASES->{$external_db} || $self->species_defs->ENSEMBL_EXTERNAL_DATABASES->{'DEFAULT'} || 'DBFETCH';
      $exe     = $self->species_defs->ENSEMBL_EXTERNAL_INDEXERS->{$indexer};
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

sub glossary_lookup {
  ## Get the glossary lookup hash
  ## @return Hashref with merged keys from TEXT_LOOKUP and ENSEMBL_GLOSSARY
  my $self = shift;

  if (!$self->{'_glossary_lookup'}) {
    my %glossary  = $self->species_defs->multiX('ENSEMBL_GLOSSARY');
    my %lookup    = $self->species_defs->multiX('TEXT_LOOKUP');
    $self->{'_glossary_lookup'} = {};

    $self->{'_glossary_lookup'}{$_} = $glossary{$_}{'desc'} for keys %glossary;
    $self->{'_glossary_lookup'}{$_} = $lookup{$_}{'desc'} for keys %lookup;
  }

  return $self->{'_glossary_lookup'};
}

sub get_viewconfig {
  ## Gets the ViewConfig object for the given component and type
  ## @param Component name or hashref with keys below:
  ##  - component Name of the component
  ##  - type      (Optional) Object type - take default as hub->type
  ##  - cache     (Optional) Flag kept on if it's the main viewconfig for the current request and thus should be safe to cache it in hub
  ## TODO - fix this 'cache' thing - it's only needed because 'param' method needs to know the current viewconfig
  ## @return An instance of EnsEMBL::Web::ViewConfig sub-class
  my ($self, $params) = @_;

  $params = { 'component' => $params } unless ref $params;

  my $component   = $params->{'component'}  || '';
  my $type        = $params->{'type'}       || $self->type;
  my $cache_code  = "${type}::$component";

  $self->{'_view_configs'} ||= {};

  if (!exists $self->{'_view_configs'}{$cache_code}) {

    my $module_name = $self->get_module_names('ViewConfig', $type, $component);

    $self->{'_view_configs'}{$cache_code} = $module_name ? $module_name->new($self, $type, $component) : undef;
  }

  # if it's the main one
  $self->{'viewconfig'} = $self->{'_view_configs'}{$cache_code} if $params->{'cache'};

  return $self->{'_view_configs'}{$cache_code};
}

sub get_imageconfig {
  ## Gets the ImageConfig object for the given type
  ## @param Type of the image config required (string) OR Hashref with following keys:
  ##  - type        Type of the image config required
  ##  - cache_code  (optional) Cache code to retrieve/save the config in cache (takes type as the cache code if not present)
  ##  - species     (optional) Species for the image config
  ## @return An instance of EnsEMBL::Web::ImageConfig sub-class
  my ($self, $params) = @_;

  $params = { 'type' => $params } unless ref $params;

  my $type        = $params->{'type'};
  my $species     = $params->{'species'}    || $self->species;
  my $cache_code  = $params->{'cache_code'} || $type;

  $self->{'_image_configs'} ||= {};

  if (!exists $self->{'_image_configs'}{$cache_code}) {
    $self->{'_image_configs'}{$cache_code} = dynamic_require("EnsEMBL::Web::ImageConfig::$type")->new($self, $species, $type, $cache_code);
  }

  return $self->{'_image_configs'}{$cache_code};
}

sub fetch_userdata_by_id {
## Just a wrapper around get_data_from_session now that userdata dbs have been retired
  my ($self, $record_id) = @_;
  return unless $record_id;
 
  my ($type, $code, $user_id) = split '_', $record_id;
  return $self->get_data_from_session($type, $code);
}

sub get_data_from_session {
  my ($self, $type, $code) = @_;
  my $species  = $self->param('species') || $self->species;
  my $tempdata = $self->session->get_data(type => $type, code => $code);
  my $name     = $tempdata->{'name'};

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
  return $file;
}

sub get_favourite_species {
  my $self         = shift;
  my $species_defs = $self->species_defs;
  my @favourites   = @{$species_defs->DEFAULT_FAVOURITES || []};
     @favourites   = ($species_defs->ENSEMBL_PRIMARY_SPECIES, $species_defs->ENSEMBL_SECONDARY_SPECIES) unless scalar @favourites;
  return \@favourites;
}

sub _source_url {
  my ($url,$type,$params) = @_;

  my @x = split(/###/,$url,-1);
  my @y;
  while(@x) {
    push @y,(shift @x);
    next unless @x;
    local $_ = shift @x;
    if(s/^(.*)=(.*)$/$1/) {
      my $pred = $2;
      return undef if $params->{$_} !~ /$pred/;
    }
    push @y,$params->{$_};
  }
  return join('',@y);
}

sub source_url {
  my ($self,$type,$params) = @_;

  my $urls = $self->species_defs->ENSEMBL_EXTERNAL_URLS->{uc $type};
  return undef unless $urls;
  $urls = [$urls] unless ref($urls) eq 'ARRAY';
  foreach my $url (@$urls) {
    my $ret = _source_url($url,$type,$params);
    return $ret if $ret;
  }
  return undef;
}

sub ie_version {
  return 11 if $ENV{'HTTP_USER_AGENT'} =~ m#Trident/7#;
  return 0 unless $ENV{'HTTP_USER_AGENT'} =~ /MSIE (\d+)/;
  return $1;
}

# check to see if SNPedia site is up or down
# if $out then site is up
sub snpedia_status {

  my $self = shift;

  my $failover = EnsEMBL::Web::Tools::FailOver::SNPedia->new($self);
  my $out;

  return $out if $self->species ne 'Homo_sapiens';

  try {
    $out = $failover->get_cached
  } catch {
    warn "SNPEDIA failure";
  };

  return $out;
}

# check to see if ClinGen Allele Registry site is up or down
# if $out then site is up
sub alleleregistry_status {

  my $self = shift;

  my $failover = EnsEMBL::Web::Tools::FailOver::AlleleRegistry->new($self);
  my $out;

  return $out if $self->species ne 'Homo_sapiens';

  try {
    $out = $failover->get_cached
  } catch {
    warn "Allele Registry failure";
  };
  return $out;
}

# Query Store stuff

sub query_store_setup {
  my ($self) = @_;

  my $cache = EnsEMBL::Web::QueryStore::Cache::PrecacheFile->new({
    dir => $SiteDefs::ENSEMBL_PRECACHE_DIR
  });
  $self->{'_query_store'} = EnsEMBL::Web::QueryStore->new({
    Adaptors => EnsEMBL::Web::QueryStore::Source::Adaptors->new($self->species_defs),
    SpeciesDefs => EnsEMBL::Web::QueryStore::Source::SpeciesDefs->new($self->species_defs),
  },$cache);
}

sub get_query     { $_[0]->{'_query_store'}->get($_[1]); }
sub qstore_open   { $_[0]->{'_query_store'}->open; }
sub qstore_close  { $_[0]->{'_query_store'}->close; }

# check to see if Wasabi site is up or down
# if $out then site is up
sub wasabi_status {

  my $self = shift;

  my $failover = EnsEMBL::Web::Tools::FailOver::Wasabi->new($self);
  my $out      = $failover->get_cached;

  return $out;
}

sub create_padded_region {
  my $self = shift;
  my ($seq_region_name, $s, $e, $strand) = $self->param('r') =~ /^([^:]+):(-?\w+\.?\w*)-(-?\w+\.?\w*)(?::(-?\d+))?/;
  my $padded = {};
  # Adding flanking region to 5' and 3' ends
  $padded->{flank5} = ($s && $e) ? int(($e - $s) * $SiteDefs::FLANK5_PERC) : 0;
  $padded->{flank3} = ($s && $e) ? int(($e - $s) * $SiteDefs::FLANK3_PERC) : 0;

  $padded->{r} = sprintf '%s:%s-%s', 
          $seq_region_name, 
          $s - $padded->{flank5},
          $e + $padded->{flank3};
  return $padded;
}

sub configure_user_data {
  my ($self, @track_data) = @_;
  my $species = $self->species;

  foreach my $view_config (map { $self->get_viewconfig({'component' => $_->[0], 'type' => $_->[1]}) || () } @{$self->components}) {
    my $ic_code = $view_config->image_config_type;

    next unless $ic_code;

    my $image_config = $self->get_imageconfig({type => $ic_code, cache_code => $ic_code . time});
    my $vertical     = $image_config->orientation eq 'vertical';

    while (@track_data) {
      my ($track_type, $track) = (shift @track_data, shift @track_data);
      next unless $track->{'species'} eq $species;

      my @nodes = grep $_, $track->{'analyses'} ? map $image_config->get_node($_), split(', ', $track->{'analyses'}) : $image_config->get_node("${track_type}_$track->{'code'}");

      if (scalar @nodes) {
        foreach (@nodes) {
          my $renderers = $_->get_data('renderers');
          my %valid     = @$renderers;
          if ($vertical) {
            $_->set_user_setting('ftype', $track->{'ftype'});
            $_->set_user_setting('display', $track->{'style'} || style_by_filesize($track->{'filesize'}));
          } else {
            my $default_display = $_->get_data('default_display') || 'normal';
            $_->set_user_setting('display', $valid{$default_display} ? $default_display : $renderers->[2]);
          }
          $image_config->altered($_->data->{'name'} || $_->data->{'coption'});
        }

        $image_config->{'code'} = $ic_code;
        $view_config->altered(1);
      }
    }
  }
}

sub store_records_if_needed {
  ## Commits the record db transaction it has been initiated
  my $self    = shift;
  my $session = $self->session;

  $session->store_records if $session;
}

sub new_for_test {
  ## @constructor
  ## Creates a new hub object for a non-web environment (for unit testing)
  my ($class, $args) = @_;

  my $self = $class->SUPER::new($args->{'species'}, $args->{'species_defs'});
  $self->init_input;
  $self->query_store_setup;

  # Arguments passed by a unit test
  $self->{'type'}             = $ENV{'ENSEMBL_TYPE'}      = $args->{'type'};
  $self->{'action'}           = $ENV{'ENSEMBL_ACTION'}    = $args->{'action'};
  $self->{'function'}         = $ENV{'ENSEMBL_FUNCTION'}  = $args->{'function'}; 
  $self->{'controller_name'}  = $ENV{'ENSEMBL_SCRIPT'}    = $args->{'controller_name'} || $args->{'script'};
  $self->{'components'}       = [];
  $self->{'cookies'}          = {};

  return $self;
}

################                  ################
################ Deprecated stuff ################
################                  ################

sub apache_handle   :Deprecated('Use hub->r') { return shift->r; }
sub script          :Deprecated('Use hub->controller_name') { return shift->controller_name; }
sub ExtURL          :Deprecated('Use hub->extURL') { return shift->extURL; }
sub config_adaptor  :Deprecated('Not in use anymore') {  }
sub input_param     :Deprecated('Use param method') { my $self = shift; return _sanitize($self->param(@_)); }


# will be removed
sub has_a_problem      { return scalar keys %{$_[0]{'_problem'}||{}}; }
sub has_fatal_problem  { return scalar @{$_[0]{'_problem'}{'fatal'}||[]}; }
sub has_problem_type   { return scalar @{$_[0]{'_problem'}{$_[1]}||[]}; }
sub get_problem_type   { return @{$_[0]{'_problem'}{$_[1]}||[]}; }
sub clear_problem_type { delete $_[0]{'_problem'}{$_[1]}; }
sub clear_problems     { $_[0]{'_problem'} = {}; }
sub problem {
  my $self = shift;
  push @{$self->{'_problem'}{$_[0]}}, EnsEMBL::Web::Problem->new(@_) if @_;
  return $self->{'_problem'};
}

sub data_species { # TODO - move to Object::UserData where it belongs
  # Determines the species for userdata pages (mandatory, since userdata databases are species-specific)
  my $self    = shift;
  my $species = $self->species;
  $species    = $self->species_defs->ENSEMBL_PRIMARY_SPECIES if $species eq 'Multi';
  return $species;
}

# TODO: Needs moving to viewconfig so we don't have to work it out each time
sub otherspecies {
  my $self         = shift;

  return $self->param('otherspecies') if $self->param('otherspecies');
  return $self->param('species') if $self->param('species');

  my $species_defs  = $self->species_defs;
  my $map           = $species_defs->multi_val('ENSEMBL_SPECIES_URL_MAP');
  my $species       = $species_defs->get_config($self->species, 'SPECIES_PRODUCTION_NAME');
  my $primary_sp    = $species_defs->get_config($species_defs->ENSEMBL_PRIMARY_SPECIES, 'SPECIES_PRODUCTION_NAME');
  my $secondary_sp  = $species_defs->get_config($species_defs->ENSEMBL_SECONDARY_SPECIES, 'SPECIES_PRODUCTION_NAME');
  my %synteny       = $species_defs->multi('DATABASE_COMPARA', 'SYNTENY');

  return $map->{$primary_sp} if ($synteny{$species}->{$primary_sp} and $primary_sp ne $species);

  return $map->{$secondary_sp} if ($synteny{$species}->{$secondary_sp} and $secondary_sp ne $species);

  my @has_synteny  = grep { $_ ne $species } sort keys %{$synteny{$species}};
  return $map->{$has_synteny[0]};
}

sub order_species_by_clade { # TODO - move to EnsEMBL::Web::Document::HTML::Compara::GeneTrees
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
    push @{$stn_by_name{$stn->genome_db->name}}, $stn;
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
    my @allowed_production_names = grep {$stn_by_name{$_}} map {$species_defs->get_config($_, 'SPECIES_PRODUCTION_NAME')} @$favourites;
    push @final_sets, ['Favourite species', [map {@{$stn_by_name{$_}}} @allowed_production_names]] if @allowed_production_names;
  }

  ## Output in taxonomic groups, ordered by common name
  foreach my $group_name (@group_order) {
      next unless exists $phylo_tree{$group_name};
      my $species_list = $phylo_tree{$group_name};
      my $name_to_use = ($group_name eq 'no_group') ? (scalar(@group_order) > 1 ? 'Other species' : 'All species') : encode_entities($group_name);
      my @sorted_by_common = sort { $species_info->{$a}->{'common'} cmp $species_info->{$b}->{'common'} } @$species_list;
      my @allowed_production_names = grep {$stn_by_name{$_}} map {$species_defs->get_config($_, 'SPECIES_PRODUCTION_NAME')} @sorted_by_common;
      push @final_sets, [$name_to_use, [map {@{$stn_by_name{$_}}} @allowed_production_names]] if @allowed_production_names;
  }

  return \@final_sets;
}

sub redirect { # TODO - move to Controller (do hub->store_records_if_needed inside Controller->redirect)
  ## Does an http redirect
  ## Since it actually throws a RedirectionRequired exception, code that follows this call will not get executed
  ## @param URL to redirect to
  ## @param Flag kept on if it's a permanent redirect
  my ($self, $url, $permanent) = @_;

  $url = $self->url($url) if $url && ref $url;

  $self->store_records_if_needed;

  $self->controller->redirect($url || $self->current_url, $permanent);
}


1;
