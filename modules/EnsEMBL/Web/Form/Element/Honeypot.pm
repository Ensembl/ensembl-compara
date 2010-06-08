package EnsEMBL::Web::Form::Element::Honeypot;

### Bogus textarea, hidden using CSS, designed to catch spambots!

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Form::Element);

sub render {
  my $self = shift;
  return sprintf( '
  <tr class="hide">
    <th><label for="%s">%s: </label></th>
    <td><textarea id="%s"></textarea>
    </td>
  </tr>',
    encode_entities( $self->name ),
    encode_entities( $self->label ),
    encode_entities( $self->name ),
  );
}


1;
