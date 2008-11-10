package EnsEMBL::Web::Controller::Command::UserData::DeleteDAS;

use strict;
use warnings;

use Class::Std;
use base 'EnsEMBL::Web::Controller::Command::UserData';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
}

sub process {
  my $self = shift;
  my $cgi = $self->action->cgi;
  my $object = $self->create_object;

  if ($object) {
    if ($cgi->param('logic_name')) {
      my $temp_das = $object->get_session->get_all_das;
      if ($temp_das) {
        my $das = $temp_das->{$object->param('logic_name')};
        $das->mark_deleted() if $das;
        $object->get_session->save_das();
      }
    }
    elsif ($cgi->param('id')) {
      $object->delete_userdas($cgi->param('id'));
    }
  }
  $self->ajax_redirect($self->ajax_url('/UserData/ManageRemote'));

}

}

1;
