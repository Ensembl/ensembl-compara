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

  my $html = qq(<p>Sorry, we were unable to register you. If you have already registered with this email address, please use the 'Lost Password' link to reactivate your account. Thank you.</p>);
  return $html;
}

1;
