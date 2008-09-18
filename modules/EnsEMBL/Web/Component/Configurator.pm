package EnsEMBL::Web::Component::Configurator;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component);
use CGI qw(escapeHTML);

sub _init {
  warn "INITIALIZED COMPONENT";
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

## Grab the description of the object...

  return '<p>CONFIG</p>';
}

1;
