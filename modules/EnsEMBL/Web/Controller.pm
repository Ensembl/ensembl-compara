=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Controller;

use strict;
use warnings;

use URI;
use List::MoreUtils qw(uniq);

use Bio::EnsEMBL::Registry;

use EnsEMBL::Web::Attributes;
use EnsEMBL::Web::Builder;
use EnsEMBL::Web::Exceptions qw(RedirectionRequired);
use EnsEMBL::Web::Hub;
use EnsEMBL::Web::Document::Panel;
use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_require);

use base qw(EnsEMBL::Web::Root);

my @HANDLES_TO_DISCONNECT;

sub r             :Accessor;
sub hub           :Accessor;
sub species_defs  :Accessor;
sub species       :Accessor;
sub path_segments :Accessor;
sub query         :Accessor;
sub filename      :Accessor;
sub type          :Accessor;
sub action        :Accessor;
sub function      :Accessor;
sub sub_function  :Accessor;
sub page_type     :Accessor;
sub request       :Accessor;
sub renderer_type :Accessor;
sub init          :Abstract;

sub node          :lvalue { $_[0]->{'node'};          }
sub command       :lvalue { $_[0]->{'command'};       }
sub filters       :lvalue { $_[0]->{'filters'};       }

sub new {
  ## @constructor
  ## @param Apache2::RequestRec object
  ## @param SpeciesDefs object
  ## @param Hashref with following keys (as required by the sub classes being instantiated)
  ##  - species       : Species name (string)
  ##  - path_segments : Arrayref of path segments
  ##  - query         : Query part of the url (string)
  ##  - filename      : Name of the file to be served (for static file request)
  my ($class, $r, $species_defs, $params) = @_;

  # Temporary
  if (!UNIVERSAL::isa($r // '', 'Apache2::RequestRec') || !UNIVERSAL::isa($species_defs // '', 'EnsEMBL::Web::SpeciesDefs')) {
    #use Carp qw(cluck);
    #cluck('Invalid parameters');
  }

  my $self = bless {
    'r'             => $r,
    'species_defs'  => $species_defs,
    'cache_debug'   => $species_defs->ENSEMBL_DEBUG_CACHE || 0,
    'page_type'     => 'Dynamic',
    'renderer_type' => 'String',
    'species'       => $params->{'species'}       || '',
    'path_segments' => $params->{'path_segments'} || [],
    'query'         => $params->{'query'}         || '',
    'filename'      => $params->{'filename'}      || '',
    'type'          => '',
    'action'        => '',
    'function'      => '',
    'sub_function'  => '',
    'request'       => '',
    'errors'        => []
  }, $class;

  $self->parse_path_segments; # populate type, action, function and sub_function

  $self->{'hub'} = EnsEMBL::Web::Hub->new($self);

  return $self;
}

sub process {
  ## Generates the response
  my $self  = shift;
  my $hub   = $self->hub;

  $self->init_cache;
  $hub->qstore_open;
  my $err;
  try {
    $self->init;
  } catch {
    $err = $_;
  };
  $hub->qstore_close;
  throw $err if $err;
  $hub->store_records_if_needed;
}

sub update_user_history {
  ## Updates history record for the current session
  ## Used by child classes only
  #TODO
}

sub query_form {
  ## Parse the query string in a hash
  ## @return Hashref extracted from URL GET params
  my $self = shift;

  return $self->{'query_form'} ||= _parse_query_form($self->query);
}

sub query_param {
  ## Gets the value(s) of a GET parameter
  ## @return List of all values in list context, only first value in scalar context
  my ($self, $key)  = @_;
  my $query_form    = $self->query_form;
  my $all_values    = $query_form->{$key} || [];

  return wantarray ? @$all_values : $all_values->[0];
}

sub object_params {
  ## @return The OBJECT_PARAMS from species defs
  my $self = shift;
  $self->{'object_params'} ||= $SiteDefs::OBJECT_PARAMS;
}

sub parse_path_segments {
  ## Parses path segments to identify type, action and function
  my $self = shift;

  ($self->{'type'}, $self->{'action'}, $self->{'function'}, $self->{'sub_function'}) = (@{$self->path_segments}, '', '', '', '');
}

sub cacheable {
  ## Returns true if the current request can be retrieved from cache and should be cached for future requests
  my $self  = shift;
  my $r     = $self->r;

  return $self->{'cacheable'} //= $r->method eq 'GET' ? 1 : 0;
}

sub init_cache {
  ## Initalises the cache tags and cache key
  my $self  = shift;
  my $hub   = $self->hub;

  return unless $hub->cache && $self->cacheable;

  my $agent = $self->r->subprocess_env('HTTP_USER_AGENT');
  my $query = $self->query_form;

  # init env cache tags
  $ENV{'CACHE_TAGS'} = {};

  $self->add_cache_tags({'species' => sprintf('SPECIES[%s]', $self->species)}) if $self->species;

  $self->add_cache_tags({
    'page'    => sprintf('PAGE[%s]', $self->page_type),
    'path'    => sprintf('PATH[%s]', join('/', @{$self->path_segments})),
    'query'   => sprintf('Q[%s]', join(';', sort map sprintf('%s=%s', $_, join(',', sort @{$query->{$_}})), keys %$query) || ''), # stringify the url query hash
    'session' => sprintf('SESSION[%s]', $hub->session),
    'mac'     => $agent =~ /Macintosh/ ? 'MAC' : '',
    'ie'      => $agent =~ /MSIE (\d+)/ ? "IE_$1" : '',
    'bot'     => $agent =~ /Sanger Search Bot/ ? 'BOT' : '',
  });

  $self->cache_key; # set $ENV{'CACHE_KEY'}
}

sub cache_key {
  ## Gets the cache keys for the current request
  ## @return String
  my $self = shift;
  return $ENV{'CACHE_KEY'} ||= join '::', @{$self->cache_tags};
}

sub cache_tags {
  ## Returns list of cache tags for the current request
  ## @return Arrayref
  my $self = shift;

  return [ sort grep $_, values %{$ENV{'CACHE_TAGS'} || {}} ];
}

sub add_cache_tags {
  ## Adds given tags to the set of tags that are used to save/retrieve the request
  ## @param Hashref of the tags (keys of the hash are just for reference but values are actually used as a list of cache tags)
  my ($self, $tags) = @_;

  $ENV{'CACHE_TAGS'}{$_} = $tags->{$_} // '' for keys %$tags;
}

sub remove_cache_tags {
  ## Removes given or all tags from the set of tags that are used to save/retrieve the request
  ## @params List of tags to be removed (no argument will remove all tags)
  my $self = shift;

  delete $ENV{'CACHE_TAGS'}{$_} for @_;
}

sub get_cached_content {
  ## Attempts to retrieve content cached for a similar requests from Memcached
  ## The already computed cache key is used to retrieve content
  my $self      = shift;
  my $cache     = $self->hub->cache;
  my $cache_key = $self->cache_key;

  return unless $cache && $cache_key && $self->cacheable;

  my $content = $cache->get($cache_key, @{$self->cache_tags});

  # leave an entry in log if required
  warn sprintf 'CACHE %s %s', $content ? 'HIT:  ' : 'MISS: ', $cache_key if $self->{'cache_debug'};

  return $content;
}

sub set_cached_content {
  ## Adds content of the current request to Memcached against the already computed cache key
  my ($self, $content) = @_;
  my $cache     = $self->hub->cache;
  my $cache_key = $self->cache_key;

  return unless $cache && $cache_key && $self->cacheable;

  $cache->set($cache_key, $content, 60 * 60 *24 * 7 * 12, @{$self->cache_tags});

  # leave an entry in logs
  warn sprintf 'CACHE SET:   %s', $cache_key if $self->{'cache_debug'};
}

sub clear_cached_content {
  ## Flush the cache if the user has hit ^R or F5.
  ## Removes content from Memcached based on the already computed cache key
  my $self      = shift;
  my $cache     = $self->hub->cache;
  my $cache_key = $self->cache_key;

  return unless $cache && $cache_key && $self->cacheable;

  # delete cache if request by the user
  my $cache_header = $self->r->headers_in->{'Cache-Control'} || '';
  if ($cache_header =~ /(max-age=0|no-cache)/) {
    $cache->delete_by_tags(@{$self->cache_tags});
  }

  # leave an entry in logs
  warn sprintf 'CACHE CLEAR: %s', $cache_key if $self->{'cache_debug'};
}

sub redirect {
  ## Does an http redirect
  ## Since it actually throws an exception, code that follows this call will not get executed
  ## @param URL to redirect to
  ## @param Flag kept on if it's a permanent redirect
  my ($self, $url, $permanent) = @_;

  throw RedirectionRequired({'url' => $url, 'permanent' => $permanent});
}

sub upload_size_limit {
  ## Upload size limit for post requests
  return shift->species_defs->CGI_POST_MAX;
}

sub builder {
  ## Returns a cached or new builder instance
  ## @return EnsEMBL::Web::Builder instance
  my $self = shift;

  return $self->{'builder'} ||= EnsEMBL::Web::Builder->new($self->hub, $self->object_params);
}

sub renderer {
  ## Returns required renderer instance according to the renderer type
  ## @return Instance of subclass of EnsEMBL::Web::Document::Renderer
  my $self = shift;

  return $self->{'renderer'} ||= dynamic_require('EnsEMBL::Web::Document::Renderer::'.$self->renderer_type)->new(
    r     => $self->r,
    cache => $self->hub->cache
  );
}

sub page {
  my $self       = shift;
  my $outputtype = $ENV{'HTTP_USER_AGENT'} =~ /Sanger Search Bot/ ? 'search_bot' : shift;

  if (!$self->{'page'}) {
    my $document_module = 'EnsEMBL::Web::Document::Page::' . $self->page_type;

    ($self->{'page'}) = $self->_use($document_module, {
      input        => $self->hub->input,
      hub          => $self->hub,
      species_defs => $self->species_defs,
      renderer     => $self->renderer,
      outputtype   => $outputtype
    });
  }

  return $self->{'page'};
}

sub referer {
  ## Gets the referer for the current request
  ## @param Flag if on will return referer string without parsing it
  ## @return Referer object (parsed) or referer string (unparsed)
  my ($self, $unparsed) = @_;

  $self->{'referer_string'} ||= $self->r->headers_in->{'Referer'};
  return $self->{'referer_string'} if $unparsed;

  return {} unless $self->{'referer_string'};

  unless (exists $self->{'referer'}) {

    my $referer       = {'absolute_url' => $self->{'referer_string'}};
    my $species_defs  = $self->species_defs;
    my $servername    = $species_defs->ENSEMBL_SERVERNAME;
    my $server        = $species_defs->ENSEMBL_SERVER;
    my $uri           = URI->new($self->{'referer_string'});

    my $path  = $uri->path;
    my $query = $uri->query;
    my $host  = $uri->authority;
    my @path  = grep $_, split '/', $path;

    if ($host !~ /$servername/i && $host !~ /$server/ && $path !~ m!/Tools/!) {## Why Tools?
      $referer->{'external'} = 1;

    } else {
      unshift @path, 'Multi' unless $path[0] eq 'Multi' || $species_defs->valid_species($path[0]);

      $referer->{'external'}  = 0;
      $referer->{'uri'}       = join '?', $path, $query || ();
      $referer->{'params'}    = _parse_query_form($query || '');

      # dynamic page
      if ($species_defs->OBJECT_TO_CONTROLLER_MAP->{$path[1]}) {
        my ($species, $type, $action, $function) = @path;
        $referer->{'ENSEMBL_SPECIES'}  = $species   || '';
        $referer->{'ENSEMBL_TYPE'}     = $type      || '';
        $referer->{'ENSEMBL_ACTION'}   = $action    || '';
        $referer->{'ENSEMBL_FUNCTION'} = $function  || '';
      }
    }

    $self->{'referer'} = $referer;
  }

  return $self->{'referer'};
}

sub is_ajax_request {
  ## Checks if the request is an AJAX request
  ## @return 1 or 0 accordingly
  my $self = shift;
  return 1 if (($self->r->headers_in->{'X-Requested-With'} || '') eq 'XMLHttpRequest');
  return 1 if (($self->query_param('X-Requested-With') || '') eq 'iframe');
  return 0;
}

sub configuration_name {
  ## Gets name of the component configuration class to be used for the request
  ## @return EnsEMBL::Web::Configuration subclass name
  my $self = shift;

  return 'EnsEMBL::Web::Configuration::' . $self->hub->type;
}

sub configuration {
  ## Initialises and returns the Configuration object for the request
  ## @return EnsEMBL::Web::Configuration subclass instance
  my $self = shift;
  my $hub  = $self->hub;

  if (!exists $self->{'configuration'}) {

    my $module;

    try {
      $module = dynamic_require($self->configuration_name);
    } catch {
      throw $_ unless $_->type eq 'ModuleNotFound';
    };

    $self->{'configuration'} = $module ? $module->new($self->page, $hub, $self->builder, {
      default      => undef,
      action       => undef,
      configurable => 0,
      page_type    => $self->page_type
    }) : undef;
  }

  return $self->{'configuration'};
}

sub configure {
  my $self          = shift;
  my $hub           = $self->hub;
  my $configuration = $self->configuration;

  my $assume_valid = 0;
  $assume_valid = 1 if $hub->script eq 'Component';
  my $node          = $configuration->get_node($configuration->get_valid_action($self->action, $self->function,$assume_valid));
  my $template;

  if ($node) {
    $self->node    = $node;
    $self->command = $node->get_data('command');
    $self->filters = $node->get_data('filters');
    $template      = $node->get_data('template') || $configuration->default_template;
  }
  $template ||= 'Legacy';  
  $hub->template($template);

  if ($hub->object_types->{$hub->type}) {
    $hub->add_components(@{$configuration->get_configurable_components($node)});
  } elsif ($self->request eq 'modal') {
    my $referer     = $self->referer;

    if ($referer->{'ENSEMBL_TYPE'} && (my $module_name = dynamic_require("EnsEMBL::Web::Configuration::$referer->{'ENSEMBL_TYPE'}", 1))) {
      $hub->add_components(@{$module_name->new_for_components($hub, $referer->{'ENSEMBL_ACTION'}, $referer->{'ENSEMBL_FUNCTION'})});
    }
  }
}

sub render_page {
  my $self     = shift;
  my $page     = $self->page;
  my $hub      = $self->hub;
  my $func     = $self->renderer->{'_modal_dialog_'} ? 'get_json' : 'content';
  my $elements = $page->elements;
  my @order    = map $_->[0], @{$page->head_order}, @{$page->body_order};
  my $content  = {};

  foreach my $element (uniq(@order)) {
    my $module = $elements->{$element};
    $module->init($self) if ($module && $module->can('init'));
  }

  foreach my $element (@order) {
    my $module = $elements->{$element};
    $content->{$element} = $module->$func() if $module && $module->can($func);
  }

  my $page_content = $page->render($content);

  $self->set_cached_content($page_content) if $self->page_type =~ /^(Static|Dynamic)$/ && $page->{'format'} eq 'HTML' && !$self->hub->has_a_problem;
}

sub add_error {
 ### Wrapper for add_panel

 my ($self, $caption, $template, @content) = @_;
 my $error = $self->_format_error(pop @content);
 push @{$self->errors}, EnsEMBL::Web::Document::Panel->new(caption => $caption, content => sprintf($template, @content, $error));
}

sub save_config {
  my ($self, $view_config, $image_config, %params) = @_;
  my $hub       = $self->hub;
  my $user      = $hub->user;
  my %groups    = $user ? map { $_->group_id => $_->name } $user->find_admin_groups : ();
  my $adaptor   = $hub->config_adaptor;
  my $configs   = $adaptor->all_configs;
  my $overwrite = $hub->param('overwrite');
     $overwrite = undef unless exists $configs->{$overwrite}; # check that the overwrite id belongs to this user
  my (%existing, $existing_config);

  if ($overwrite) {
    foreach my $id ($overwrite, $configs->{$overwrite}{'link_key'} || ()) {
      $existing{$configs->{$id}{'type'}} = { config_key => $id };
      $params{$_} ||= $configs->{$id}{$_} for qw(record_type record_type_id name description);
      push @{$params{'set_keys'}}, $adaptor->record_to_sets($id);
    }
  }

  my $record_type_ids = delete $params{'record_type_ids'};

  foreach my $record_type_id (ref $record_type_ids eq 'ARRAY' ? @$record_type_ids : $record_type_ids) {
    my (@links, $saved_config);

    foreach (qw(view_config image_config)) {
      ($params{'code'}, $params{'link'}) = $_ eq 'view_config' ? ($view_config, [ 'image_config', $image_config ]) : ($image_config, [ 'view_config', $view_config ]);

      my ($saved, $deleted) = $adaptor->save_config(%params, %{$existing{$_} || {}}, type => $_, record_type_id => $record_type_id, data => $adaptor->get_config($_, $params{'code'}));

      push @links, { id => $saved, code => $params{'code'}, link => $params{'link'}, set_keys => $params{'set_keys'} };

      if ($deleted) {
        push @{$existing_config->{'deleted'}}, $deleted;
      } elsif ($saved) {
        my $conf = $configs->{$saved};

         # only provide one saved entry for a linked pair
        $saved_config ||= {
          value => $saved,
          class => $saved,
          html  => $conf->{'name'} . ($user ? sprintf(' (%s%s)', $conf->{'record_type'} eq 'user' ? 'Account' : ucfirst $conf->{'record_type'}, $conf->{'record_type'} eq 'group' ? ": $groups{$record_type_id}" : '') : '')
        };
      }
    }

    push @{$existing_config->{'saved'}}, $saved_config if $saved_config;

    $adaptor->link_configs(@links);
  }

  $existing_config->{'saved'} = [ grep !$configs->{$_->{'value'}}{'link_key'}, @{$existing_config->{'saved'}} ] if $overwrite;

  return $existing_config;
}

sub _parse_query_form {
  ## @private
  my $query = shift;

  my $q = {};
  my @p = URI->new(sprintf '?%s', $query)->query_form;

  while (my ($key, $val) = splice @p, 0, 2) {
    next if $key eq 'time' || $key eq '_'; # ignore params added to clear browser cache by the frontend - they don't clear any backend cache
    push @{$q->{$key}}, $val;
  }

  return $q;
}

sub _use {
  ### Wrapper for EnsEMBL::Root::dynamic_use.
  ### Returns either a newly created module or the error detailing why the new function failed.
  ### Skips "Can't locate" errors - these come from trying to use non-existant modules in plugin directories and can be safely ignored.

  my $self        = shift;
  my $module_name = shift;

  my $module = $self->dynamic_use($module_name) && $module_name->can('new') ? $module_name->new(@_) : undef;
  my $error;

  if (!$module) {
    $error = $self->dynamic_use_failure($module_name);
    $error = undef if ($error && $error =~ /^Can't locate/);
  }

  return ($module, $error);
}

sub disconnect_on_request_finish {
  my ($class, $handle) = @_;
  return unless $SiteDefs::TIDY_USERDB_CONNECTIONS;
  push @HANDLES_TO_DISCONNECT, $handle;
}

sub DESTROY {
  Bio::EnsEMBL::Registry->disconnect_all;
  $_->disconnect || warn $_->errstr for @HANDLES_TO_DISCONNECT;
}



sub OBJECT_PARAMS :Deprecated('use object_params') { return  $SiteDefs::OBJECT_PARAMS; }
sub input         :Deprecated('use hub->input')    { return $_[0]->hub->input;    }
sub errors        :Deprecated('Use EnsEMBL::Web::Exceptions for error handling') { return $_[0]->{'errors'}; }
sub object        :Deprecated('Use builder->object') { return $_[0]->builder->object; }


1;
