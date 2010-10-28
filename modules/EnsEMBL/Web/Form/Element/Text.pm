package EnsEMBL::Web::Form::Element::Text;

use strict;
use warnings;
no warnings 'uninitialized';

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Form::Element);

### Textarea element;

sub render {
  my $self = shift;
  my ($style, @styles);
  if ( encode_entities( $self->rows ) ) {
    my $height = encode_entities( $self->rows ) * 1.2;
    push @styles, 'height:'.$height.'em';
  }
  
  if (@styles) {
    $style = 'style="'.join(';', @styles).'"';
  }

  return sprintf(
    qq(<tr>
<th><label for="%s" style="vertical-align:top;">%s: </label></th>
<td><textarea name="%s" id="%s" rows="%s" cols="%s" class="input-textarea %s %s" %s>%s</textarea><br />%s</td>
</tr>),
    encode_entities( $self->name ), 
    encode_entities( $self->label ), 
    encode_entities( $self->name ), 
    encode_entities( $self->id ),
    encode_entities( $self->rows ) ? encode_entities( $self->rows ) : '10', 
    encode_entities( $self->cols ) ? encode_entities( $self->cols ) : '40',
    encode_entities( $self->_class ),
    $self->required eq 'yes' ? 'required' : 'optional',
    $style,
    encode_entities( $self->value ),
    encode_entities( $self->notes ), 
  );
}

sub validate { return 1; }

sub _class { return '_text'; }

1;
