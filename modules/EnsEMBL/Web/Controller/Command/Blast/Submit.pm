package EnsEMBL::Web::Controller::Command::Blast::Submit;

### Command module to submit a new Blast query to the database
### and forward to an appropriate feedback page

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
  my $self = shift;
  my $cgi = $self->action->cgi;
  my ($script, $new_param);

  my $object = $self->_create_object;
  my $ticket = $object->submit_query;

  $new_param->{'species'} = $cgi->param('species');
  $new_param->{'ticket'} = $ticket;

  my $report = $object->get_status($ticket);
  if ($cgi->param('method') eq 'BLAT' && $report->{'pending'}) {
    ## Run BLAT jobs immediately and get results
    $object->run_jobs($ticket);
    $report = $object->get_status($ticket);
    if ($report->{'complete'}) {
      $script = 'Results';
      $new_param->{'run_id'} = $report->{'run_id'};
    }
    else {
      $script = 'Status';
      $new_param->{'status'} = $report->{$ticket};
    }
  }
  else {
    ## BLAST always gets queued, so redirect to status page (and then run in background)
    $script = 'Status';
    $new_param->{'status'} = $report->{$ticket};
  }

  $cgi->redirect($self->url('/Blast/'.$script, $new_param));
}


sub _create_object {
### Helper method - creates a fully-fledged Blast object in order to talk to the blast server
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
