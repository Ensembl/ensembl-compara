package EnsEMBL::Web::Form::Element::Button;
use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Form::Element);

sub new { 
  my $class = shift; 
  my $self = $class->SUPER::new( @_ );
  return $self;
}

sub render { 
  ## NB: this function is normally called from Form::render_buttons, which wraps the buttons in a TR tag
  my ($self = shift; 
  return sprintf(
    '<input type="button" name="%s" value="%s" class="submit" style="margin-left:0.5em;margin-right:0.5em" />', 
    encode_entities($_[0]->name) || 'submit', 
    encode_entities($_[0]->value), 
  );
}  
1;
