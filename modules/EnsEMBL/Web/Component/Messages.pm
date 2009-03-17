package EnsEMBL::Web::Component::Messages;

### Module to output messages from session, etc

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub caption {
  my $self = shift;
  return undef;
}

sub content {
  my $self = shift;
  ### TODO - replace this with a div that pulls messages in via AJAX, so they aren't cached
  my $html = qq(<div style="width:80%" class="error"><h3>Error</h3><div class="error-pad">Oops, an error!</div></div>);
  return $html;
}

1;
