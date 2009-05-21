package EnsEMBL::Web::Form::Element::Image;

use strict;
use base qw( EnsEMBL::Web::Form::Element );

use CGI qw(escapeHTML);

sub new { my $class = shift; return $class->SUPER::new( @_ ); }

sub render { return sprintf( '<tr><td colspan="2"><input type="image" alt="%s" name="%s" src="%s" class="form-button" /></td></tr>', 
			     CGI::escapeHTML($_[0]->alt),
			     CGI::escapeHTML($_[0]->name),
			     CGI::escapeHTML($_[0]->src || '-') ); }

1;
