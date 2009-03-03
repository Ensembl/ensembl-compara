package EnsEMBL::Web::Filter::DuplicateUser;

use strict;
use warnings;
use Class::Std;

use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Filter);

### Checks if an email address is already registered

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  ## Set the messages hash here
  $self->set_messages({
    'duplicate' => 'Sorry, that email address is already registered.',
  });
}

sub catch {
  my $self = shift;
  if (EnsEMBL::Web::Data::User->find(email => $self->object->param('email'))) {
    $self->set_error_code('duplicate');
  }
}

}

1;
