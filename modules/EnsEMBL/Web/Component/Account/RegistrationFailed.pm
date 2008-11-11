package EnsEMBL::Web::Component::Account::RegistrationFailed;

### Module to create custom error page for the Account modules

use base qw( EnsEMBL::Web::Component::Account);
use strict;
use warnings;
no warnings "uninitialized";

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  0 );
}

sub caption {
  my $html = 'Registration Failed';
  return $html;
}


sub content {
  my $self = shift;

  my $html = '<p class="space-below">Sorry, we were unable to register you.';

  if ($self->object->param('error') eq 'duplicate_record') {
    $html .= " If you have already registered with this email address, please use the 'Lost Password' link to reactivate your account. Thank you.";
  }
  elsif ($self->object->param('error') eq 'spam') {
    $html .= ' Your details were identified as spam by our web filter. Please remove any URLs from your input and try again.';
  }
  $html .= '</p><p>If you require any further assistance, please <a href="/Help/Contact" class="modal_link">contact our HelpDesk</a></p>';
  return $html;
}

1;
