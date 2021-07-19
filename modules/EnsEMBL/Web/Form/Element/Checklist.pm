=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Form::Element::Checklist;

use strict;

use base qw(EnsEMBL::Web::Form::Element::Div);

use constant {
  CSS_CLASS_SUBHEADING      => 'optgroup',
  CSS_CLASS_INNER_WRAPPER   => 'ff-checklist',
  CSS_CLASS_INNER_LABEL     => 'ff-checklist-label',
  SELECT_DESELECT_CAPTION   => '<b>Select/deselect all</b>',
  SELECT_DESELECT_JS_CLASS  => '_selectall'
};

sub _is_multiple {
  ## @protected
  ## Overridden in Radiolist and Filterable
  return 1;
}

sub configure {
  ## @overrides
  my ($self, $params) = @_;

  # configure the wrapping parent div
  delete $params->{'children'};
  $self->SUPER::configure($params);

  # default attributes for the checkboxs/radiobuttons
  $self->{'__option_name'}        = $params->{'name'} || '';
  $self->{'__option_disabled'}    = $params->{'disabled'} ? 1 : 0;
  $self->{'__option_class'}       = $params->{'class'} if exists $params->{'class'};
  $self->{'__option_label_first'} = $params->{'label_first'} if exists $params->{'label_first'};
  $self->{'__inline'}             = exists $params->{'inline'} && $params->{'inline'} == 1 ? 1 : 0;

  my $checked_values = {};
  if (exists $params->{'value'}) {
    $params->{'value'}  = [ $params->{'value'} ] unless ref($params->{'value'}) eq 'ARRAY';
    $params->{'value'}  = [ shift @{$params->{'value'}} ] unless $self->_is_multiple;
    $checked_values     = { map { $_ => 1 } @{$params->{'value'}} };
  }
  if ($params->{'selectall'}) {
    $self->add_option({
      'value'         => 'select_all',
      'class'         => $self->SELECT_DESELECT_JS_CLASS,
      'caption'       => {'inner_HTML' => $self->SELECT_DESELECT_CAPTION},
      'checked'       => $params->{'selectall'} eq 'on',
    });
    $self->set_attribute('class', $self->SELECT_DESELECT_JS_CLASS);
  }
  if (exists $params->{'values'}) {
    for (@{$params->{'values'}}) {
      $_ = {'value' => $_, 'caption' => $_} unless ref $_ eq 'HASH';
      $_->{'checked'} = $_->{'checked'} || exists $_->{'value'} && defined $_->{'value'} && exists $checked_values->{$_->{'value'}} ? 1 : 0;
      $_->{'id'} = $params->{'id'} if (scalar(@{$params->{'values'}}) == 1);
      $_->{'class'} = $params->{'class'} if $params->{'class'};
      $self->add_option($_);
    }
  }
}

sub add_option {
  ## Adds an option to the dropdown
  ## @params HashRef with following keys:
  ##  - id          Id attribute of <input>
  ##  - class       Class attribute of <input>
  ##  - value       goes in value attribute of the option
  ##  - label       Text string (or hashref set of attributes including inner_HTML or inner_text) for <label>, appearing right side of the checkbox/radiobutton
  ##  - caption     Same as label (label takes precedence if both provided)
  ##  - checked     flag to tell whether option is selected or not
  ##  - helptip     Helptip text for the label
  ##  - group       Subheading caption - option will be added under this subheading, but if this subheading does not exist, a new one's created before adding the option
  ##  - class       Only needed to override the default class attribute for all options
  ##  - name        Only needed to override the default name attribute for all options
  ##  - disabled    Only needed to override the default enabled status for all options
  ##  - label_first Only needed to override the default label_first flag for all options
  ## @return newly added Node::Element::P/Span object containg an input and a label
  my ($self, $params) = @_;
  
  my $dom = $self->dom;

  $params->{'value'}         = '' unless exists $params->{'value'} && defined $params->{'value'};
  $params->{'class'}       ||= $self->{'__option_class'}        if $self->{'__option_class'};
  $params->{'label_first'} ||= $self->{'__option_label_first'}  if $self->{'__option_label_first'};
  $params->{'caption'}       = $params->{'label'}               if exists $params->{'label'};
  $params->{'id'}          ||= $self->unique_id                 if exists $params->{'caption'}; #'for' attrib for label if caption provided

  my $wrapper = $dom->create_element($self->{'__inline'} ? 'span' : 'p', {'class' => $self->CSS_CLASS_INNER_WRAPPER});
  my $input   = $dom->create_element($self->_is_multiple ? 'inputcheckbox' : 'inputradio', {'value' => $params->{'value'}, 'name' => $params->{'name'} || $self->{'__option_name'}});

  $params->{$_} and $input->set_attribute($_, $params->{$_}) for qw(id class);
  $input->disabled(exists $params->{'disabled'} ? ($params->{'disabled'} ? 1 : 0) : $self->{'__option_disabled'});
  $input->checked(1) if $params->{'checked'};
  
  my @children = ($input, exists $params->{'caption'} ? {
    'node_name' => 'label',
    'for'       => $input->id,
    'class'     => [ $self->CSS_CLASS_INNER_LABEL, $params->{'helptip'} ? ('ht', '_ht') : () ], $params->{'helptip'} ? (
    'title'     => $params->{'helptip'} ) : (),
    ref $params->{'caption'} eq 'HASH' ? %{$params->{'caption'}} : 'inner_text' => $params->{'caption'}
  } : ());
  $wrapper->append_children($params->{'label_first'} ? reverse @children : @children);

  my $next_heading = undef;
  if (exists $params->{'group'} && defined $params->{'group'}) {
    my $match = 0;
    for (@{$self->get_elements_by_class_name($self->CSS_CLASS_SUBHEADING)}) {
      $match and $next_heading = $_ and last;
      $match = 1 if $_->inner_HTML eq $params->{'group'};
    }
    $self->append_child('p', {'inner_HTML' => $params->{'group'}, 'class' => $self->CSS_CLASS_SUBHEADING}) unless $match; #create new heading if no match found
  }
  return defined $next_heading ? $self->insert_before($wrapper, $next_heading) : $self->append_child($wrapper);
}

1;
