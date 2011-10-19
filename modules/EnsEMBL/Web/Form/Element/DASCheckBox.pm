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

  my $das               = $params->{'das'};
  my $logic_name        = $das->logic_name;
  $params->{'name'}   ||= 'logic_name';
  $params->{'value'}  ||= $logic_name;
  $params->{'label'}  ||= $das->label;
  $params->{'id'}     ||= $self->unique_id;

  $self->set_attributes({'class' => [$self->CSS_CLASS, $params->{'wrapper_class'} || ()], $params->{'wrapper_id'} ? ('id' => $params->{'wrapper_id'}) : ()});
  $self->append_children({
    'node_name'   => 'p',
    'class'       => $self->CSS_CLASS_CHECKBOX_WRAPPER,
    'children'    => [{
      'node_name'               => 'inputcheckbox',
      (map {$params->{$_} ? ($_ => $params->{$_}) : ()} qw(id name value class)),
      (map {$params->{$_} ? ($_ => $_)            : ()} qw(checked disabled)),
    }]
  }, {
    'node_name'   => 'div',
    'class'       => $self->CSS_CLASS_TEXT,
    'inner_HTML'  => sprintf(
      q(<p><label for="%s">%s</label></p><div>%s%s</div>),
      $params->{'id'},
      $params->{'label'} eq $logic_name ? $params->{'label'} : "$params->{'label'} ($logic_name)",
      $das->{'description'},
      $das->{'homepage'} ? qq( [<a href="$das->{'homepage'}">Homepage</a>]) : ''),
  });  
}

1;