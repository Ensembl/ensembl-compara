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

package EnsEMBL::Web::Form::ModalForm;

use strict;

use base qw(EnsEMBL::Web::Form);

use constant {
  _PARAMS_KEY       => '__modal_form_params',
};

sub new {
  ## @overrides
  ## @params HashRef with keys
  ##  - action          Action attribute
  ##  - class           Class attribute
  ##  - method          Method attribute
  ##  - label           Label for the submit button 
  ##  - no_button       No buttons displayed automatically if flag is on
  ##  - buttons_on_top  If flag on, dupicate buttons are added at the top of the form
  ##  - buttons_align   where to align the buttons - centre, left, right, default
  ##  - skip_validation Flag if on, will not apply JS validation while submitting the form
  my ($class, $params) = @_;
  my $self = $class->SUPER::new({
    'id'              => $params->{'name'},
    'action'          => $params->{'action'} || '#',
    'method'          => $params->{'method'},
    'skip_validation' => $params->{'skip_validation'},
    'enctype'         => $params->{'enctype'},
  });

  $self->set_attribute('class', $params->{'class'}) if $params->{'class'};

  $self->{$self->_PARAMS_KEY} = {};
  for (qw(label no_button backtrack current next buttons_on_top buttons_align)) {
    $self->{$self->_PARAMS_KEY}{$_} = $params->{$_} if exists $params->{$_};
  }
  return $self;
}

sub render {
  ## Adds buttons and hidden inputs inside the form before rendering it
  ## @overrides
  my $self = shift;
  my $params = $self->{$self->_PARAMS_KEY};
  
  my $label = $params->{'label'} || 'Next >';
  my @buttons;
  my @hiddens;

  if (!$params->{'no_button'}) {
    push @buttons, {'type' => 'Submit', 'name' => 'submit_button', 'value' => $label};
  }
  
  $self->add_hidden(\@hiddens);
  
  if (@buttons) {
    my $buttons_field = $self->add_button({'buttons' => \@buttons, 'align' => $params->{'buttons_align'} || 'default'});
    
    if ($params->{'buttons_on_top'}) {
      $buttons_field = $buttons_field->clone_node(1);
      my $fieldset = $self->fieldsets->[0] || $self->add_fieldset;
      $fieldset->prepend_child($buttons_field);
    }
  }

  return $self->SUPER::render;
}

1;
