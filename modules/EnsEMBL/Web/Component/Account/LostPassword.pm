package EnsEMBL::Web::Component::Account::LostPassword;

### Module to create user login form 

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Account);
use EnsEMBL::Web::Form;

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

  my $form = EnsEMBL::Web::Form->new( 'lost_password', "/Account/SendActivation", 'post' );

  $form->add_element('type'  => 'Information',
                    'value' => qq(<p>If you have lost your password or activation email, enter your email address and we will send you a new activation code.</p>));
  $form->add_element('type'  => 'String', 'name'  => 'email', 'label' => 'Email', 'required' => 'yes');
  $form->add_element('type'  => 'Hidden', 'name'  => 'lost', 'value' => 'yes');
  $form->add_element('type'  => 'Hidden', 'name'  => '_referer', 'value' => $self->object->param('_referer'));
  $form->add_element('type'  => 'Submit', 'name'  => 'submit', 'value' => 'Send', 'class'=>'cp-internal');

  return $form->render;
}

1;
