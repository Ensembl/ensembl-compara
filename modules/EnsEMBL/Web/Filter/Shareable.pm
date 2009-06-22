package EnsEMBL::Web::Filter::Shareable;

use strict;
use warnings;
use Class::Std;

use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Filter);

### Checks if user has any shareable data

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  ## Set the messages hash here
  $self->set_messages({
    'no_group' => 'Could not find this group. Please try again',
    'none' => 'You have no shareable data. Please add some data to your account in order to share it with colleagues or collaborators.',
    'shared' => 'The selected record(s) are already shared with this group.',
    'not_shareable' => 'Some of the selected records could not be shared with the group, as they have not been saved to your user account. Please correct this and try again.',
  });
}

sub catch {
  my $self = shift;
  $self->set_redirect('/UserData/SelectFile');

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;

  my @temp_uploads = $self->object->get_session->get_data(type => 'upload');
  my @user_uploads = $user ? $user->uploads : ();

  unless (@temp_uploads || @user_uploads) {
    $self->set_error_code('none');
  }
}

}

1;
