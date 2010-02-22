# $Id$

package EnsEMBL::Web::Form;

use strict;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Form::FieldSet;

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $name, $action, $method, $style) = @_;
  
  my $self = {
    '_attributes' => {
        'action'   => $action,
        'method'   => lc($method) || 'get' ,  
        'id'       => $name,
        'class'    => $style || 'std check',
    },
    '_buttons'        => [],
    '_extra_buttons'  => '',
    '_fieldsets'      => [],
    '_form_id'        => 1
  };
  
  bless $self, $class;
  
  return $self;
}

# Add a button element to the form - used particularly for adding multiple buttons, e.g. on wizards
sub add_button {
  my ($self, %options) = @_;
  
  my $type = $options{'type'};
  
  if ($type eq 'Submit' || $type eq 'Button') {
    my $module = "EnsEMBL::Web::Form::Element::$type";
    
    if ($self->dynamic_use($module)) {
      my $button = $module->new('form' => $self->{'_attributes'}{'id'}, %options);
      push @{$self->{'_buttons'}}, $button;
    } else {
      warn "Button module $module appears to be missing!";
    }
  } else {
    warn 'Not a button module!';
  }
} 

sub extra_buttons {
  my ($self, $buttons) = @_;
  $self->{'_extra_buttons'} = $buttons if $buttons;
  return $self->{'_extra_buttons'};
}

# Add an attribute to the FORM tag
sub add_attribute {
  my ($self, $type, $value) = @_;
  
  if ($type eq 'class' && $self->{'_attributes'}{'class'}) {
    $self->{'_attributes'}{$type} .= " $value";
  } else {
    $self->{'_attributes'}{$type} = $value;
  }
}

# Add a fieldset object to the form
sub add_fieldset {
  my ($self, %options) = @_;
  
  my $fieldset = EnsEMBL::Web::Form::FieldSet->new('form' => $self->{'_attributes'}{'id'}, %options);
  $fieldset->{'_name'} =  $self->_next_id unless $fieldset->{'_name'};
  push @{$self->{'_fieldsets'}}, $fieldset;
  
  return $fieldset;
}

# Returns an autoincremented ID for fieldset (used if not defined manually in the component) 
sub _next_id {
  my $self = shift;
  return $self->{'_attributes'}{'id'} . '_' . ($self->{'_form_id'}++);
}

sub _render_buttons {
  my $self = shift;
  
  return unless  @{$self->{'_buttons'}};
  
  my $class = $self->{'_attributes'}{'class'};
  $class =~ s/check//;
  
  my $output = qq{
  <table style="width:100%" class="$class">
  <tbody>
    <tr>
    <th>&nbsp;</th><td>
  };
  
  $output .= $_->render for @{$self->{'_buttons'}};
  
  $output .= qq{
    </td>
  </tr>
  </tbody>
  </table>};

  return $output;
}

sub add_hidden {
  my ($self, $hidden) = @_;
  
  $self->add_element('type' => 'Hidden', 'name' => $_, 'value' => $hidden->{$_}) for keys %{$hidden||{}};
}

sub add_notes {
  my ($self, $notes) = @_;
   
  my $fieldset = $self->{'_fieldsets'}->[0] || $self->add_fieldset;
  
  $fieldset->notes($notes) if $fieldset && $notes;
} 

# Render the FORM tag and its contents
sub render {
  my $self = shift;
  
  if (grep $_->{'_file'}, @{$self->{'_fieldsets'}}) {
    #  File types must always be multipart Posts
    $self->add_attribute('method',  'post');
    $self->add_attribute('class',   'upload');
    $self->add_attribute('enctype', 'multipart/form-data');
    $self->add_attribute('target',  'uploadframe');
    
    $self->add_element(
      'type'  => 'Hidden',
      'name'  => 'uploadto',
      'value' => 'iframe'
    );
  }
  
  my $output = '<form';
  
  while (my ($k, $v) = each (%{$self->{'_attributes'}})) {
    $output .= sprintf ' %s="%s"', encode_entities($k), encode_entities($v);
  }
  
  $output .= '>';
  $output .= $self->_render_buttons if $self->{'_extra_buttons'} eq 'top';
  $output .= $_->render for @{$self->{'_fieldsets'}};
  $output .= $self->_render_buttons;
  $output .= "\n</form>\n";
  $output .= '<div style="height:1px; overflow:hidden; clear:both; font-size:1pt">&nbsp;</div>';
  
  return $output;
}

# Replacement for old method, included for backwards compatibility
# Tries to add the element to the last fieldset, or creates a new one if none exist
sub add_element {
  my ($self, %options) = @_;

  my $fieldset = $self->{'_fieldsets'}->[-1];
  my $new_fieldset;
  
  if (!$fieldset) {
    $new_fieldset = 1;
    $fieldset = EnsEMBL::Web::Form::FieldSet->new('form' => $self->{'_attributes'}{'id'});
    $fieldset->class('generic');
    push @{$self->{'_fieldsets'}}, $fieldset;
  }
  
  $fieldset->add_element(%options);
  
  return $fieldset if $new_fieldset;
}

1;
