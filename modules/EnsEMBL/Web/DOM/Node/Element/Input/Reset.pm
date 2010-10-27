package EnsEMBL::Web::DOM::Node::Element::Input::Reset;

## Status - Under Development

use strict;
use warnings;

use base qw(EnsEMBL::Web::DOM::Node::Element::Input);

sub new {
  ## @overrides
  my $self = shift->SUPER::new(@_);
  $self->set_attribute('type', 'reset');
  return $self;
}

1;