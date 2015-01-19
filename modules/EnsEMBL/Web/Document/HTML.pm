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

package EnsEMBL::Web::Document::HTML;

use strict;

use EnsEMBL::Web::Document::Panel;
use EnsEMBL::Web::Hub;
use EnsEMBL::Web::DBSQL::ArchiveAdaptor;
use LWP::UserAgent;

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $hub) = @_;

  return bless {
    _hub      => $hub || EnsEMBL::Web::Hub->new,
    _renderer => undef,
  }, $class;
}

sub renderer      :lvalue { $_[0]->{'_renderer'}; }
sub hub           { return $_[0]->{'_hub'}; }

sub printf        { my $self = shift; $self->renderer->printf(@_) if $self->renderer; }
sub print         { my $self = shift; $self->renderer->print(@_)  if $self->renderer; }

sub render        {}

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
      EnsEMBL::Web::Document::Panel->new(
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
    EnsEMBL::Web::Document::Panel->new(
      hub     => $controller->hub,
      builder => $controller->builder,
      object  => $controller->object,
      code    => "error_$params{'code'}",
      caption => "Panel runtime error",
      content => sprintf ('<p>Unable to compile <strong>%s</strong></p><pre>%s</pre>', $module_name, $self->_format_error($@))
    );
  
  return undef;
}

sub news_header {
  my ($self, $hub, $release_id) = @_;
  my $header_text;

  if ($hub->species_defs->ENSEMBL_SUBTYPE && $hub->species_defs->ENSEMBL_SUBTYPE eq 'GRCh37') {
    $header_text = 'Ensembl GRCh37';
  }
  else {
    my $sitename = join(' ', $hub->species_defs->ENSEMBL_SITETYPE, $hub->species_defs->ENSEMBL_SUBTYPE);
    my $adaptor = EnsEMBL::Web::DBSQL::ArchiveAdaptor->new($hub);
    my $release      = $adaptor->fetch_release($release_id);
    my $release_date = $release->{'date'};
    $header_text = sprintf('%s Release %s (%s)', $sitename, $release_id, $release_date);
  }
  return $header_text;
}

sub get_rss_feed {
  my ($self, $hub, $rss_url, $limit) = @_;
  if (!$hub || !$rss_url) {
    return [];
  }

  ## Does this feed work best with XML::Atom or XML:RSS? 
  my $rss_type = $rss_url =~ /atom/ ? 'atom' : 'rss';

  my $ua = LWP::UserAgent->new;
  my $proxy = $hub->species_defs->ENSEMBL_WWW_PROXY;
  $ua->proxy( 'http', $proxy ) if $proxy;
  #$ua->timeout(5);

  my $response = $ua->get($rss_url);
  my $items = [];

  eval {
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
          last if ($limit && $count == $limit);
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
          last if ($limit && $count == $limit);
        }
      }
      else {
        warn "!!! UNKNOWN RSS METHOD DEFINED";
      }
    }
    else {
      warn "!!! COULD NOT GET RSS FEED from $rss_url: ".$response->code.' ('.$response->message.')';
    }
  };
  if($@) {
    warn "Error parsing blog: $@\n";
  }
  return $items;
}

1;
