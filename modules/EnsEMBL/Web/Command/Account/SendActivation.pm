package EnsEMBL::Web::Command::Account::SendActivation;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Mailer::User;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;

  my $mailer = EnsEMBL::Web::Mailer::User->new;

  $mailer->set_to($object->param('email'));
  $mailer->send_activation_email($object);
  $self->ajax_redirect('/Account/ActivationSent');
}

1;
