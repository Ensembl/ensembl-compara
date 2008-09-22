package EnsEMBL::Web::Form::FieldSet;

use strict;
use EnsEMBL::Web::Root;
use CGI qw(escapeHTML);
our @ISA = qw( EnsEMBL::Web::Root );

sub new {
  my ($class, %option) = @_;
  my $self = {
    '_id'         => $option{'form'},
    '_elements'   => [],
    '_set_id'     => 1,
    '_required'   => 0,
    '_file'       => 0,
    '_extra'      => '',
    '_notes'      => '',
  };
  bless $self, $class;
  return $self;
}

sub add_element {
  my( $self, %options ) = @_;
  my $module = "EnsEMBL::Web::Form::Element::$options{'type'}";
  
  if( $self->dynamic_use( $module ) ) {
    $self->_add_element( $module->new( 'form' => $self->{'_attributes'}{'id'}, %options ) );
  } else {
    warn "Unable to dynamically use module $module. Have you spelt the element type correctly?";
  }
}

sub _add_element {
  my( $self, $element ) = @_;
  if( $element->type eq 'File' ) { 
    $self->{'_file'} = 1;
  }
  if( $element->required eq 'yes' ) { 
    $self->{'_required'} = 1;
  }
  if (!$element->id) {
    $element->id =  $self->_next_id();
  }
  push @{$self->{'_elements'}}, $element;
}

sub notes {
### a
  my ($self, $notes) = @_;
  if (!$self->{'_notes'}) {
    $self->{'_notes'} = $notes;
  }
  return $self->{'_notes'};
}

sub extra {
### a
  my ($self, $extra) = @_;
  if (!$self->{'_extra'}) {
    $self->{'_extra'} = $extra;
  }
  return $self->{'_extra'};
}

sub _next_id {
  my $self = shift;
  return $self->{'_id'}.'_'.($self->{'_set_id'}++);
}

sub _render_element {
  my( $self, $element ) = @_;
  my $output;
  return $element->render() if $element->type eq 'Hidden';

  #my $style = $element->required ? 'required' : 'optional';
  return qq(
  <div>
    ).$element->render().qq(
  </div>\n);
}


sub render {
  my $self = shift;
  my $output = '<fieldset'.$self->extra.">\n";
 
  if ($self->notes) {
    $output .= '<div class="notes">';
    if ($self->notes->{'heading'}) {
      $output .= '<h4>'.$self->notes->{'heading'}.'</h4>';
    }
    if ($self->notes->{'list'}) {
      $output .= '<ul>';
      foreach my $item (@{$self->notes->{'list'}}) {
        $output .= "<li>$item</li>\n";
      }
      $output .= '</ul>';
    }
    else {
      $output .= '<p>'.$self->notes->{'text'}.'</p>';
    }
    $output .= "</div>\n";
  } 
  
  foreach my $element ( @{$self->{'_elements'}} ) {
    $output .= $self->_render_element( $element );
  }
  $output .= "\n</fieldset>\n";
  return $output;
}

1;
