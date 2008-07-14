package EnsEMBL::Web::Form::Element::Submit;

use EnsEMBL::Web::Form::Element;
use CGI qw(escapeHTML);
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new { my $class = shift; return $class->SUPER::new( @_ ); }
sub render { 
  my $self = shift;
  my $html =  sprintf( '<div class="submit"><input type="submit" name="%s" value="%s" class="submit" /></div>', CGI::escapeHTML($self->name) || 'submit', CGI::escapeHTML($self->value) ); 
  return $html;
}

1;
