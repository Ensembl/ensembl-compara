package EnsEMBL::Web::Form::Element::Html;

use strict;
use warnings;
no warnings 'uninitialized';
use base qw( EnsEMBL::Web::Form::Element::Text );

### Html fragment text area element - will need to map JavaScript validator back into Perl to make
### sure that the validation does not allow HTML check to be bypassed
### This package checks for a limited safe subset of HTML tags

use XHTML::Validator;

sub new {
  my $class = shift;
  my $widget = $class->SUPER::new( @_ );
  $widget->rows = 20 unless $widget->rows;
  $widget->cols = 80 unless $widget->cols;
  return $widget;
}

sub _is_valid {
  my $self = shift;
  my $validator = new XHTML::Validator;
  return $validator->validate( $self->value ) ? 0 : 1;
}

sub _class { return '_html'; }
1;
