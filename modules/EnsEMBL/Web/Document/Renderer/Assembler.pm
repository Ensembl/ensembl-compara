package EnsEMBL::Web::Document::Renderer::Assembler;

use strict;
use LWP::Parallel;
use LWP::Parallel::UserAgent;
use Data::Dumper;

use base 'EnsEMBL::Web::Document::Renderer';

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(content => [], @_);
  return $self;
}

sub printf  { push @{ shift->{content} }, sprintf( shift, @_ ); }
sub print   { push @{ shift->{content} }, @_; }
sub close   { shift->process; }
sub content { return join '', @{ shift->{content} } }

sub process {
  my $self = shift;

  my $agent = LWP::Parallel::UserAgent->new();

  foreach my $request (@{ $self->{content} }) {
    next unless ref $request;

    my $content;

    if ($self->cache) {
      ## Check the cache
      my $key = $request->uri->path_query;
      $key .= '::SESSION['.$self->session->get_session_id.']'
                if $self->session && $self->session->get_session_id;
      $key .= "::WIDTH[$ENV{ENSEMBL_IMAGE_WIDTH}]"
                if $ENV{'ENSEMBL_IMAGE_WIDTH'};

      $content = $self->cache->get($key);
    }

    if ($content) {
      $request = $content;
    } else {
      $request->header(
        Cookie  => $self->r->headers_in->{'Cookie'},
        Referer => $ENV{REQUEST_URI},
      );
      $agent->register($request);
    }

  }

  my $entries = $agent->wait;

  for my $i (0..@{ $self->{content} }) {
    $self->{content}->[$i] = $entries->{$self->{content}->[$i]}->response->content
      if ref $self->{content}->[$i] && ref $entries->{$self->{content}->[$i]};
  }

}

1;