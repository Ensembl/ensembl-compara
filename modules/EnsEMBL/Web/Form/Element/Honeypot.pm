package EnsEMBL::Web::Form::Element::Honeypot;

### Bogus textarea, hidden using CSS, designed to catch spambots!

use CGI qw(escapeHTML);

use base qw( EnsEMBL::Web::Form::Element );

sub render {
  my $self = shift;
  return sprintf( '
  <tr class="hide">
    <th><label for="%s">%s: </label></th>
    <td><textarea name="%s"></textarea>
    </td>
  </tr>',
    CGI::escapeHTML( $self->name ),
    CGI::escapeHTML( $self->label ),
    CGI::escapeHTML( $self->name ),
  );
}


1;
