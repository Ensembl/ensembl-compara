package EnsEMBL::Web::Form::Element::Submit;

use strict;
use warnings;
no warnings 'uninitialized';

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Form::Element);

sub new { my $class = shift; return $class->SUPER::new( @_ ); }

sub render { 
  my $self = shift; 
  return  sprintf( '<input type="submit" name="%s" value="%s" class="submit" %s/>', 
    encode_entities($self->name) || 'submit', encode_entities($self->value) );
}

1;
