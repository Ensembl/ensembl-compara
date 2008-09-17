package EnsEMBL::Web::Controller::Command::Blast::Submit;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;

use base 'EnsEMBL::Web::Controller::Command::Blast';

{

sub BUILD {
  my ($self, $ident, $args) = @_;
}

sub process {
### This method handles the initial stages of the blast query - submitting the data
### and checking ticket status - before forwarding to the appropriate page
  my $self = shift;
  my $cgi = $self->action->cgi;
  my ($script, $new_param);

  my $object = $self->_create_object;
  my $blast;
  $new_param->{'species'} = $cgi->param('species');

  my $ticket = $cgi->param('_ticket') || $cgi->param('ticket');

  if ($ticket) {
    $ticket =~ s/\s//g;
  }
  else {
    ## Submit new query
    $ticket = $object->submit_query;
  }
  $new_param->{'ticket'} = $ticket;

  my $report = $object->get_status($ticket);
  my $status = $report->{$ticket};
  if ($report->{'complete'}) {
    $script = 'Results';
  }
  else {
    $script = 'Status';
    $new_param->{'status'} = $report->{$ticket};
  }

  $cgi->redirect($self->url('/Blast/'.$script, $new_param));
}


sub _create_object {
  ## This module needs to create a fully-fledged Blast object in order to talk to the blast server
  my $self = shift;

  my $db_connection = EnsEMBL::Web::DBSQL::DBConnection->new(undef, $ENSEMBL_WEB_REGISTRY->species_defs);
  my $core_objects = EnsEMBL::Web::CoreObjects->new( $self->action->cgi, $db_connection );
  my $factory = EnsEMBL::Web::Proxy::Factory->new(
    'Blast', {
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
