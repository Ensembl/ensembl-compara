package EnsEMBL::Web::Form::Element::DropDown;
use strict;
use base qw( EnsEMBL::Web::Form::Element );
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

use CGI qw(escapeHTML);

sub new {
  my $class  = shift;
  my %params = @_;

  my $self   = $class->SUPER::new(
    %params,
    'render_as' => $params{'select'} || '',
  );
  $self->{'on_change'} = $params{'on_change'};
  $self->{'firstline'} = $params{'firstline'};
  $self->{'classes'} = $params{'classes'} || ['radiocheck'];
  return $self;
}

sub firstline :lvalue { $_[0]->{'firstline'}; }

sub _validate() { return $_[0]->render_as eq 'select'; }

sub render {
  my $self = shift;
  if( $self->render_as eq 'select' ) {
    my $options = '';
    my $current_group;
    if( $self->firstline ) {
      $options .= sprintf qq(<option value="">%s</option>\n), CGI::escapeHTML( $self->firstline );
    }
    my $optcount = 0;
    my @styles = @{$self->styles};
    foreach my $V ( @{$self->values} ) {
      if( $V->{'group'} ne $current_group ) {
        if( $current_group ) {
          $options.="</optgroup>\n";
        }
        if( $V->{'group'}) {
          $options.= sprintf qq(<optgroup label="%s">\n), CGI::escapeHTML( $V->{'group'} );
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
#       sprintf( "document.forms[%s].submit()", $self->form ) :
    my $label = $self->label ? CGI::escapeHTML( $self->label ).': ' : '';
    return sprintf( qq(
  <tr>
    <th><label for="%s">%s</label></th>
    <td><select name="%s" id="%s" %s%s>\n%s</select>%s</td>
  </tr>),
      CGI::escapeHTML( $self->name ), $label,
      CGI::escapeHTML( $self->name ), 
      CGI::escapeHTML( $self->id ),
      $self->class_attrib,
      $self->style_attrib,
      $options,
      $self->notes
    );
  } else {
    my $output = '';
    my $K = 0;
    foreach my $V ( @{$self->values} ) {
      $output .= sprintf( qq(    <tr><td></td><td%s%s><input id="%s_%d" class="radio" type="radio" name="%s" value="%s" %s /><label for="%s_%d">%s</label></td></tr>\n),
        $self->class_attrib, $self->style_attrib, CGI::escapeHTML($self->id), $K, CGI::escapeHTML($self->name), CGI::escapeHTML($V->{'value'}),
        $self->value eq $V->{'value'} ? ' checked="checked"' : '', CGI::escapeHTML($self->id), $K,
        CGI::escapeHTML($V->{'name'})
      );
      $K++;
    }
    return $self->introduction.$output.$self->notes;
  }
}

1;
