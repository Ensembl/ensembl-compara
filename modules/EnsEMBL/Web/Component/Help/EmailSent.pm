package EnsEMBL::Web::Component::Help::EmailSent;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Help);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $html = '<p>Thank you. Your message has been sent to our HelpDesk. You should receive a confirmation email shortly.</p>';
  $html .= '<p>If you do not receive a confirmation, please email us directly at <a href="mailto:helpdesk@ensembl.org">helpdesk@ensembl.org</a>. Thank you.</p>';

  return $html;
}

1;
