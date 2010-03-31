package EnsEMBL::Web::Form::Element::CheckBox;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Form::Element);

sub new {
  my $class = shift;
  my %params = @_;
  my $self = $class->SUPER::new( %params );
  $self->checked = $params{'checked'};
  if ($params{'long_label'}) {
    $self->add_class('checkbox-long');
  }
  return $self;
}

sub checked  :lvalue { $_[0]->{'checked'};  }
sub disabled :lvalue { $_[0]->{'disabled'}; }

sub render {
  my $self = shift;
  return sprintf(
    qq(
  <tr>
    <th%s>
      <label for="%s">%s %s</label>
    </th>
    <td%s>
      <input type="checkbox" name="%s" id="%s" value="%s" class="input-checkbox"%s%s/>
    </td>
  </tr>),
    $self->class_attrib,
    encode_entities( $self->id ),
    $self->{'raw'} ? $self->label : encode_entities( $self->label ), 
    $self->notes ? '<div style="font-weight:normal">'.encode_entities($self->notes).'</div>':'',
    $self->class_attrib,
    encode_entities( $self->name ), 
    encode_entities( $self->id ),
    $self->value || 'yes',
    $self->checked ? ' checked="checked" ' : '',
    $self->disabled ? ' disabled="disabled" ' : '',
  );
}
                                                                                
sub validate { return 1; }
1;
