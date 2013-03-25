package EnsEMBL::Web::Component::Help::EmailSent;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Component::Help);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self  = shift;
  my $hub   = $self->hub;
  my $email = $hub->species_defs->ENSEMBL_HELPDESK_EMAIL;

  return $hub->param('result')
    ? qq(<p>Thank you. Your message has been sent to our HelpDesk. You should receive a confirmation email shortly.</p>
      <p>If you do not receive a confirmation, please email us directly at <a href="mailto:$email">$email</a>. Thank you.</p>)
    : qq(<p>There was some problem sending your message. Please try again, or email us directly at <a href="mailto:$email">$email</a>. Thank you.</p>)
  ;
}

1;
