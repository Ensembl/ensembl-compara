package EnsEMBL::Web::Component::Account::Message;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Account);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return '';
}

sub content {
  my $self = shift;
  my $object = $self->object;
  
  my $messages = {
    'password_not_confirmed'  => 'New password could not be confirmed. Please try again.',
    'invalid_password'        => 'New password is not valid. Password can be 6 to 32 characters long with no spaces.',
    'password_saved'          => 'Your new password has been saved successfully.',
  };
  
  my $message;
  $message = $messages->{ $object->param('message') } if $object->param('message') && exists $messages->{ $object->param('message') };
  $message = $object->param('error') eq '1' ? 'Unknown error' : '' unless defined $message;
  
  my $css  = $object->param('error') eq '1' ? ' class="modal_error"' : '';
  my $link = $object->param('back') ? '<p class="modal_a"><a href="/Account/'.$object->param('back').'" class="modal_link" >Back</a></p>' : '';
  
  return qq(<p$css>$message</p>$link);
}

1;
