package EnsEMBL::Web::Controller::Command::UserData::DeleteUpload;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::RegObj;
use base 'EnsEMBL::Web::Controller::Command::UserData';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
}

sub process {
  my $self = shift;
  my $cgi = $self->action->cgi;

  my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;
  my $object = $self->_create_object;
  if ($object) {
    $object->delete_userdata($cgi->param('id'));
  }
  $cgi->redirect($self->url('/UserData/ManageUpload'));
}

sub _create_object {
### Helper method - creates a skeleton UserData object in order to talk to the userdata dbs
  my $self = shift;

  my $db_connection = EnsEMBL::Web::DBSQL::DBConnection->new(undef, $ENSEMBL_WEB_REGISTRY->species_defs);
  my $core_objects = EnsEMBL::Web::CoreObjects->new( $self->action->cgi, $db_connection );
  my $factory = EnsEMBL::Web::Proxy::Factory->new(
    'UserData', {
      '_input'         => $self->action->cgi,
      '_core_objects'  => $core_objects,
      '_databases'     => $db_connection,
    }
  );
  $factory->createObjects;
  my @objects = @{$factory->DataObjects};
  return $objects[0];
}


}

1;
