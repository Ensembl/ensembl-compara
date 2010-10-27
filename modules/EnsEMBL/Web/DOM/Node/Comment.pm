package EnsEMBL::Web::DOM::Node::Comment;

## Status - Under Development

use strict;
use warnings;

use base qw(EnsEMBL::Web::DOM::Node);

sub node_type {
  ## @overrides
  return shift-COMMENT_NODE;
}

sub can_have_child {
  ## @overrides
  return 0;
}

sub render {
  ## @overrides
  return $self->text; 
}

sub text {
  ## Getter only of text
  ## Can not set text as in parent class
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
  }
  return $self->{'_text'};
}

1;