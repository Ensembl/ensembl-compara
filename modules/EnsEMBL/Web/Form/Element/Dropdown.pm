=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Form::Element::Dropdown;

use strict;

use base qw(
  EnsEMBL::Web::DOM::Node::Element::Select
  EnsEMBL::Web::Form::Element
);

sub render {
  ## @overrides
  my $self = shift;
  return $self->SUPER::render(@_).$self->shortnote->render(@_);
}

sub configure {
  ## @overrides
  my ($self, $params) = @_;
  
  exists $params->{$_} and $self->set_attribute($_, $params->{$_}) for qw(id name class size style);
  exists $params->{$_} and $params->{$_} == 1 and $self->$_(1) for qw(disabled multiple);
  $self->set_attribute('class', $self->CSS_CLASS_REQUIRED) if exists $params->{'required'};
  
  my $selected_values = {};
  if (exists $params->{'value'}) {
    $params->{'value'} = [ $params->{'value'} ] unless ref($params->{'value'}) eq 'ARRAY';
    $params->{'value'} = [ shift @{ $params->{'value'} } ] unless $self->multiple;
    $selected_values  = { map { $_ => 1 } @{ $params->{'value'} } };
  }
  
  $params->{'shortnote'} = '<strong title="Required field">*</strong> '.($params->{'shortnote'} || '') if $params->{'required'} && !$params->{'no_asterisk'};
  $self->{'__shortnote'} = $params->{'shortnote'} if exists $params->{'shortnote'};
  $self->{'__option_class'} = $params->{'option_class'} if exists $params->{'option_class'};
  if (exists $params->{'values'}) {
    for (@{$params->{'values'}}) {
      $_ = {'value' => $_, 'caption' => $_} unless ref $_ eq 'HASH';
      $_->{'selected'} = $_->{'selected'} || (defined $_->{'value'} && exists $selected_values->{ $_->{'value'} } ? 1 : 0);
      $self->add_option($_);
    }
  }
}

sub add_option {
  ## Adds an option to the dropdown
  ## @params HashRef with following keys:
  ##  - id        Id attribute
  ##  - value     goes in value attribute of the option
  ##  - caption   Text string (or hashref set of attributes including inner_HTML or inner_text, excluding 'value' and 'class' attrib) for <option>
  ##  - selected  flag to tell whether option is selected or not
  ##  - class     Class attribute - overrides the one added by option_class key in the element itself
  ##  - disabled  Disabled attribute
  ##  - group     (optional) Label attribute for the parent Optgroup for the option - If optgroup does not exist, a new one's created before adding it
  ## @return newly added Node::Element::Option object
  my ($self, $params) = @_;

  $params->{'value'}   = '' unless exists $params->{'value'} && defined $params->{'value'};
  $params->{'caption'} = $params->{'value'} unless exists $params->{'caption'} && defined $params->{'caption'};
  $params->{'class'} ||= $self->{'__option_class'} if exists $params->{'__option_class'};

  my $option = $self->dom->create_element('option', {(ref $params->{'caption'} eq 'HASH' ? %{$params->{'caption'}} : ('inner_HTML' => $params->{'caption'})),
    'value' => $params->{'value'},
    $params->{'class'}    ? ('class'    => $params->{'class'}) : (),
    $params->{'id'}       ? ('id'       => $params->{'id'})    : (),
    $params->{'selected'} ? ('selected' => 'selected')         : (),
    $params->{'disabled'} ? ('disabled' => 'disabled')         : ()
  });

  my $group = undef;
  if (exists $params->{'group'} && $params->{'group'} ne '') {
    $_->get_attribute('label') eq $params->{'group'} and $group = $_ and last for @{$self->get_elements_by_tag_name('optgroup')}; #find any matching one
    $group = $self->append_child('optgroup', {'label' => $params->{'group'}}) unless $group;                                      #new optgroup if no match
  }
  return ($group || $self)->append_child($option);
}

1;