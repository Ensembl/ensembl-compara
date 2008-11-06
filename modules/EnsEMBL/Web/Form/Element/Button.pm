package EnsEMBL::Web::Form::Element::Button;
use strict;
use base qw( EnsEMBL::Web::Form::Element );

use CGI qw(escapeHTML);

sub new { 
  my $class = shift; 
  my $self = $class->SUPER::new( @_ );
  return $self;
}

sub render { 
  my ($self, $multi) = @_; ## Optional boolean parameter 'multi' passed by e.g. Form::_render_buttons
  my $html;
  my $extra = $multi ? 'style="margin-left:0.5em;margin-right:0.5em" ' : '';
  unless ($multi) {
    $html .= '<dl><dt class="submit wide center">';
  }
  $html .= sprintf(
    '<input type="button" name="%s" value="%s" class="submit" %s/>', 
    CGI::escapeHTML($_[0]->name) || 'submit', 
    CGI::escapeHTML($_[0]->value), $extra, 
  );
  unless ($multi) {
    $html .= '</dt></dl>';
  }
  return $html;

}  
1;
