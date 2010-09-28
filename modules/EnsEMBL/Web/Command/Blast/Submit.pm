package EnsEMBL::Web::Command::Blast::Submit;

### Command module to submit a new Blast query to the database
### and forward to an appropriate feedback page

use strict;
use warnings;
no warnings 'uninitialized';

use base 'EnsEMBL::Web::Controller::Command';

sub process {
  my $self = shift;
  my $object = $self->object;
  my $hub = $self->hub;
  my ($script, $new_param);

  my $ticket = $object->submit_query;

  $new_param->{'species'} = $hub->param('species');
  $new_param->{'ticket'} = $ticket;

  my $report = $object->get_status($ticket);
  if ($hub->param('method') eq 'BLAT' && $report->{'pending'}) {
    ## Run BLAT jobs immediately and get results
    $object->run_jobs($ticket);
    $report = $object->get_status($ticket);
    if ($report->{'complete'}) {
      $script = 'View';
      $new_param->{'run_id'} = $report->{'run_id'};
    }
    else {
      $script = 'Ticket';
      $new_param->{'status'} = $report->{$ticket};
    }
  }
  else {
    ## BLAST always gets queued, so redirect to status page (and then run in background)
    $script = 'Ticket';
    $new_param->{'status'} = $report->{$ticket};
  }

  $self->redirect($hub->url('/Blast/'.$script, $new_param));
}


1;
