package EnsEMBL::Web::DOM::Node::Element::Input::Password;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element::Input::Text);

sub new {
  ## @overrides
  my $self = shift->SUPER::new(@_);
  $self->set_attribute('type', 'password');
  return $self;
}

1;