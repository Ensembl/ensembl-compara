package EnsEMBL::Web::Filter::Invitation;

use strict;
use warnings;

use EnsEMBL::Web::Data::Group;
use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Filter);

### Checks if a given invitation exists and that the code matches the value stored in the database

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  ## Set the messages hash here
  $self->set_messages({
    'invalid' => 'Sorry, the invitation details you provided were invalid. Please try again, or contact the group administrator.',
    'not_found' => 'Sorry, this invitation no longer exists in our database. Either it has been deleted by the group administrator, or you have already accepted the invitation (in which case, if you log in, you should see the group in your account panel.',
  });
}

sub catch {
  my $self = shift;
  my $invitation = EnsEMBL::Web::Data::Record::Invite::Group->new($self->object->param('id'));
  if ($invitation) {
    unless ($invitation->code eq $self->object->param('code')) {
      $self->set_error_code('invalid');
    }
  }
  else {
    $self->set_error_code('not_found');
  }
}

}

1;
