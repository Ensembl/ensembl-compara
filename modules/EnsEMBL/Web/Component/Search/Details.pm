package EnsEMBL::Web::Component::Search::Details;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;
  my $exa_obj = $self->object->Obj;
  my $renderer = new ExaLead::Renderer::HTML( $exa_obj );
  my $html = $renderer->render_form .
    $renderer->render_summary .
    $renderer->render_navigation .
    $renderer->render_hits;
  return $html;
}

1;

