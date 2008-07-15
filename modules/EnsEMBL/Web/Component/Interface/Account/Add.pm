package EnsEMBL::Web::Component::Interface::Account::Add;

### Module to create custom form for the Account modules

use EnsEMBL::Web::Component::Interface;
use EnsEMBL::Web::Form;

our @ISA = qw( EnsEMBL::Web::Component::Interface);
use strict;
use warnings;
no warnings "uninitialized";

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $html = '';
  return $html;
}


sub content {
  my $self = shift;

  my $form = $self->data_form($self->object, 'add');

}

1;
