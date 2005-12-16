package EnsEMBL::Web::Form::Element::StaticImage;

use EnsEMBL::Web::Form::Element;
use CGI qw(escapeHTML);
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new { my $class = shift; return $class->SUPER::new( @_ ); }

sub render { return sprintf( '<img alt="%s" name="%s" src="%s" width="%s" height="%s" />', 
			     CGI::escapeHTML($_[0]->alt),
			     CGI::escapeHTML($_[0]->name),
			     CGI::escapeHTML($_[0]->src || '-'),
			     CGI::escapeHTML($_[0]->width),
			     CGI::escapeHTML($_[0]->height),
   ); 
}

1;
