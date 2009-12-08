package EnsEMBL::Web::Form::Element::Raw;

### Module for rendering arbitrary form elements using raw XHTML
### USE WITH CAUTION!!

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Form::Element);

sub render {
  my $self = shift;
  return sprintf( '
  <tr>
    <th><label>%s: </label></th>
    <td>
    %s
    </td>
  </tr>',
    encode_entities( $self->label ),
    $self->raw
  );
}


1;
