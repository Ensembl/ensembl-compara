package EnsEMBL::Web::Form::FieldSet;

use strict;
use base qw( EnsEMBL::Web::Root );

use EnsEMBL::Web::Document::SpreadSheet;
use CGI qw(escapeHTML);

sub new {
  my ($class, %option) = @_;
  my $self = {
    '_id'               => $option{'form'},
    '_layout'           => $option{'layout'} || 'normal',
    '_legend'           => $option{'legend'} || '',
    '_wizard_elements'  => $option{'elements'} || [],
    '_elements'         => [],
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
  my( $self, $element, $layout ) = @_;
  my $output;
  return $element->render() if $element->type eq 'Hidden';
  return $element->render($layout);
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
  
  if (scalar(@{$self->{'_wizard_elements'}})) {
    foreach my $wizard_element (@{$self->{'_wizard_elements'}}) {
      $self->add_element(%$wizard_element);
    }
  }
  
  if ($self->{'_layout'} eq 'table') {
    ## Used for complex forms like DAS and healthchecks
    my $table = EnsEMBL::Web::Document::SpreadSheet->new();
    $table->add_columns(
      {'key' => 'label', 'title' => '', 'width' => '90%', 'align' => 'left' },
      {'key' => 'widget', 'title' => '', 'width' => '5%', 'align' => 'left' },
    );
    my $hidden_output;
    foreach my $element ( @{$self->{'_elements'}} ) {
      if ($element->type eq 'Hidden') {
        $hidden_output .= $self->_render_element( $element );
      }
      else {
        $table->add_row($self->_render_element( $element, 'table') );
      }
    }
    $output .= $table->render;
    $output .= $hidden_output;
  }
  else {
    foreach my $element ( @{$self->{'_elements'}} ) {
      $output .= $self->_render_element( $element );
    }
  }
  $output .= "\n</fieldset>\n";
  return $output;
}

1;
