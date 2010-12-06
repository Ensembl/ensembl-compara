package EnsEMBL::Web::Form::ModalForm;

use strict;

use base qw(EnsEMBL::Web::Form);

use constant {
  WIZARD_CLASS_NAME => 'wizard',
};

sub new {
  ## @overrides
  my ($class, $params) = @_;
  my $self = $class->SUPER::new({
    'id' => $params->{'name'},
    'action' => $params->{'action'} || '#',
    'method' => $params->{'method'},
  });
  
  $self->set_attribute('class', $params->{'class'}) if $params->{'class'};

  $self->{'__modal_form_params'} = {};
  for (qw(wizard label back_button no_button backtrack current next)) {
    $self->{'__modal_form_params'}{$_} = $params->{$_} if exists $params->{$_};
  }
  return $self;
}

sub render {
  ## @overrides
  my $self = shift;
  my $params = $self->{'__modal_form_params'};
  
  my $label = $params->{'label'} || 'Next >';

  if ($params->{'wizard'}) {
    $self->set_attribute('class', $self->WIZARD_CLASS_NAME);
    
    $self->add_button({'type' => 'Button', 'name' => 'wizard_back', 'value' => '< Back', 'class' => 'back submit'}) unless defined $params->{'back_button'} && $params->{'back_button'} == 0;
    
    # Include current and former nodes in _backtrack
    if ($params->{'backtrack'}) {
      for (@{$params->{'backtrack'}}) {
        $self->add_hidden({'name' => '_backtrack', 'value' => $_}) if $_;
      }
    }
    
    $self->add_button({'type'  => 'Submit', 'name' => 'wizard_submit', 'value' => $label});
    $self->add_hidden([
      {'name' => '_backtrack', 'value' => $params->{'current'}},
      {'name' => 'wizard_next', 'value' => $params->{'next'}}
    ]);

  } elsif (!$params->{'no_button'}) {
    $self->add_button({'type' => 'Submit', 'name' => 'submit', 'value' => $label});
  }

  return $self->SUPER::render;
}

1;