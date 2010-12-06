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

  $self->set_attribute('id', $params->{'id'}) if exists $params->{'id'};
  $self->set_attribute('class', $params->{'class'}) if exists $params->{'class'};
  $self->set_attribute('class', $self->CSS_CLASS);
  
  my $wrapper  = $self->dom->create_element('p');
  $self->append_child($wrapper);
  $wrapper->set_attribute('class', $self->CSS_CLASS_CHECKBOX_WRAPPER);
  my $checkbox = $self->dom->create_element('inputcheckbox');
  $wrapper->append_child($checkbox);
  $checkbox->set_attribute('name', $params->{'name'});
  $checkbox->checked($params->{'checked'} ? 1 : 0);
  $checkbox->set_attribute('value', $params->{'value'});

  my $text = $self->dom->create_element('div');
  $text->set_attribute('class', $self->CSS_CLASS_TEXT);
  $self->append_child($text);
  $text->inner_HTML(qq(<p>$params->{das}->{label}</p><span>$params->{das}->{description} [<a href="$params->{das}->{homepage}">Homepage</a>]</span>));
}

1;