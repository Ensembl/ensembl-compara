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

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Form::Element);

sub new {
  my $class = shift;
  my %params = @_;
  my $self = $class->SUPER::new(
    %params,
    'render_as' => $params{'select'} ? 'select' : 'radiobutton'
  );
  $self->{'on_change'} = $params{'on_change'};
  $self->{'firstline'} = $params{'firstline'};
  $self->button_value = $params{'button_value'};
  return $self;
}

sub _validate() { return $_[0]->render_as eq 'select'; }

sub firstline     :lvalue { $_[0]->{'firstline'}; }
sub button_value  :lvalue { $_[0]->{'button_value'}; }


sub render {
  my $self = shift;
  if( $self->render_as eq 'select' ) {
    my $options = '';
    my $current_group;
    if( $self->firstline ) {
      $options .= sprintf qq(<option value="">%s</option>\n), encode_entities( $self->firstline );
    }
    my $optcount = 0;
    my @styles = @{$self->styles};
    foreach my $V ( @{$self->values} ) {
      if( $V->{'group'} ne $current_group ) {
        if( $current_group ) {
          $options.="</optgroup>\n";
        }
        if( $V->{'group'}) {
          $options.= sprintf qq(<optgroup label="%s">\n), encode_entities( $V->{'group'} );
        }
        $current_group = $V->{'group'};
      }
      my $extra = $self->value eq $V->{'value'} ? ' selected="selected"' : '';
      if ($styles[$optcount]) {
        $extra .= ' style="'.$styles[$optcount].'"';
      }
      $options .= sprintf( qq(<option value="%s"%s>%s</option>\n),
        $V->{'value'}, $extra, $V->{'name'}
      );
      $optcount++;
    }
    if( $current_group ) { $options.="</optgroup>\n"; }
    if ($self->{'on_change'} eq 'submit') {
      my $classes = $self->classes;
      push @$classes, 'autosubmit';
      $self->classes($classes);
    }

    my $label = $self->label ? encode_entities( $self->label ).': ' : '';
    return sprintf( qq(
  <tr>
    <th><label for="%s">%s</label></th>
    <td><select name="%s" id="%s" %s%s>\n%s</select> <input type="submit" value="%s" class="input-submit" />%s</td>
  </tr>),
      encode_entities( $self->name ), $label,
      encode_entities( $self->name ),
      encode_entities( $self->id ),
      $self->class_attrib,
      $self->style_attrib,
      $options,
      encode_entities( $self->button_value ),
      $self->notes
    );
  } else {
    my $output = '<tr><th></th><td>';
    my $K = 0;
    foreach my $V ( @{$self->values} ) {
      $output .= sprintf( qq(<input id="%s_%d" class="radio" type="radio" name="%s" value="%s" %s /><label for="%s_%d">%s</label>\n),
        encode_entities($self->id), $K, encode_entities($self->name), encode_entities($V->{'value'}),
        $self->value eq $V->{'value'} ? ' checked="checked"' : '', encode_entities($self->id), $K,
        encode_entities($V->{'name'})
      );
      $K++;
    }
    return sprintf( 
      qq(</td><td>%s%s<input type="submit" class="input-submit" value="%s" />%s\n  %s</td></tr>),
      $self->label, $output,
      encode_entities( $self->button_value ),
      $self->required eq 'yes' ? $self->required_string : '',
      $self->notes
    );
  }
}

1;
