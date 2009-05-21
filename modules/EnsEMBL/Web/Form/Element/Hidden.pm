package EnsEMBL::Web::Form::Element::Hidden;

use strict;
use base qw( EnsEMBL::Web::Form::Element );

use CGI qw(escapeHTML);

sub render {
  return sprintf
    '<input type="hidden" name="%s" value="%s" id="%s" />',
    CGI::escapeHTML( $_[0]->name ), CGI::escapeHTML( $_[0]->value ), CGI::escapeHTML( $_[0]->id );
}

1;
