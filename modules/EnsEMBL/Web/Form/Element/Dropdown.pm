package EnsEMBL::Web::Form::Element::Dropdown;

use strict;

use base qw(
  EnsEMBL::Web::DOM::Node::Element::Select
  EnsEMBL::Web::Form::Element
);

sub render {
  ## @overrides
  my $self = shift;
  $self->after($self->dom->create_element('span', {'class' => $self->CSS_CLASS_SHORTNOTE, 'inner_HTML' => ' '.$self->{'__shortnote'}})) if exists $self->{'__shortnote'};
  return $self->SUPER::render;
}

sub configure {
  ## @overrides
  my ($self, $params) = @_;
  
  exists $params->{$_} and $self->set_attribute($_, $params->{$_}) for qw(id name class size);
  exists $params->{$_} and $params->{$_} == 1 and $self->$_(1) for qw(disabled multiple);
  $self->set_attribute('class', $self->CSS_CLASS_REQUIRED) if exists $params->{'required'};
  
  my $selected_values = {};
  if (exists $params->{'value'}) {
    $params->{'value'} = [ $params->{'value'} ] unless ref($params->{'value'}) eq 'ARRAY';
    $params->{'value'} = [ shift @{ $params->{'value'} } ] unless $self->multiple;
    $selected_values  = { map { $_ => 1 } @{ $params->{'value'} } };
  }
  
  $params->{'shortnote'} = '<strong title="Required field">*</strong> '.($params->{'shortnote'} || '') if $params->{'required'};
  $self->{'__shortnote'} = $params->{'shortnote'} if exists $params->{'shortnote'};
  $self->{'__option_class'} = $params->{'option_class'} if exists $params->{'option_class'};
  if (exists $params->{'values'}) {
    for (@{$params->{'values'}}) {
      $_->{'selected'} = $_->{'value'} && exists $selected_values->{ $_->{'value'} } ? 1 : 0;
      $self->add_option($_);
    }
  }
}

sub add_option {
  ## Adds an option to the dropdown
  ## @params HashRef with following keys:
  ##  - id        Id attribute
  ##  - value     goes in value attribute of the option
  ##  - caption   goes as innerText in <option> (is the actual name displayed)
  ##  - selected  flag to tell whether option is selected or not
  ##  - class     Class attribute - overrides the 
  ##  - group     (optional) Label attribute for the parent Optgroup for the option - If optgroup does not exist, a new one's created before adding it
  ## @return newly added Node::Element::Option object
  my ($self, $params) = @_;
  
  $params->{'value'}   = '' unless exists $params->{'value'} && defined $params->{'value'};
  $params->{'caption'} = '' unless exists $params->{'caption'} && defined $params->{'caption'};
  $params->{'class'} ||= $self->{'__option_class'} if exists $params->{'__option_class'};
  
  my $option = $self->dom->create_element('option', {'inner_HTML' => $params->{'caption'}, 'value' => $params->{'value'}});
  $option->set_attribute('id', $params->{'id'}) if $params->{'id'};
  $option->selected(1) if exists $params->{'selected'} && $params->{'selected'} == 1;

  my $group = undef;
  if (exists $params->{'group'} && $params->{'group'} ne '') {
    $_->get_attribute('label') eq $params->{'group'} and $group = $_ and last for @{$self->get_elements_by_tag_name('optgroup')}; #find any matching one
    $group = $self->append_child($self->dom->create_element('optgroup', {'label' => $params->{'group'}})) unless $group;          #new optgroup if no match
  }
  return ($group || $self)->append_child($option);
}

1;