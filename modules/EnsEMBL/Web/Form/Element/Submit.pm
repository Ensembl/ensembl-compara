package EnsEMBL::Web::Form::Element::Submit;

use EnsEMBL::Web::Form::Element;
use CGI qw(escapeHTML);
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new { my $class = shift; return $class->SUPER::new( @_ ); }
sub render { return sprintf( '<input type="submit" name="%s" value="%s" class="red-button" />', CGI::escapeHTML($_[0]->name) || 'submit', CGI::escapeHTML($_[0]->value) ); }

1;
