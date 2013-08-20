package EnsEMBL::Web::Form::Element::Filterable;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Form::Element::Checklist);

use constant {
  CLASSNAME_DIV       => 'filterable-dropdown _fd',
  CLASSNAME_FILTER    => 'filterable-dropdown-filter _fd_filter',
  DEFAULT_FILTER_TEXT => 'type in to filter&#8230;'
};

sub configure {
  ## @overrrides
  my ($self, $params) = @_;

  $params->{'wrapper_class'}  = [ ref $params->{'wrapper_class'} ? @{$params->{'wrapper_class'}} : $params->{'wrapper_class'} || (), $self->CLASSNAME_DIV ];
  $params->{'force_wrapper'}  = 1;

  $self->{'__multiple'} = delete $params->{'multiple'};

  $self->SUPER::configure($params);

  $self->append_child('div', {'children' => $self->child_nodes});
  $self->prepend_child('p', {
    'class'     => $self->CLASSNAME_FILTER,
    'children'  => [{'node_name' => 'input', 'class' => 'inactive', 'type' => 'text', 'value' => $params->{'filter_text'} || $self->DEFAULT_FILTER_TEXT}]
  });
}

sub _is_multiple {
  ## @overrides
  return shift->{'__multiple'};
}

1;