package EnsEMBL::Web::DOM::Node::Element::Input::Image;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element::Input);

sub new {
  ## @overrides
  my $self = shift->SUPER::new(@_);
  $self->set_attribute('type', 'image');
  return $self;
}

1;