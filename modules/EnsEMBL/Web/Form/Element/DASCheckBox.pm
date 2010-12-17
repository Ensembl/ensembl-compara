package EnsEMBL::Web::Form::Element::DASCheckBox;

use strict;

use base qw(
  EnsEMBL::Web::DOM::Node::Element::Div
  EnsEMBL::Web::Form::Element
);

use constant {
  CSS_CLASS                  => 'ele-das',
  CSS_CLASS_CHECKBOX_WRAPPER => 'ele-das-left',
  CSS_CLASS_TEXT             => 'ele-das-right',
};

sub configure {
  ## @overrides
  my ($self, $params) = @_;
  
  $params->{'name'}   ||= 'logic_name';
  $params->{'value'}  ||= $params->{'das'}->logic_name;
  $params->{'label'}  ||= $params->{'das'}->label;
  $params->{'id'}     ||= $self->unique_id;

  $self->set_attribute('class', $self->CSS_CLASS.' '.($params->{'wrapper_class'} || ''));
  $self->set_attribute('id', $params->{'wrapper_id'}) if $params->{'wrapper_id'};
  
  my $checkbox = $self->dom->create_element('inputcheckbox', {'id' => $params->{'id'}, 'name' => $params->{'name'}, 'value', $params->{'value'}});
  $checkbox->set_attribute('class', $params->{'class'}) if $params->{'class'};
  $checkbox->checked(1)  if $params->{'checked'};
  $checkbox->disabled(1) if $params->{'disabled'};

  $self->append_child($self->dom->create_element('p', {'class' => $self->CSS_CLASS_CHECKBOX_WRAPPER}))->append_child($checkbox);
  $self->append_child($self->dom->create_element('div', {
    'inner_HTML'  => qq(<p><label for="$params->{'id'}">$params->{'label'}</label></p><div>$params->{'das'}->{'description'} [<a href="$params->{'das'}->{'homepage'}">Homepage</a>]</div>),
    'class'       => $self->CSS_CLASS_TEXT
  }));
}

1;