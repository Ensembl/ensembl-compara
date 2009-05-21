package EnsEMBL::Web::Form::Element::RadioGroup;

use strict;
use base  qw( EnsEMBL::Web::Form::Element );

use CGI qw(escapeHTML);

sub new {
  my $class = shift;
  my %params = @_;
  my $self = $class->SUPER::new( %params, 'render_as' => $params{'select'} ? 'select' : 'radiobutton', 'values' => $params{'values'} );
  return $self;
}

sub validate { return $_[0]->render_as eq 'select'; }

sub render {
  my $self =shift;

  my $output = '';
  my $K = 0;
  foreach my $V ( @{$self->values} ) {
    my $checked = 'no';
    # check if we want to tick this box
    foreach my $M ( @{$self->value||[]} ) {
	    if ($M eq $V->{'value'}) {
	      $checked = 'yes';
	      last;
	    }
    }
    if ($V->{'checked'} eq 'yes') {
	    $checked = 'yes';
    }
    $output .= sprintf(qq(    
<tr>
<td></td>
<td><label class="label-radio">
<input type="radio" name="%s" id="%s_%d" value="%s" class="input-radio" %s/> %s </label></td>
</tr>),
        CGI::escapeHTML($self->name),
        CGI::escapeHTML($self->name), $K,
			  CGI::escapeHTML($V->{'value'}),
			  $checked eq 'yes' ? ' checked="checked"' : '', 
			  $self->{'noescape'} ? $V->{'name'} : CGI::escapeHTML($V->{'name'}),
			  );
    $K++;
  }
  return $self->introduction.$output.$self->notes;

}

1;
