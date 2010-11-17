package EnsEMBL::Web::DOM::Node::Comment;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Text);

sub node_type {
  ## @overrides
  return shift->COMMENT_NODE;
}

sub text {
  ## @overrides
  ## Getter only of text
  ## @return Text
  my $self = shift;
  warn 'Do not call Comment->text to add comment, call Comment->comment instead.' if @_;
  return '<!--'.$self->{'_text'}.'-->';
}

sub comment {
  ## Getter/Setter of text comment
  ## @params Text (string, can contain HTML that will not be escaped) to be set
  ## @return Text
  my $self = shift;
  $self->{'_text'} = shift if @_;
  return $self->{'_text'};
}

1;