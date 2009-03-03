package EnsEMBL::Web::Filter::UserData;

use strict;
use warnings;
use Class::Std;

use base qw(EnsEMBL::Web::Filter);

### Error messages for userdata database actions

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  ## Set the messages hash here
  $self->set_messages({
    'no_file' => 'Unable to save uploaded file contents to your account',
    'no_das'  => 'Unable to save DAS details to your account',
    'no_url'  => 'Unable to save URL to your account',
  });
}

sub catch {
  my $self = shift;
}

}

1;
