package EnsEMBL::Web::DOM::Node::Text;

use strict;

use base qw(EnsEMBL::Web::DOM::Node);

sub node_type {
  ## @overrides
  return shift->TEXT_NODE;
}

sub can_have_child {
  ## @overrides
  return 0;
}

sub render {
  ## @overrides
  return shift->{'_text'}; 
}

sub render_text {
  ## @overrides
  return shift->{'_text'}; 
}

sub text {
  ## Getter/Setter of text
  ## @params Text (string, can contain HTML that will not be escaped) to be set
  ## @return Text
  my $self = shift;
  $self->{'_text'} = $self->encode_htmlentities(shift) if @_;
  return $self->{'_text'};
}

1;