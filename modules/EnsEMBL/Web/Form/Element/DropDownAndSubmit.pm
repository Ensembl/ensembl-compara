package EnsEMBL::Web::Form::Element::DropDownAndSubmit;

#--------------------------------------------------------------------
# Creates a form element for an option set, as either a select box
# or a set of radio buttons
# Takes an array of anonymous hashes, thus:
# my @values = (
#           {'name'=>'Option 1', 'value'=>'1'},
#           {'name'=>'Option 2', 'value'=>'2'},
#   );
# The 'name' element is displayed as a label or in the dropdown,
# whilst the 'value' element is passed as a form variable
#--------------------------------------------------------------------


use strict;
use base qw( EnsEMBL::Web::Form::Element );

use CGI qw(escapeHTML);

sub new {
  my $class = shift;
  my %params = @_;
  my $self = $class->SUPER::new(
    %params,
    'render_as' => $params{'select'} ? 'select' : 'radiobutton'
  );
  $self->button_value = $params{'button_value'};
  return $self;
}

sub _validate() { return $_[0]->render_as eq 'select'; }

sub button_value :lvalue { $_[0]->{'button_value'}; }
sub render {
  my $self = shift;
  if( $self->render_as eq 'select' ) {
    my $options = '';
    foreach my $V ( @{$self->values} ) {
      my %v_hash = %{$V}; 
      $options .= sprintf( qq(<option value="%s"%s>%s</option>\n),
        $v_hash{'value'}, $self->value eq $v_hash{'value'} ? ' selected="selected"' : '', $v_hash{'name'}
      );
    }
    return sprintf( qq(<tr><th><label for="%s">%s</label></th><td><select name="%s" id="%s" class="%s %s autosubmit">\n%s</select>
      <input type="submit" value="%s" class="input-submit" />%s
    %s</td></tr>),
      CGI::escapeHTML( $self->id ),
      $self->label,
      CGI::escapeHTML( $self->name ), 
      CGI::escapeHTML( $self->id ),
      $self->style,
      $self->required eq 'yes' ? 'required' : 'optional',
      $options,
      CGI::escapeHTML( $self->button_value ),
      $self->required eq 'yes' ? $self->required_string : '',
      $self->notes
    );
  } else {
    my $output = '<tr><th></th><td>';
    my $K = 0;
    foreach my $V ( @{$self->values} ) {
      $output .= sprintf( qq(<input id="%s_%d" class="radio" type="radio" name="%s" value="%s" %s /><label for="%s_%d">%s</label>\n),
        CGI::escapeHTML($self->id), $K, CGI::escapeHTML($self->name), CGI::escapeHTML($V->{'value'}),
        $self->value eq $V->{'value'} ? ' checked="checked"' : '', CGI::escapeHTML($self->id), $K,
        CGI::escapeHTML($V->{'name'})
      );
      $K++;
    }
    return sprintf( 
      qq(</td><td>%s%s<input type="submit" class="input-submit" value="%s" />%s\n  %s</td></tr>),
      $self->label, $output,
      CGI::escapeHTML( $self->button_value ),
      $self->required eq 'yes' ? $self->required_string : '',
      $self->notes
    );
  }
}

1;
