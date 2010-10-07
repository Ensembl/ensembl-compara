# $Id$

package EnsEMBL::Web::Document::Renderer::Assembler;

use strict;

use LWP::Parallel;
use LWP::Parallel::UserAgent;

use base qw(EnsEMBL::Web::Document::Renderer);

sub new {
  my $class = shift;
  my $self  = $class->SUPER::new(content => [], @_);
  return $self;
}

sub printf  { push @{shift->{'content'}}, sprintf shift, @_; }
sub print   { push @{shift->{'content'}}, @_; }
sub content { return join '', @{shift->{'content'}} }

sub close {
  my $self = shift;

  my $agent = new LWP::Parallel::UserAgent;

  foreach my $request (@{$self->{'content'}}) {
    next unless ref $request;

    my $content;

    if ($self->cache) {
      ## Check the cache
      my $key = $request->uri->path_query;
      $key   .= '::SESSION[' . $self->session->session_id . ']' if $self->session && $self->session->session_id;
      $key   .= "::WIDTH[$ENV{ENSEMBL_IMAGE_WIDTH}]" if $ENV{'ENSEMBL_IMAGE_WIDTH'};

      $content = $self->cache->get($key);
    }

    if ($content) {
      $request = $content;
    } else {
      $request->header(
        Cookie  => $self->r->headers_in->{'Cookie'},
        Referer => $request->uri->scheme . '://' . $request->uri->host_port . $ENV{'REQUEST_URI'},
      );
      
      $agent->register($request);
    }
  }

  my $entries = $agent->wait;
  
  $_ = $entries->{$_}->response->content for grep { ref $_ && ref $entries->{$_} } @{$self->{'content'}};
}

1;