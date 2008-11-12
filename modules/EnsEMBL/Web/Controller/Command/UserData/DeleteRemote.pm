package EnsEMBL::Web::Controller::Command::UserData::DeleteRemote;

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
    my $type = $cgi->param('record') || '';
    my $data = $cgi->param('data') || '';
    ## TEMPORARY URL
    if ($data eq 'url' && $type eq 'session' && $object->param('code')) {
      $self->object->get_session->purge_data(type => 'url', code => $object->param('code')); 
    }
    ## SAVED URL
    elsif ($data eq 'url' && $type eq 'user') {
      $object->delete_userurl($object->param('id'));
    }
    ## DAS
    else {
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
  }
  $self->ajax_redirect($self->ajax_url('/UserData/ManageRemote'));

}

}

1;
