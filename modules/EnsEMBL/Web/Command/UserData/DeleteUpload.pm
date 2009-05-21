package EnsEMBL::Web::Command::UserData::DeleteUpload;

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
  my $object = $self->object;

  $object->delete_upload
    if $object;

  $self->ajax_redirect('/'.$object->data_species.'/UserData/ManageData', {'reload' => 1});
}

}

1;
