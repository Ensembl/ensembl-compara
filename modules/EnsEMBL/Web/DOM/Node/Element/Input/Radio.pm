package EnsEMBL::Web::DOM::Node::Element::Input::Radio;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element::Input::Checkbox);

sub new {
  ## @overrides
  my $self = shift->SUPER::new(@_);
  $self->set_attribute('type', 'radio');
  return $self;
}

1;