package EnsEMBL::Web::Command::Account::SendActivation;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Mailer::User;

use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;

  my $mailer = EnsEMBL::Web::Mailer::User->new;

  $mailer->set_to($object->param('email'));
  $mailer->send_activation_email($object);
  $self->ajax_redirect('/Account/ActivationSent', {'_referer' => $object->param('_referer')});
}

}

1;
