package EnsEMBL::Web::Component::Help::EmailSent;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Help);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $email = $self->hub->species_defs->ENSEMBL_HELPDESK_EMAIL;

  my $html = '<p>Thank you. Your message has been sent to our HelpDesk. You should receive a confirmation email shortly.</p>';
  $html .= qq(<p>If you do not receive a confirmation, please email us directly at <a href="mailto:$email">$email</a>. Thank you.</p>);

  return $html;
}

1;
