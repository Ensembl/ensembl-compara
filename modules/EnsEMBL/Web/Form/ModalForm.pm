=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  WIZARD_CLASS_NAME => 'wizard',
  
  _PARAMS_KEY       => '__modal_form_params',
};

sub new {
  ## @overrides
  ## @params HashRef with keys
  ##  - action          Action attribute
  ##  - class           Class attribute
  ##  - method          Method attribute
  ##  - wizard          Flag on if form is a part of wizard
  ##  - label           Label for the submit button if wizard - default "Next >"
  ##  - no_back_button  Flag if on, back button is not displayed
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
  for (qw(wizard label no_back_button no_button backtrack current next buttons_on_top buttons_align)) {
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

  if ($params->{'wizard'}) {
    $self->set_attribute('class', $self->WIZARD_CLASS_NAME);
    
    push @buttons, {'type' => 'button', 'name' => 'wizard_back', 'value' => '< Back', 'class' => 'back submit'} unless $params->{'no_back_button'};
    
    # Include current and former nodes in _backtrack
    if ($params->{'backtrack'}) {
      for (@{$params->{'backtrack'}}) {
        push @hiddens, {'name' => '_backtrack', 'value' => $_} if $_;
      }
    }
    
    push @buttons, {'type'  => 'Submit', 'name' => 'wizard_submit', 'value' => $label};
    push @hiddens, {'name' => '_backtrack', 'value' => $params->{'current'}}, {'name' => 'wizard_next', 'value' => $params->{'next'}};

  } elsif (!$params->{'no_button'}) {
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
