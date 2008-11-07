package EnsEMBL::Web::Controller::Command::UserData::DetachDAS;

use strict;
use warnings;

use Class::Std;
use base 'EnsEMBL::Web::Controller::Command::UserData';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
}

sub process {
  my $self = shift;
  my $cgi = $self->action->cgi;

  my $object = $self->create_object;
  if ($object) {
    my $temp_das = $object->get_session->get_all_das;
    if ($temp_das) {
      my $das = $temp_das->{$cgi->param('logic_name')};
      $das->mark_deleted();
      $object->get_session->save_das();
    }
  }
  $self->ajax_redirect($self->ajax_url('/UserData/ManageRemote'));
}

}

1;
