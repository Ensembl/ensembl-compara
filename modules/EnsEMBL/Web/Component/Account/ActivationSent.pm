package EnsEMBL::Web::Component::Account::ActivationSent;

### Module to create user login form 

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Account);
use EnsEMBL::Web::Form;

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

  my $html = qq('<p>An activation email has been sent to the address you gave. Please check your email box; if nothing has arrived after a few hours, please contact our HelpDesk.</p>');

  return $html;
}

1;
