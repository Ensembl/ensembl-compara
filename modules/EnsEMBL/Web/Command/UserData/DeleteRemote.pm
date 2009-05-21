package EnsEMBL::Web::Command::UserData::DeleteRemote;

use strict;
use warnings;

use Class::Std;
use base 'EnsEMBL::Web::Command';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
}

sub process {
  my $self = shift;
  $self->object->delete_remote;

  $self->ajax_redirect('/'.$self->object->data_species.'/UserData/ManageData', {'reload' => 1});
}

}

1;
