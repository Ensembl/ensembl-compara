package EnsEMBL::Web::Form::Element::Submit;

use strict;
use warnings;
no warnings 'uninitialized';
use base qw( EnsEMBL::Web::Form::Element );

use CGI qw(escapeHTML);

sub new { my $class = shift; return $class->SUPER::new( @_ ); }

sub render { 
  my ($self, $multi) = @_; ## Optional boolean parameter 'multi' passed by e.g. Form::_render_buttons
  my $html;
  my $extra = $multi ? 'style="margin-left:0.5em;margin-right:0.5em" ' : '';
  unless ($multi) {
    $html .= '<dl><dt class="submit wide center">'; 
  }
  $html .=  sprintf( '<input type="submit" name="%s" value="%s" class="submit" %s/>', 
    CGI::escapeHTML($self->name) || 'submit', CGI::escapeHTML($self->value), $extra );
  unless ($multi) {
    $html .= '</dt></dl>';
  }
  return $html;
}

1;
