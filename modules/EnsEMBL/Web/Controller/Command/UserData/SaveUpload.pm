package EnsEMBL::Web::Controller::Command::UserData::SaveUpload;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Document::Wizard;
use base 'EnsEMBL::Web::Controller::Command::UserData';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
}

sub process {
  my $self = shift;

  my $object = $self->create_object;

  $object->param(error_message => 'Error occured while saving your data')
    unless $object && $object->store_data(type => 'upload', code => $object->param('code'));

  $self->ajax_redirect($self->ajax_url('/UserData/ManageUpload'));
}

}

1;
