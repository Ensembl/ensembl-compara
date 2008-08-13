package EnsEMBL::Web::Component::Help::View;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Help);
use CGI qw(escapeHTML);
use EnsEMBL::Web::Data::View;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $html;

  my $help = EnsEMBL::Web::Data::View->new(CGI::escapeHTML($object->param('id')));

  if ($help) {

    $html .= $help->content;  

  }

  return $html;
}

1;
