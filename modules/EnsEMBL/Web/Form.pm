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
        'name'     => $name,
        'id'       => $name,
        'onSubmit' => sprintf( 'return( on_submit( %s_vars ))', $name ),
        'class'    => '',
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
      my $button = $module->new( 'form' => $self->{'_attributes'}{'name'}, %options );
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
  my $fieldset = EnsEMBL::Web::Form::FieldSet->new('form' => $self->{'_attributes'}{'name'}, %options );
  if (!$fieldset->{'_name'}) {
    $fieldset->{'_name'} =  $self->_next_id();
  }
  push @{$self->{'_fieldsets'}}, $fieldset;
  return $fieldset;
}

sub _next_id {
### Returns an autoincremented ID for fieldset (used if not defined manually in the component) 
  my $self = shift;
  return $self->{'_attributes'}{'name'}.'_'.($self->{'_form_id'}++);
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
    'value' => '<div class="right">Fields marked with <strong>*</strong> are required</div>'
    )
  }

  $output .= $self->_render_buttons;
  $output .= "\n</form>\n";
  return $output;
}


sub render_js {
  my $self = shift;
  my @entries;
  foreach my $element ( @{$self->{'_elements'}} ) {
    if($element->validate()) {
      if( $element->type eq 'DropDownAndString' ) {
        (my $T_name = $element->name)=~s/'/\\'/g;
        (my $T_label = $element->label)=~s/'/\\'/g;
        (my $TS_name = $element->string_name)=~s/'/\\'/g;
        (my $TS_label = $element->string_label)=~s/'/\\'/g;
        push @entries, sprintf(
          " new form_obj( '%s', '%s', '%s', '%s', %d )", $self->{_attributes}{'name'},$T_name,
          'DropDown', $T_label, $element->required eq 'yes'?1:0
        );
        push @entries, sprintf(
          " new form_obj( '%s', '%s', '%s', '%s', %d )", $self->{_attributes}{'name'},$TS_name,
          'String', $TS_label, $element->required eq 'yes'?1:0
        );
      } else {
        (my $T_name = $element->name)=~s/'/\\'/g;
        (my $T_label = $element->label)=~s/'/\\'/g;
        push @entries, sprintf(
          " new form_obj( '%s', '%s', '%s', '%s', %d )", $self->{_attributes}{'name'},$T_name,
          $element->type, $T_label, $element->required eq 'yes'?1:0
        );
      }
    }
  }
  my $vars_array = $self->{'_attributes'}{'name'}."_vars";
  if( @entries ) {
    return {
      'head_vars' => "$vars_array = new Array(\n  ".join(",\n  ",@entries)."\n);\n",
      'body_code' => "on_load( $vars_array );",
      'scripts'   => '/js/forms.js'
    };
  } else {
    return {};
  }
}

sub add_element {
### x
### Replacement for old method, included for backwards compatibility
### Tries to add the element to the last fieldset, or creates a new one if none exist

  my( $self, %options ) = @_;

  my $fieldset = $self->{'_fieldsets'}[-1];
  if (!$fieldset) {
    $fieldset = EnsEMBL::Web::Form::FieldSet->new('form' => $self->{'_attributes'}{'name'});
    push @{$self->{'_fieldsets'}}, $fieldset;
  }
  $fieldset->add_element(%options);
}

1;
