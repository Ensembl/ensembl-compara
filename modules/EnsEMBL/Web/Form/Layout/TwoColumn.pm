package EnsEMBL::Web::Form::Layout::TwoColumn;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Form::Layout);

use constant {
  CSS_CLASS     => 'twocolumnlayout',
  FIELD         => 'tc_field',
};

sub new {
  ## @overrides
  my $self = shift->SUPER::new(@_);
  $self->set_attribute('class', $self->CSS_CLASS);
  $self->{'__fields'} = [];
  $self->dom->map_element_class({
    $self->FIELD => 'EnsEMBL::Web::Form::Layout::TwoColumn::Field',
  });
  return $self;
}

sub fields {
  ## Returns all fields added
  ## @return ArrayRef of Web::Form::Field objects
  return shift->{'__fields'};
}

sub add_field {
  ## Adds a field to the form
  ## Each field is a combination of one label on the left column of the layout and one (or more) elements (input, select, textarea) on the right column. 
  ## @params HashRef with keys:
  ##  - class             CSS className for the wrapper div
  ##  - label             innerHTML for <label>
  ##  - head_notes        Head notes hashref with following keys
  ##    - text            String or arrayref of strings
  ##    - serialise       Flag to tell whether or not to display list with numbers
  ##    - text_is_html    Flag to tell not to escape HTML while adding notes
  ##  - foot_notes        Similar hashref as in head_notes
  ##    - text            String or arrayref of strings
  ##    - serialise       Flag to tell whether or not to display list with numbers
  ##    - text_is_html    Flag to tell not to escape HTML while adding notes
  ##  - elements          ArrayRef of HashRefs - one HashRef for each element with keys as accepted by Form::Element::configure()
  ##  - inline            Flag to tell whether all elements are to be displayed in a horizontal line
  my ($self, $params) = @_;

  my $field = $self->dom->create_element($self->FIELD);
  $field->{'__inline'} = $params->{'inline'} && $params->{'inline'} == 1;
  $field->set_attribute('class', $params->{'class'}) if exists $params->{'class'};
  # add label
  $field->set_label($params->{'label'} || '');
  
  # add head notes
  $field->add_head_notes({
    'text'          => $params->{'head_notes'}->{'text'} || '',
    'serialise'     => $params->{'head_notes'}->{'serialise'} || '',
    'text_is_html'  => $params->{'head_notes'}->{'text_is_html'} || '',
  }) if exists $params->{'head_notes'};
  
  # add foot notes

  $field->add_foot_notes({
    'text'          => $params->{'foot_notes'}->{'text'} || '',
    'serialise'     => $params->{'foot_notes'}->{'serialise'} || '',
    'text_is_html'  => $params->{'foot_notes'}->{'text_is_html'} || '',
  }) if exists $params->{'foot_notes'};

  # add elements
  my $elements = [];
  push @$elements, $field->add_element($_) for @{ $params->{'elements'} };
  
  # set label's "for" attribute for the very first element in the field if possible
  my $inputs = $field->get_elements_by_tag_name(['input', 'select', 'textarea']);
  if (scalar @$inputs 
    && $inputs->[0]->id 
    && ($inputs->[0]->node_name =~ /^(select|textarea)$/
      || $inputs->[0]->node_name eq 'input' && $inputs->[0]->get_attribute('type') =~ /^(text|password|file)$/
      || $inputs->[0]->node_name eq 'input' && $inputs->[0]->get_attribute('type') =~ /^(checkbox|radio)$/ && scalar @$inputs == 1
    )
  ) {
    $field->label->set_attribute('for', $inputs->[0]->id);
  }

  $self->inner_div->append_child($field);
  push @{ $self->{'__fields'} }, $field;
  return $field;
}

1;