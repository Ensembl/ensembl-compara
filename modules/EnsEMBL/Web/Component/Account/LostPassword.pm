package EnsEMBL::Web::Component::Account::LostPassword;

### Module to create user login form 

use strict;

use base qw(EnsEMBL::Web::Component::Account);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'Lost Password';
}

sub content {
  my $self = shift;

  my $form = $self->new_form({
    'id'      =>  'lost_password',
    'action'  =>  '/Account/SendActivation'
  });
  
  my $fieldset = $form->add_fieldset;

  $fieldset->add_hidden({'name'  => 'lost', 'value' => 'yes'});
  $fieldset->add_notes(qq(<p>If you have lost your password or activation email, enter your email address and we will send you a new activation code.</p>));

  $fieldset->add_field([
    {'type'  => 'Email', 'name'  => 'email', 'label' => 'Email', 'required' => 'yes'},
    {'type'  => 'Submit', 'name'  => 'submit', 'value' => 'Send', 'class'=>'modal_link'}
  ]);

  return $form->render;
}

1;
