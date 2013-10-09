# $Id$

package EnsEMBL::Web::Component::Messages::Other;

### Module to output info messages from session, etc

use strict;

use base qw(EnsEMBL::Web::Component::Messages);

sub content {
  my $self = shift;
  
  return $self->SUPER::content('_info', '_hint'); 
}

1;
