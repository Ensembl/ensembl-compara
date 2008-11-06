package EnsEMBL::Web::Component::Interface::Account::FailedRegistration;

### Module to create custom page for the Account modules

use EnsEMBL::Web::Component::Interface;
use EnsEMBL::Web::Form;

our @ISA = qw( EnsEMBL::Web::Component::Interface);
use strict;
use warnings;
no warnings "uninitialized";

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  0 );
}

sub caption {
  my $html = '';
  return $html;
}


sub content {
  my $self = shift;

  my $html = qq(<p>Sorry, we were unable to register you. If you have already registered with this email address, please use the 'Lost Password' link to reactivate your account. Thank you.</p>);
  return $html;
}

1;
