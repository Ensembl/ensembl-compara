package EnsEMBL::Web::Form::Element::Submit;

use strict;
use warnings;
no warnings 'uninitialized';
use base qw( EnsEMBL::Web::Form::Element );

use CGI qw(escapeHTML);

sub new { my $class = shift; return $class->SUPER::new( @_ ); }
sub render { 
  my $self = shift;
  my $html =  sprintf( '
  <dl>
    <dt class="submit"><input type="submit" name="%s" value="%s" class="submit" /></dt>
  </dl>', CGI::escapeHTML($self->name) || 'submit', CGI::escapeHTML($self->value) ); 
  return $html;
}

1;
