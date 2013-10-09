# $Id$

package EnsEMBL::Web::Component::Messages::Urgent;

### Module to output warning messages from session, etc

use strict;

use base qw(EnsEMBL::Web::Component::Messages);

sub content {
  my $self = shift;
  
  return $self->SUPER::content(qw(_error _warning)); 
}

1;
