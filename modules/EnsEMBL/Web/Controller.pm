# $Id$

package EnsEMBL::Web::Controller;

use strict;

use Apache2::RequestUtil;
use CGI;

use Bio::EnsEMBL::Registry;

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::Builder;
use EnsEMBL::Web::Data::Record::History;
use EnsEMBL::Web::Document::Panel;
use EnsEMBL::Web::Tree;

use base qw(EnsEMBL::Web::Root);

sub new {
  my $class = shift;
  my $r     = shift || Apache2::RequestUtil->can('request') ? Apache2::RequestUtil->request : undef;
  my $args  = shift || {};
  my $input = new CGI;
  
  my $object_params = [
    [ 'Phenotype',           'ph'  ],
    [ 'Location',            'r'   ],
    [ 'Gene',                'g'   ],
    [ 'Transcript',          't'   ],
    [ 'Variation',           'v'   ],
    [ 'StructuralVariation', 'sv'  ],
    [ 'Regulation',          'rf'  ],
    [ 'Experiment',          'ex'  ],
    [ 'Marker',              'm'   ],
    [ 'LRG',                 'lrg' ],
    [ 'GeneTree',            'gt'  ],
  ];
  
  my $object_types    = { map { $_->[0] => $_->[1] } @$object_params };
  my $ordered_objects = [ map $_->[0], @$object_params ];
  
  my $hub = new EnsEMBL::Web::Hub({
    apache_handle  => $r,
    input          => $input,
    object_types   => $object_types,
    session_cookie => $args->{'session_cookie'},
    user_cookie    => $args->{'user_cookie'},
  });
  
  my $builder = new EnsEMBL::Web::Builder({
    hub             => $hub,
    object_params   => $object_params,
    object_types    => $object_types,
    ordered_objects => $ordered_objects
  });
  
  my $self = {
    r             => $r,
    input         => $input,
    hub           => $hub,
    builder       => $builder,
    cache         => $hub->cache,
    type          => $hub->type,
    action        => $hub->action,
    function      => $hub->function,
    command       => undef,
    filters       => undef,
    errors        => [],
    page_type     => 'Dynamic',
    renderer_type => 'String',
    %$args
  };
  
  bless $self, $class;
  
  my $species_defs = $hub->species_defs;
  
  $CGI::POST_MAX = $species_defs->CGI_POST_MAX; # Set max upload size
  
  if ($self->cache && $self->request ne 'modal') {
    # Add parameters useful for caching functions
    $self->{'session_id'}  = $hub->session->session_id;
    $self->{'user_id'}     = $hub->user;
    $self->{'url_tag'}     = $hub->url({ update_panel => undef }, undef, 1);
    $self->{'cache_debug'} = $species_defs->ENSEMBL_DEBUG_FLAGS & $species_defs->ENSEMBL_DEBUG_MEMCACHED;
    
    $self->set_cache_params;
  }
  
  $self->init;
  
  return $self;
}

sub init {}

sub r             { return $_[0]->{'r'};              }
sub input         { return $_[0]->{'input'};          }
sub hub           { return $_[0]->{'hub'};            }
sub builder       { return $_[0]->{'builder'};        }
sub cache         { return $_[0]->{'cache'};          }
sub errors        { return $_[0]->{'errors'};         }
sub type          { return $_[0]->hub->type;          }
sub action        { return $_[0]->hub->action;        }
sub function      { return $_[0]->hub->function;      }
sub species_defs  { return $_[0]->hub->species_defs;  }
sub object        { return $_[0]->builder->object;    }
sub page_type     { return $_[0]->{'page_type'};      }
sub renderer_type { return $_[0]->{'renderer_type'};  }
sub request       { return undef;                     }
sub cacheable     { return 0;                         }
sub node          :lvalue { $_[0]->{'node'};          }
sub command       :lvalue { $_[0]->{'command'};       }
sub filters       :lvalue { $_[0]->{'filters'};       }

sub renderer {
  my $self = shift;
  
  if (!$self->{'renderer'}) {
    my $renderer_module = 'EnsEMBL::Web::Document::Renderer::' . $self->renderer_type;
    
    ($self->{'renderer'}) = $self->_use($renderer_module, (
      r     => $self->r,
      cache => $self->cache
    ));
  }
  
  return $self->{'renderer'};
}

sub page {
  my $self       = shift;
  my $outputtype = $ENV{'HTTP_USER_AGENT'} =~ /Sanger Search Bot/ ? 'search_bot' : shift;
  
  if (!$self->{'page'}) {
    my $document_module = 'EnsEMBL::Web::Document::Page::' . $self->page_type;
    
    ($self->{'page'}) = $self->_use($document_module, {
      input        => $self->input,
      hub          => $self->hub, 
      species_defs => $self->species_defs, 
      renderer     => $self->renderer,
      outputtype   => $outputtype
    });
  }
  
  return $self->{'page'};
}

sub configuration {
  my $self = shift;
  my $hub  = $self->hub;
  
  if (!$self->{'configuration'}) {
    my $conf = {
      tree         => new EnsEMBL::Web::Tree,
      default      => undef,
      action       => undef,
      configurable => 0,
      page_type    => $self->page_type
    };
    
    my $module_name = 'EnsEMBL::Web::Configuration::' . $hub->type;
    my ($configuration, $error) = $self->_use($module_name, $self->page, $hub, $self->builder, $conf);
    
    if ($error) {
      # Handle "use" failures gracefully, but skip "Can't locate" errors
      $self->add_error( 
        'Configuration module compilation error',
        '<p>Unable to use Configuration module <strong>%s</strong> due to the following error:</p><pre>%s</pre>',
        $module_name, $error
      );
    }
    
    $self->{'configuration'} = $configuration;
  }
  
  return $self->{'configuration'};
}

sub configure {
  my $self          = shift;
  my $hub           = $self->hub;
  my $configuration = $self->configuration;
  my $node          = $configuration->get_node($configuration->get_valid_action($self->action, $self->function));
  
  if ($node) {
    $self->node    = $node;
    $self->command = $node->data->{'command'};
    $self->filters = $node->data->{'filters'};
  }
  
  if ($hub->object_types->{$hub->type}) {
    $hub->components = $configuration->get_configurable_components($node);
  } elsif ($self->request eq 'modal') {
    my $referer     = $hub->referer;
    my $module_name = "EnsEMBL::Web::Configuration::$referer->{'ENSEMBL_TYPE'}";
    
    $hub->components = $module_name->new_for_components($hub, { tree => new EnsEMBL::Web::Tree }, $referer->{'ENSEMBL_ACTION'}, $referer->{'ENSEMBL_FUNCTION'}) if $self->dynamic_use($module_name);
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
  
  foreach my $element (@order) {
    my $module = $elements->{$element};
    $module->init($self) if $module->can('init');
  }
  
  foreach my $element (@order) {
    my $module = $elements->{$element};
    $content->{$element} = $module->$func();
  }
  
  my $page_content = $page->render($content);
  
  $self->set_cached_content($page_content) if $self->page_type =~ /^(Static|Dynamic)$/ && $page->{'format'} eq 'HTML' && !$self->hub->has_a_problem;
}

sub update_user_history {
  my $self            = shift;
  my $hub             = $self->hub;
  my $user            = $hub->user;
  my $referer         = $hub->referer;
  my $referer_type    = $referer->{'ENSEMBL_TYPE'};
  my $referer_species = $referer->{'ENSEMBL_SPECIES'};
  my $param           = $hub->object_types->{$referer_type};
  
  if ($referer_type && $param) {
    my @type_history = grep $_->{'object'} eq $referer_type, $user->histories;
    my $value        = shift || $referer->{'params'}->{$param}->[0];
    my $name         = $self->species_defs->get_config($referer_species, 'SPECIES_COMMON_NAME');
    
    if ($referer_type =~ /^(Gene|Transcript)$/) {
      my $db           = $referer->{'params'}->{'db'}->[0] || 'core';
      $db              = 'otherfeatures' if $db eq 'est';
      my $func         = "get_${referer_type}Adaptor";
      my $feature      = $hub->get_adaptor($func, $db, $referer_species)->fetch_by_stable_id($value);
      my $display_xref = $feature ? $feature->display_xref : undef;
      
      $name .= ': ' . ($display_xref ? $display_xref->display_id : $value);
    } else {
      $name .= $name ? ": $value" : $value;
    }
    
    my $name_check = grep { $_->{'name'} eq $name } @type_history;
    
    if ($value && !$name_check && !($referer_type eq $self->type && $hub->param($param) eq $value)) {
      my $history = new EnsEMBL::Web::Data::Record::History::User({ user_id => $user->id });
      $history->name($name);
      $history->species($referer_species);
      $history->object($referer_type);
      $history->param($param);
      $history->value($value);
      $history->url($referer->{'absolute_url'});
      $history->save;
      
      ## Limit to 5 entries per object type
      shift(@type_history)->delete while scalar @type_history >= 5; 
    }
  }
}

sub set_cache_params {
  my $self = shift;
  my $hub  = $self->hub;
  my %tags = (
    url       => $self->{'url_tag'},
    page_type => $self->page_type,
  );
  
  $tags{'session'} = "SESSION[$self->{'session_id'}]" if $self->{'session_id'};
  $tags{'user'}    = "USER[$self->{'user_id'}]"       if $self->{'user_id'};
  $tags{'mac'}     = 'MAC'                            if $ENV{'HTTP_USER_AGENT'} =~ /Macintosh/;
  $tags{'ie'}      = "IE$1"                           if $ENV{'HTTP_USER_AGENT'} =~ /MSIE (\d+)/;
  $tags{'bot'}     = 'BOT'                            if $ENV{'HTTP_USER_AGENT'} =~ /Sanger Search Bot/;
  $tags{'ajax'}    = 'NO_AJAX'                        unless $hub->check_ajax;
  
  $ENV{'CACHE_KEY'}  = join '::', map $tags{$_} || (), qw(url page_type session user mac ie bot ajax);
  $ENV{'CACHE_KEY'} .= join '::', '', map $_->name =~ /^toggle_/ ? sprintf '%s[%s]', $_->name, $_->value : (), values %{$hub->cookies};
  
  if ($self->request !~ /^(page|ssi)$/) {
    my $referer = $hub->referer;
    (my $tag    = $referer->{'uri'}) =~ s/\?.+/?/;
    my @params;
    
    foreach my $p (sort keys %{$referer->{'params'}}) {
      push @params, "$p=$_" for @{$referer->{'params'}{$p}};
    }
    
    $tag .= join ';', @params;
    $tags{'referer'} = $tag if $tag;
  }
  
  
  $ENV{'CACHE_TAGS'}{$_} = $tags{$_} for keys %tags;  
}

sub get_cached_content {
  ### Attempt to retrieve page and component requests from Memcached
  
  my ($self, $type) = @_;
  
  my $cache = $self->cache;
  my $r     = $self->r;
  
  return unless $cache;
  return if $r->method eq 'POST';
  return unless $type eq 'page';
  
  my $content = $cache->get($ENV{'CACHE_KEY'}, values %{$ENV{'CACHE_TAGS'}});
  
  if ($content) {
    $r->headers_out->set('X-MEMCACHED' => 'yes');     
    $r->content_type('text/html');
    
    print $content;
    
    warn "CONTENT CACHE HIT:  $ENV{'CACHE_KEY'}" if $self->{'cache_debug'};
  } else {
    warn "CONTENT CACHE MISS: $ENV{'CACHE_KEY'}" if $self->{'cache_debug'};
  }
  
  return !!$content;
}

sub set_cached_content {
  ### Attempt to add page and component requests to Memcached
  
  my ($self, $content) = @_;
  
  my $cache = $self->cache;
  
  return unless $cache && $self->cacheable;
  return unless $ENV{'CACHE_KEY'};
  return if $self->r->method eq 'POST';
  
  $cache->set($ENV{'CACHE_KEY'}, $content, 60*60*24*7, values %{$ENV{'CACHE_TAGS'}});
  
  warn "CONTENT CACHE SET:  $ENV{'CACHE_KEY'}" if $self->{'cache_debug'};
}

sub clear_cached_content {
  ### Flush the cache if the user has hit ^R or F5.
  ### Removes content from Memcached based on the request's URL and the user's session id.
  
  my $self  = shift;
  my $cache = $self->cache;
  my $r     = $self->r;
  
  if ($cache && $r->headers_in->{'Cache-Control'} =~ /(max-age=0|no-cache)/ && $r->method ne 'POST') {
    my @tags = ($self->{'url_tag'});
    
    if ($self->request eq 'ssi') {
      push @tags, "USER[$self->{'user_id'}]" if $self->{'user_id'};
    } else {
      push @tags, "SESSION[$self->{'session_id'}]" if $self->{'session_id'};
    }
    
    $cache->delete_by_tags(@tags);
    
    warn 'CONTENT CACHE CLEAR: ' . (join ', ', @tags) if $self->{'cache_debug'};
  }
}

sub add_error {
 ### Wrapper for add_panel
 
 my ($self, $caption, $template, @content) = @_;
 my $error = $self->_format_error(pop @content);
 push @{$self->errors}, new EnsEMBL::Web::Document::Panel(caption => $caption, content => sprintf($template, @content, $error));
}

sub _use {
  ### Wrapper for EnsEMBL::Web::Root::dynamic_use.
  ### Returns either a newly created module or the error detailing why the new function failed.
  ### Skips "Can't locate" errors - these come from trying to use non-existant modules in plugin directories and can be safely ignored.
  
  my $self        = shift;
  my $module_name = shift;
  
  my $module = $self->dynamic_use($module_name) && $module_name->can('new') ? $module_name->new(@_) : undef;
  my $error;
  
  if (!$module) {
    $error = $self->dynamic_use_failure($module_name);
    $error = undef if $error =~ /^Can't locate/;
  }
  
  return ($module, $error);
}

sub DESTROY { Bio::EnsEMBL::Registry->disconnect_all; }

1;
