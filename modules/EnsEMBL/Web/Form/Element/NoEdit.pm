package EnsEMBL::Web::Form::Element::NoEdit;

use EnsEMBL::Web::Form::Element;
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new {
  my $class = shift;
  return $class->SUPER::new( @_ );
}

sub render { 
  my $self = shift;
  my $value = $self->value || '&nbsp;';
  return sprintf(qq(
    <tr>
      <th><label for="%s">%s: </label></th>
      <td><div id="%s">%s</div></td>
    </tr>),
    $self->name, $self->label, $self->name, $value
  ); 
}

1;
