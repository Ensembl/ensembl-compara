# $Id$

package EnsEMBL::Web::Document::HTML;

use strict;

use EnsEMBL::Web::Document::Panel;
use LWP::UserAgent;

use base qw(EnsEMBL::Web::Root);

sub new {
  my $class = shift;
  
  my $self = { 
    _renderer => undef,
    @_
  };
  
  bless $self, $class;
  
  return $self;
}

sub renderer :lvalue { $_[0]->{'_renderer'}; }
sub species_defs     { return $_[0]->{'species_defs'}; }

sub printf { my $self = shift; $self->renderer->printf(@_) if $self->renderer; }
sub print  { my $self = shift; $self->renderer->print(@_)  if $self->renderer; }

sub render {}

sub new_panel {
  my ($self, $panel_type, $controller, %params) = @_;
  
  my $module_name = 'EnsEMBL::Web::Document::Panel';
  $module_name.= "::$panel_type" if $panel_type;
  
  $params{'code'} =~ s/#/$self->{'flag'}||0/eg;

  if ($panel_type && !$self->dynamic_use($module_name)) {
    my $error = $self->dynamic_use_failure($module_name);
    
    if ($error =~ /^Can't locate/) {
      $error = qq{<p>Unrecognised panel type "<b>$panel_type</b>"};
    } else {
      $error = sprintf '<p>Unable to compile <strong>%s</strong></p><pre>%s</pre>', $module_name, $self->_format_error($error);
    }
    
    push @{$controller->errors},
      new EnsEMBL::Web::Document::Panel(
        hub        => $controller->hub,
        builder    => $controller->builder,
        object     => $controller->object,
        code       => "error_$params{'code'}",
        caption    => 'Panel compilation error',
        content    => $error,
        has_header => $params{'has_header'},
      );
    
    return undef;
  }
  
  my $panel;
  
  eval {
    $panel = $module_name->new(
      builder => $controller->builder, 
      hub     => $controller->hub,
      object  => $controller->object,
      %params
    );
  };
  
  return $panel unless $@;
  
  push @{$controller->errors},
    new EnsEMBL::Web::Document::Panel(
      hub     => $controller->hub,
      builder => $controller->builder,
      object  => $controller->object,
      code    => "error_$params{'code'}",
      caption => "Panel runtime error",
      content => sprintf ('<p>Unable to compile <strong>%s</strong></p><pre>%s</pre>', $module_name, $self->_format_error($@))
    );
  
  return undef;
}

sub get_rss_feed {
  my ($self, $hub, $rss_url) = @_;
  if (!$hub || !$rss_url) {
    return [];
  }

  ## Does this feed work best with XML::Atom or XML:RSS? 
  my $rss_type = $rss_url =~ /atom/ ? 'atom' : 'rss';

  my $ua = new LWP::UserAgent;
  my $proxy = $hub->species_defs->ENSEMBL_WWW_PROXY;
  $ua->proxy( 'http', $proxy ) if $proxy;
  $ua->timeout(5);

  my $response = $ua->get($rss_url);
  my $items = [];

  if ($response->is_success) {
    my $count = 0;
    if ($rss_type eq 'atom' && $self->dynamic_use('XML::Atom::Feed')) {
      my $feed = XML::Atom::Feed->new(\$response->decoded_content);
      my @entries = $feed->entries;
      foreach my $entry (@entries) {
        my ($link) = grep { $_->rel eq 'alternate' } $entry->link;
        my $date  = $self->pretty_date(substr($entry->published, 0, 10), 'daymon');
        my $item = {
              'title'   => $entry->title,
              'content' => $entry->content,
              'link'    => $link->href,
              'date'    => $date,
        };
        push @$items, $item;
        $count++;
        last if $count == 3;
      }
    }
    elsif ($rss_type eq 'rss' && $self->dynamic_use('XML::RSS')) {
      my $rss = XML::RSS->new;
      $rss->parse($response->decoded_content);
      foreach my $entry (@{$rss->{'items'}}) {
        my $date = substr($entry->{'pubDate'}, 5, 11);
        my $item = {
          'title'   => $entry->{'title'},
          'content' => $entry->{'http://purl.org/rss/1.0/modules/content/'}{'encoded'},
          'link'    => $entry->{'link'},
          'date'    => $date,
        };
        push @$items, $item;
        $count++;
        last if $count == 3;
      }
    }
    else {
      warn "!!! UNKNOWN RSS METHOD DEFINED";
    }
  }
  else {
    warn "!!! COULD NOT GET RSS FEED from $rss_url";
  }

  return $items;
}

1;
