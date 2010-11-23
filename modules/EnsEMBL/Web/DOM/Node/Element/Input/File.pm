package EnsEMBL::Web::DOM::Node::Element::Input::File;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element::Input);

sub new {
  ## @overrides
  my $self = shift->SUPER::new(@_);
  $self->set_attribute('type', 'file');
  return $self;
}


1;