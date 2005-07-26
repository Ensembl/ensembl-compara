package EnsEMBL::Web::Form::Element::Image;

use EnsEMBL::Web::Form::Element;
use CGI qw(escapeHTML);
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new { my $class = shift; return $class->SUPER::new( @_ ); }

sub render { return sprintf( '<input type="image" alt="%s" name="%s" src="%s" class="form-button" />', 
			     CGI::escapeHTML($_[0]->alt),
			     CGI::escapeHTML($_[0]->name),
			     CGI::escapeHTML($_[0]->src || '-') ); }

1;
