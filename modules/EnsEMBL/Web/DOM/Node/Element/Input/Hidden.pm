package EnsEMBL::Web::DOM::Node::Element::Input::Hidden;

## Status - Under Development

use strict;
use warnings;

use base qw(EnsEMBL::Web::DOM::Node::Element::Input);

sub new {
  ## @overrides
  my $self = shift->SUPER::new(@_);
  $self->set_attribute('type', 'hidden');
  return $self;
}

1;