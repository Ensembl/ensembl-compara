package EnsEMBL::Web::Form::Element::Dropdown;

use strict;
use warnings;

use base qw( EnsEMBL::Web::DOM::Node::Element::Select EnsEMBL::Web::Form::Element);

sub configure {
  ## @overrides
  my ($self, $params) = @_;
  
  $self->set_attribute('id',        $params->{'id'} || $self->unique_id);
  $self->set_attribute('name',      $params->{'name'})            if exists $params->{'name'};
  $self->set_attribute('class',     $params->{'class'})           if exists $params->{'class'};
  $self->set_attribute('size',      $params->{'size'})            if exists $params->{'size'};
  $self->set_attribute('class',     $self->CSS_CLASS_REQUIRED)    if exists $params->{'required'} && $params->{'required'} == 1;

  $self->disabled(1) if exists $params->{'disabled'} && $params->{'disabled'} == 1;
  $self->multiple(1) if exists $params->{'multiple'} && $params->{'multiple'} == 1;
  
  my $selected_values = {};
  if (exists $params->{'value'}) {
    $params->{'value'} = [ $params->{'value'} ] unless ref($params->{'value'}) eq 'ARRAY';
    $params->{'value'} = [ shift @{ $params->{'value'} } ] unless $self->multiple;
    $selected_values  = { map { $_ => 1 } @{ $params->{'value'} } };
  }
  if (exists $params->{'options'}) {
    for (@{ $params->{'options'} }) {
      my $args = {};
      $args->{'id'}       = $_->{'id'}        if exists $_->{'id'};
      $args->{'value'}    = $_->{'value'}     if exists $_->{'value'};
      $args->{'caption'}  = $_->{'caption'}   if exists $_->{'caption'};
      $args->{'selected'} = $_->{'value'} && exists $selected_values->{ $_->{'value'} } ? 1 : 0;
      $args->{'optgroup'} = $_->{'optgroup'}  if $_->{'optgroup'};
    
      $self->add_option($args);
    }
  }
  if (exists $params->{'shortnote'}) {
    $self->parent_node->append_child($self->dom->create_element('span'));
    $self->next_sibling->inner_text($params->{'shortnote'});
  }
}

sub add_option {
  ## Adds an options to the dropdown
  ## @params HashRef with following keys:
  ##  - id        Id attribute
  ##  - value     goes in value attribute of the option
  ##  - caption   goes as innerText in <option> (is the actual name displayed)
  ##  - selected  flag to tell whether option is selected or not
  ##  - optgroup  (optional) Label attribute for the parent Optgroup for the option - If optgroup does not exist, a new one's created before adding it
  ## @return newly added Node::Element::Option object
  my ($self, $params) = @_;
  
  $params->{'value'} = '' unless exists $params->{'value'} && defined $params->{'value'};
  $params->{'caption'} = '' unless exists $params->{'caption'} && defined $params->{'caption'};
  
  my $option = $self->dom->create_element('option');
  $option->inner_text($params->{'caption'});
  $option->set_attribute('id', $params->{'id'}) if exists $params->{'id'};
  $option->set_attribute('value', $params->{'value'});
  $option->selected(1) if exists $params->{'selected'} && $params->{'selected'} == 1;
  
  my $parent_node = $self;
  if (exists $params->{'optgroup'} && $params->{'optgroup'} ne '') {
  
    my $optgroup = undef;
    for (@{ $self->get_elements_by_tag_name('optgroup') }) {
      $optgroup = $_ if $_->get_attribute('label') eq $params->{'optgroup'};
    }
    unless (defined $optgroup) {
      $optgroup = $self->dom->create_element('optgroup');
      $optgroup->set_attribute('label', $params->{'optgroup'});
      $self->append_child($optgroup);
    }
    $parent_node = $optgroup;
  }
  $parent_node->append_child($option);
  return $option;
}

1;