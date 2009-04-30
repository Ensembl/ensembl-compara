package EnsEMBL::Web::Form::FieldSet;

use strict;
use base qw( EnsEMBL::Web::Root );

use EnsEMBL::Web::Document::SpreadSheet;
use EnsEMBL::Web::Tools::RandomString;
use CGI qw(escapeHTML);

sub new {
  my ($class, %option) = @_;
  my $name = $option{'name'} || EnsEMBL::Web::Tools::RandomString::random_string;
  my $self = {
    '_id'               => $option{'form'}."_$name",
    '_legend'           => $option{'legend'} || '',
    '_stripes'          => $option{'stripes'} || 0,
    '_elements'         => [],
    '_set_id'     => 1,
    '_required'   => 0,
    '_file'       => 0,
    '_extra'      => '',
    '_notes'      => '',
  };
  bless $self, $class;
  ## Make adding of form elements as bulletproof as possible!
  if ($option{'elements'} && ref($option{'elements'}) eq 'ARRAY') {
    foreach my $element (@{$option{'elements'}}) {
      if (ref($element) =~ /EnsEMBL::Web::Form::Element/) {
        $self->_add_element($element);
      }
      else {
        $self->add_element(%$element);
      }
    }    
  }
  return $self;
}

sub create_element {
  my( $self, $options ) = @_;
  my $module = 'EnsEMBL::Web::Form::Element::'.$options->{'type'};
  
  if( $self->dynamic_use( $module ) ) {
    return $module->new( 'form' => $self->{'_attributes'}{'id'}, %$options );
  } else {
    warn "Unable to dynamically use module $module. Have you spelt the element type correctly?";
  }
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

sub legend {
  my $self = shift;
  $self->{'_legend'} = shift if @_;
  return $self->{'_legend'};
}

sub notes {
### a
  my $self = shift;
  $self->{'_notes'} = shift if @_;
  return $self->{'_notes'};
}

sub extra {
### a
  my $self = shift;
  $self->{'_extra'} = shift if @_;
  return $self->{'_extra'};
}

sub _next_id {
  my $self = shift;
  return $self->{'_id'}.'_'.($self->{'_set_id'}++);
}

sub _render_element {
  my( $self, $element, $tint) = @_;
  my $output;
  if ($element->type eq 'Submit' || $element->type eq 'Button') {
    my $html = '<tr><td></td><td>';
    $html .= $element->render($tint);
    $html .= '</td></tr>';
    return $html;
  }
  else {
    return $element->render;
  }
}


sub render {
  my $self = shift;
  my $output = '<fieldset'.$self->extra.">\n";
  $output .= '<h2>'.CGI::escapeHTML( $self->legend )."</h2>\n" if $self->legend; 
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
  
  $output .= qq(\n<table style="width:100%"><tbody>\n);
  my $hidden_output;
  my $i;
  foreach my $element ( @{$self->{'_elements'}} ) {
    #if (ref($element) eq 'HASH') {
    #  $element = $self->create_element($element);
    #}
    if ($element->type eq 'Hidden') {
      $hidden_output .= $self->_render_element( $element );
    }
    else {
      if ($self->{'_stripes'}) {
        $element->bg = $i % 2 == 0 ? 'bg2' : 'bg1';
      }
      $output .= $self->_render_element( $element );
    }
    $i++;
  }
  $output .= "\n</tbody></table>\n";
  $output .= $hidden_output;

  $output .= "\n</fieldset>\n";
  return $output;
}

1;
