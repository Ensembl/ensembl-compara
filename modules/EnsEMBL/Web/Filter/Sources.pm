package EnsEMBL::Web::Filter::Sources;

use strict;
use warnings;
use Class::Std;

use base qw(EnsEMBL::Web::Filter);

### Checks if the user has actually selected one or more DAS sources

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_messages({
    'none' => 'No sources selected.',
  });
}

sub catch {
  my $self = shift;
  $self->set_redirect('/UserData/SelectDAS');
  # Process any errors
  if (!$self->object->param('dsn')) {
    ## Store the server's message in the session
    $self->set_error_code('none');
  }
}

}

1;
