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

  $self->set_attribute('id', $params->{'id'}) if exists $params->{'id'};
  $self->set_attribute('class', $self->CSS_CLASS.' '.($params->{'wrapper_class'} || ''));
  
  my $checkbox = $self->dom->create_element('inputcheckbox', {'name' => $params->{'name'}, 'value', $params->{'value'}});
  $checkbox->set_attribute('class', $params->{'class'}) if exists $params->{'class'};
  $checkbox->checked($params->{'checked'} ? 1 : 0);
  $checkbox->disabled($params->{'disabled'} ? 1 : 0);

  $self->append_child($self->dom->create_element('p', {'class' => $self->CSS_CLASS_CHECKBOX_WRAPPER}))->append_child($checkbox);
  $self->append_child($self->dom->create_element('div', {
    'inner_HTML'  => qq(<p>$params->{label}</p><span>$params->{das}->{description} [<a href="$params->{das}->{homepage}">Homepage</a>]</span>),
    'class'       => $self->CSS_CLASS_TEXT
  }));
}

1;