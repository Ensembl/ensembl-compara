package EnsEMBL::Web::Form;

use strict;
use EnsEMBL::Web::Root;
use EnsEMBL::Web::Form::FieldSet;
use CGI qw(escapeHTML);
our @ISA = qw( EnsEMBL::Web::Root );

sub new {
  my( $class, $name, $action, $method ) = @_;
  my $self = {
    '_attributes' => {
        'action'   => $action,
        'method'   => lc($method) || 'get' ,  
        'id'       => $name,
        'class'    => 'std check',
    },
    '_buttons'     => [],
    '_fieldsets'   => [],
    '_form_id'     => 1
  };
  bless $self, $class;
  return $self;
}

sub add_button {
### Add a button element to the form
  my( $self, %options ) = @_;
  my $type = $options{'type'};
  if ($type eq 'Submit' || $type eq 'Button') {
    my $module = "EnsEMBL::Web::Form::Element::$type";
    if( $self->dynamic_use( $module ) ) {
      my $button = $module->new( 'form' => $self->{'_attributes'}{'id'}, %options );
      push @{$self->{'_buttons'}}, $button;
    } 
    else {
      warn "Button module $module appears to be missing!";
    }
  }
  else {
    warn "Not a button module!";
  }
} 

sub add_attribute {
### Add an attribute to the FORM tag
  my( $self, $type, $value ) = @_;
  $self->{'_attributes'}{$type} = $value;
}

sub add_fieldset {
### Add a fieldset object to the form
  my( $self, %options ) = @_;
  my $fieldset = EnsEMBL::Web::Form::FieldSet->new('form' => $self->{'_attributes'}{'id'}, %options );
  if (!$fieldset->{'_name'}) {
    $fieldset->{'_name'} =  $self->_next_id();
  }
  push @{$self->{'_fieldsets'}}, $fieldset;
  return $fieldset;
}

sub _next_id {
### Returns an autoincremented ID for fieldset (used if not defined manually in the component) 
  my $self = shift;
  return $self->{'_attributes'}{'id'}.'_'.($self->{'_form_id'}++);
}

sub _render_buttons {
  my $self = shift;
  my $output = '<div class="submit">';
  foreach my $button ( @{$self->{'_buttons'}}) {
    $output .= $button->render;
  }
  $output .= '</div>';

  return $output;
}

sub render {
### Render the FORM tag and its contents
  my $self = shift;

  my $widgets = '';
  my $has_file = 0; 
  my $required = 0;
  foreach my $fieldset ( @{$self->{'_fieldsets'}} ) {
    $has_file = 1 if $fieldset->{'_file'};
    $required = 1 if $fieldset->{'_required'};
    $widgets .= $fieldset->render;
  }

  if( $has_file ) { # File types must always be multipart Posts 
    $self->add_attribute( 'method',  'post' );
    $self->add_attribute( 'enctype', 'multipart/form-data' );
  }

  my $output = "<form";
  while (my ($k, $v) = each ( %{$self->{'_attributes'}} )) {
    $output .= sprintf ' %s="%s"', CGI::escapeHTML($k), CGI::escapeHTML($v);
  }
  $output .= '>';

  $output .= $widgets;
  
  if ($required) {
    $self->add_element( 'type' => 'Information', 
    'value' => 'Fields marked with <strong>*</strong> are required'
    )
  }

  $output .= $self->_render_buttons;
  $output .= "\n</form>\n";
  $output .= '<div style="height:1px;overflow: hidden;clear:both;font-size:1pt">&nbsp;</div>';
  return $output;
}

sub add_element {
### x
### Replacement for old method, included for backwards compatibility
### Tries to add the element to the last fieldset, or creates a new one if none exist

  my( $self, %options ) = @_;

  my $fieldset = $self->{'_fieldsets'}[-1];
  if (!$fieldset) {
    $fieldset = EnsEMBL::Web::Form::FieldSet->new('form' => $self->{'_attributes'}{'id'});
    push @{$self->{'_fieldsets'}}, $fieldset;
  }
  $fieldset->add_element(%options);
}

1;
