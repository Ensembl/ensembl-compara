package EnsEMBL::Web::Controller::Command::UserData;

use strict;
use warnings;

use base 'EnsEMBL::Web::Controller::Command';

sub create_object {
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


1;
