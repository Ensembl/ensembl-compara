package EnsEMBL::Web::Component::Search::New;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component);
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML::HomeSearch;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;

  my $search = EnsEMBL::Web::Document::HTML::HomeSearch->new();
  return $search->render;

}

1;

