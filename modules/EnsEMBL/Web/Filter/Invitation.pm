package EnsEMBL::Web::Filter::Invitation;

use strict;

use EnsEMBL::Web::Data::Record::Invite;

use base qw(EnsEMBL::Web::Filter);

### Checks if a given invitation exists and that the code matches the value stored in the database

sub init {
  my $self = shift;
  
  $self->messages = {
    invalid   => 'Sorry, the invitation details you provided were invalid. Please try again, or contact the group administrator.',
    not_found => 'Sorry, this invitation no longer exists in our database. Either it has been deleted by the group administrator, or you have already accepted the invitation (in which case, if you log in, you should see the group in your account panel.',
  };
}

sub catch {
  my $self = shift;
  my $invitation = EnsEMBL::Web::Data::Record::Invite::Group->new($self->hub->param('id'));
  
  if ($invitation) {
    $self->error_code = 'invalid' unless $invitation->code eq $self->hub->param('code');
  } else {
    $self->error_code = 'not_found';
  }
}

1;
