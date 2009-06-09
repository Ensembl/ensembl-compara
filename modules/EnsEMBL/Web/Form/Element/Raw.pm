package EnsEMBL::Web::Form::Element::Raw;

### Module for rendering arbitrary form elements using raw XHTML
### USE WITH CAUTION!!

use strict;
use base qw( EnsEMBL::Web::Form::Element );

use CGI qw(escapeHTML);

sub render {
  my $self = shift;
  return sprintf( '
  <tr>
    <th><label>%s: </label></th>
    <td>
    %s
    </td>
  </tr>',
    CGI::escapeHTML( $self->label ),
    $self->raw
  );
}


1;
