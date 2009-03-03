package EnsEMBL::Web::Filter::Activation;

use strict;
use warnings;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Filter);

### Checks if a given activation code matches the value stored in the database

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  ## Set the messages hash here
  $self->set_messages({
    'invalid' => 'Sorry, your activation details could not be validated. Please check your activation link, or <a href="/Help/Contact">contact our Helpdesk</a> for assistance.',
  });
}


sub catch {
  my $self = shift;
  my $object = $self->object;
  my $user = EnsEMBL::Web::Data::User->find(email => $object->param('email'));

  if ($user) {
    ## Strip all the non \w chars
    my $code = $object->param('code');
    $code =~ s/[^\w]//g;

    if ($user->salt ne $code) {
      $self->set_error_code('invalid');
    }
  }
  else {
    $self->set_error_code('invalid');
  }
}

}

1;
