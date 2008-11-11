package EnsEMBL::Web::Controller::Command::UserData::DeleteRemote;

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
    my $type = $cgi->param('record') || '';
    my $data = $cgi->param('data') || '';
    ## TEMPORARY URL
    if ($data eq 'url' && $type eq 'session') {
      my $temp = $self->object->get_session->get_tmp_data('url');
      my $urls = $temp->{'urls'} || [];
      if (scalar(@$urls) && $object->param('url')) {
        for my $i ( 0 ..  $#{@$urls}) {
          if ( $urls->[$i]{'url'} eq $object->param('url') ) {
            splice @$urls, $i, 1;
          }
        }
      }
      if (scalar(@$urls) < 1) {
        $object->get_session->purge_tmp_data('url');
      }
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
