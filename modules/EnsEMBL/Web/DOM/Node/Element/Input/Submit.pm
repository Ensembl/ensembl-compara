package EnsEMBL::Web::DOM::Node::Element::Input::Submit;

## Status - Under Development

use strict;
use warnings;

use base qw(EnsEMBL::Web::DOM::Node::Element::Input);

sub new {
  ## @overrides
  my $self = shift->SUPER::new(@_);
  $self->set_attribute('type', 'submit');
  return $self;
}

1;