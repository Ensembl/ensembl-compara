package EnsEMBL::Web::Filter::LoggedIn;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Registry;

use base qw(EnsEMBL::Web::Filter);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_redirect('/Account/Login');
  ## Set the messages hash here
  $self->set_messages({
    'not_logged_in' => 'You must be logged in to view this page.',
  });
}


sub catch {
  my $self = shift;
  my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;
  unless ($user) {
    $self->set_error_code('not_logged_in');
  }
}

}

1;
