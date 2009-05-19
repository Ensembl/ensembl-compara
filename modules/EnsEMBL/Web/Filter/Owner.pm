package EnsEMBL::Web::Filter::Owner;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Registry;

use base qw(EnsEMBL::Web::Filter);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_redirect('/Account/Links');
  ## Set the messages hash here
  $self->set_messages({
    'not_owner' => 'You are not the owner of this record.',
    'bogus_id' => 'No valid record selected.',
  });
}


sub catch {
  my $self = shift;
  my $object = $self->object;
  ## Don't fail if no ID - implies new record
  if ($object->param('id')) {
    ## First check we have a sensible value for 'id'
    if ($object->param('id') =~ /\D/) {
      $self->set_error_code('bogus_id');
      return;
    }
    else {
      my $user = $ENSEMBL_WEB_REGISTRY->get_user;
      my $record = $user->records($object->param('id')); 
      unless ($record) {
        $self->set_error_code('not_owner');
      }
    }
  }
}
  

}

1;
