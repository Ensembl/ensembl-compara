package EnsEMBL::Web::Form::Element::Range;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Form::Element);

## TODO -  Needs updating - probably doesn't work with current JavaScript

sub render {
  my $self = shift;
  my( $min, $max ) = $self->value ? ( 1, $self->value ) : ( '','' );
  if( $self->value =~ /^(.*):(.*)$/ ) {
    $min = $1;
    $max = $2;
  }
  my $extra = sprintf qq(class="%s" onKeyUp="os_check('%s',this,%s)" onChange="os_check( '%s', this, %s )" ),
    'range' , 'range', $self->required eq 'yes' ? 1 : 0 , 'range', $self->required eq 'yes' ? 1 : 0;
  return sprintf
    '%s<input type="text" name="%s_min" value="%s" id="%s_min" %s /> - <input type="text" name="%s_max" value="%s" id="%s_max" %s />%s%s',
    $self->introduction,
    encode_entities( $self->name ),
    encode_entities( $min ),
    encode_entities( $self->id ),
    $extra,
    encode_entities( $self->name ),
    encode_entities( $max ),
    encode_entities( $self->id ),
    $extra,
    $self->required eq 'yes' ? $self->required_string : '',
    $self->notes;
}

1;
