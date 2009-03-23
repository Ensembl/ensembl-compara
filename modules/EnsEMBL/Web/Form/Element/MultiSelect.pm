package EnsEMBL::Web::Form::Element::MultiSelect;

use EnsEMBL::Web::Form::Element;
use CGI qw(escapeHTML);
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new {
  my $class = shift;
  my %params = @_;

  my $self = $class->SUPER::new( %params, 'render_as' => $params{'select'} ? 'select' : 'radiobutton', 'values' => $params{'values'} );
  return $self;
}

sub validate { return $_[0]->render_as eq 'select'; }

sub render {
  my $self =shift;

  #cluck "This is how we got here!";

  if( $self->render_as eq 'select' ) {
    my $options = '';
    foreach my $V( @{$self->values} ) {
      my $checked = 'no';
      foreach my $M ( @{$self->value||[]} ) {
        if ($M eq $V->{'value'}) {
          $checked = 'yes';
          last;
        }
      }
      if ($V->{'checked'}) {
        $checked = 'yes';
      }
      $options .= sprintf( "<option value=\"%s\"%s>%s</option>\n",
			   $V->{'value'}, $checked eq 'yes' ? ' selected="selected"' : '', $V->{'name'}
      );
    }
    my $label = $self->label ? CGI::escapeHTML( $self->label ).': ' : '';
    return sprintf( qq(
    <tr>
      <th><label for="%s">%s</label></th>
      <td>%s<select multiple="multiple" name="%s" id="%s" class="normal" size="%s">
      %s
      </select>
      %s</td>
    </tr>),
      CGI::escapeHTML( $self->id ),
      $label, 
      $self->introduction,
      CGI::escapeHTML( $self->name ), CGI::escapeHTML( $self->id ),
      $self->size,
      $options,
      $self->notes
    );
  } else {
    warn ">>> MULTISELECT RADIO BUTTONS!";
    my $output = sprintf(qq(
    <tr>
    <th><label class="label" for="%s">%s</label></th>
    <td>),
        CGI::escapeHTML($self->id), CGI::escapeHTML( $self->label ));
    my $K = 0;
    my $separator = @{$self->values} > 2 ? 1 : 0;

    foreach my $V ( @{$self->values} ) {
      my $checked = 'no';
      # check if we want to tick this box
      foreach my $M ( @{$self->value||[]} ) {
        if ($M eq $V->{'value'}) {
          $checked = 'yes';
          last;
        }
      }
      if ($V->{'checked'}) {
        $checked = 'yes';
      }
      $output .= '<p>' if $separator;
      $output .= sprintf(qq(
<input type="checkbox" name="%s" id="%s_%d" value="%s" class="input-checkbox" %s /> %s),
	          CGI::escapeHTML($self->name), 
            CGI::escapeHTML($self->id), $K, 
	          CGI::escapeHTML($V->{'value'}),
            $checked eq 'yes' ? ' checked="checked"' : '', 
            CGI::escapeHTML($V->{'name'},
            )
      );
      $output .= '</p>' if $separator;
      $K++;
    }

    # To deal with the case when all checkboxes get unselected we intoduce a dummy 
    # hidden field that will force CGI to pass the parameter to our script
    $output .= sprintf( "    <input id=\"%s_%d\" type=\"hidden\" name=\"%s\" value=\"\" />\n",
            CGI::escapeHTML($self->id), 
	    $K, 
	    CGI::escapeHTML($self->name), 
			
    );
    $output .= qq(</td>
    </tr>);

    return $self->introduction.$output.$self->notes;
  }
}

1;
