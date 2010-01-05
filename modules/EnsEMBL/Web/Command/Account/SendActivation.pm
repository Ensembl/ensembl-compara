package EnsEMBL::Web::Command::Account::SendActivation;

use strict;
use warnings;

use EnsEMBL::Web::Mailer::User;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;

  my $mailer = new EnsEMBL::Web::Mailer::User{
    to => $object->param('email')
  };
  
  $mailer->send_activation_email($object);
  
  $self->ajax_redirect('/Account/ActivationSent');
}

1;
