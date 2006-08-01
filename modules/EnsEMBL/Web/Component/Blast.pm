package EnsEMBL::Web::Component::Blast;

use EnsEMBL::Web::Component;
use EnsEMBL::Web::Component::Feature;

use strict;
use warnings;
no warnings "uninitialized";

use vars qw($UPDATE_DIV);

BEGIN {
  $UPDATE_DIV = 'blast_queue_ticket';
}

@EnsEMBL::Web::Component::Share::ISA = qw( EnsEMBL::Web::Component);

sub name {
  my($panel, $data) = @_;

  my $label = 'Blast';
  my $html = "<dl>Ready to rock</dl>";
  $panel->add_row( $label, $html );
  return 1;
}

sub blast_home {
  my ( $panel, $object, $node ) = @_;
  my $wizard = $panel->{wizard};
  $node = "blast_home";
  my $header = &render_progress_bar($wizard, $node) . "<div class='wizard'>\n";
  my $form = $panel->form($node);
  my $footer = &render_previous_searches_form;
  $footer .= qq(</div>\n);
  $panel->print($header. $form->render() . $footer); 
  return 1;
}


sub blast_info {
  my ( $panel, $object, $node ) = @_;
  $node = "blast_info";
  my $wizard = $panel->{wizard};
  my $header = &render_progress_bar($wizard, $node) . "<div class='wizard'>\n";
  my $form = $panel->form($node);
  my $footer = "</div>";
  $panel->print($header . $form->render() . $footer); 
  return 1;
}


sub blast_prepare {
  my ( $panel, $object, $node ) = @_;
  $node = "blast_prepare";
  my $wizard = $panel->{wizard};
  my $header = &render_progress_bar($wizard, $node) . "<div class='wizard'>\n";
  my $form = $panel->form($node);
  my $footer = qq(</div>);
  $panel->print($header . $form->render() . $footer); 
  return 1;
}

sub blast_submit {
  my ( $panel, $object, $node ) = @_;
  $node = "blast_submit";

  $object->request->update($object);

  my $pending = $object->job->queue_length;
  my $running = $object->job->running_jobs;
  my $wait_time = $object->job->wait_time;

  $object->job->create_ticket_with_request($object->request);

  my $html = "Ticket ID: " . $object->job->id;
  $html .= "<br />";

  if ($pending == 0) {
    $html .= "The Ensembl search queue is currently empty. Your job should begin shortly.";
  } else {
    if ($running > 0) {
      $html .= "Your job has been submitted, and is currently at position $pending in the Ensembl search queue. There are currently $running active jobs. We estimate the wait time until your job starts as $wait_time.";
    } else {
      $html .= "Your job has been submitted to the Ensembl search queue and should begin soon. The queue currently has $pending jobs pending. We estimate the wait time until your job starts as $wait_time.";
    }
  }
 
  my $javascript_delay = 15000;     # time between delays in milliseconds
  my $update_div = "update_queue";

  $html .= qq(
    <div id="$update_div">
      Waiting for update...
    </div>
  );

  $html .= qq(<br /><br /><a href="#" onclick="javascript:start_periodic_updates($javascript_delay, '$update_div')">Start periodic updates</a>);

  $panel->print($html); 

  return 1;
}

sub blast_ticket {
  my($panel, $object) = @_;
  my $request = $object->blast_adaptor->job_with_ticket($object->param('ticket'));

  $object->job->ticket($request->ticket);

  my $pending = $object->job->queue_length;
  my $queue_position = $object->job->position_in_queue;
  my $running = $object->job->running_jobs;
  my $wait_time = $object->job->wait_time;
  my $html;

  if (!$request) {
    $panel->print(qq(Ticket not found!));
  } else {
    $panel->print("This is the ticket view for ticket: " . $request->ticket);
    $html .= "<br />";

    if ($pending == 0) {
      $html .= "The Ensembl search queue is currently empty. Your job should begin shortly.";
    } else {
      if ($running > 0) {
        $html .= "Your job has been submitted, and is currently at position $queue_position of $pending in the Ensembl search queue. There are currently $running active jobs. We estimate the wait time until your job starts as $wait_time.";
      } else {
        $html .= "Your job has been submitted to the Ensembl search queue and should begin soon. The queue currently has $pending jobs pending. We estimate the wait time until your job starts as $wait_time.";
      }
    }
 
    my $javascript_delay = 15000;     # time between delays in milliseconds
    my $update_div = "update_queue";

    $html .= qq(
      <div id="$update_div">
        Waiting for update...
      </div>
    );

    $html .= qq(<br /><br /><a href="#" onclick="javascript:start_periodic_updates($javascript_delay, '$update_div')">Start periodic updates</a>);

    $panel->print($html); 
  }

  return 1;
}

sub render_progress_bar {
  my ($wizard, $current_node) = @_;
  my @nodes = $wizard->nodes_in_progress_bar; 
  my $todo = 0;
  my $class = "";
  my $width = sprintf("%.0f", 100 / $#nodes);
  my $html = "\n<div class='progress_bar'>";
  $html .= qq(<table width="90%" cellpadding="2" cellspacing="0"><tr>\n);
  foreach my $node (@nodes) {
    $class = "class='todo'" if $todo;
    $html .= "<td $class width='$width'>" . $node->{'progress_label'} . "</td>\n";
    warn "NAME: " . $node->{'name'};
    warn "CURRENT: " . $current_node;
    if ($node->{'name'} eq $current_node) {
      $todo = 1;
    }
  }
  $html .= qq(</tr></table>\n</div>\n);
  return $html;
}

sub searchview {
  my($panel, $object) = @_;
  my $ticket = $object->param('ticket');

  my $request = $object->blast_adaptor->job_with_ticket($object->param('ticket'));
  
  my $header= qq(
    <h2>Blast search: $ticket</h2>
    <div class="content"><div class="autocenter">
  );
  my $html = "";
  my $footer = "</div></div>";

  if ($request) {
    $html = &render_ticket($object, $request);
  } else {
    $html = &render_ticket_does_not_exist($object);
  }

  $panel->print($header . $html . $footer);
}

sub render_ticket_with_ticket {
  my $ticket = shift;
  return $ticket;
}

sub render_ticket {
  my ($object, $request) = @_;

  my $ticket = $request->ticket;
  $object->job->ticket($ticket);

  warn "STATUS: " . $request->status;
  my $html = "";

  $html = "<div id='$UPDATE_DIV'>";  
  if ($request->status == EnsEMBL::Web::DBSQL::BlastAdaptor::status_pending) {
    my $pending = $object->job->queue_length;
    my $queue_position = $object->job->position_in_queue;
    my $running = $object->job->running_jobs;
    my $wait_time = $object->job->wait_time;

    $html .= &render_pending( { 'pending' => $pending,
			        'queue_position' => $queue_position,
                                'running' =>  $running, 
                                'wait_time' => $wait_time,
                                'ticket' => $ticket
                              } );
  } elsif ($request->status == EnsEMBL::Web::DBSQL::BlastAdaptor::status_running) {
    my $pending = $object->job->queue_length;
    my $queue_position = $object->job->position_in_queue;
    my $running = $object->job->running_jobs;
    my $wait_time = $object->job->wait_time;

    $html .= &render_running( { 'pending' => $pending,
			        'queue_position' => $queue_position,
                                'running' =>  $running, 
                                'wait_time' => $wait_time,
                                'ticket' => $ticket
                              } );
  } elsif ($request->status == EnsEMBL::Web::DBSQL::BlastAdaptor::status_complete) {
    my $pending = $object->job->queue_length;
    my $queue_position = $object->job->position_in_queue;
    my $running = $object->job->running_jobs;
    my $wait_time = $object->job->wait_time;

    $html .= &render_complete( { 'pending' => $pending,
			         'queue_position' => $queue_position,
                                 'running' =>  $running, 
                                 'wait_time' => $wait_time,
                                 'ticket' => $ticket
                              } );
 
  }

  $html .= "</div>"; 

  return $html;
}

sub render_complete {
   my $parameters = shift;
   my $pending = $parameters->{'pending'};
   my $queue_position = $parameters->{'queue_position'};
   my $running = $parameters->{'running'};
   my $wait_time = $parameters->{'wait_time'};
   my $ticket = $parameters->{'ticket'};
   my $html_status = 'update_status';
   my $javascript_delay = 10000; # ms

   my $html = "";
   $html .= "<div class='wizard_check'>";  
   $html .= &render_complete_message($pending, $queue_position, $wait_time);
   $html .= "</div>";
   return $html;
}

sub render_running {
   my $parameters = shift;
   my $pending = $parameters->{'pending'};
   my $queue_position = $parameters->{'queue_position'};
   my $running = $parameters->{'running'};
   my $wait_time = $parameters->{'wait_time'};
   my $ticket = $parameters->{'ticket'};
   my $html_status = 'update_status';
   my $javascript_delay = 10000; # ms

   my $html = "";
   $html .= "<div id='blast_queue_message'>";  
   $html .= &render_running_message($pending, $queue_position, $wait_time);
   $html .= "<br /><br />";
   $html .= qq(<span id='$html_status'>This page will update automatically.</span> [ <a href="#" onclick="javascript:start_periodic_updates($javascript_delay, '$UPDATE_DIV', '$ticket', '$html_status')">&rarr;</a> ]);
   $html .= "</div>"; 
   $html .= "<div id='blast_queue_stamp'>";  
   $html .= &render_queue_stamp( {
                                'header' => "<i>e<font color='#880000'>!</font></i>",
                                'footer' => "Searching...",
                                'status' => 1 });
   $html .= "</div>"; 
   $html .= "<br clear='all' />";
   $html .= &render_evangelism;
   return $html;
}

sub render_pending {
   my $parameters = shift;
   my $pending = $parameters->{'pending'};
   my $queue_position = $parameters->{'queue_position'};
   my $running = $parameters->{'running'};
   my $wait_time = $parameters->{'wait_time'};
   my $ticket = $parameters->{'ticket'};
   my $status = 0;
   my $html_status = 'update_status';
   my $javascript_delay = 10000; # ms

   my $html = "";
   $html .= "<div id='blast_queue_message'>";  
   $html .= &render_pending_message($pending, $queue_position, $wait_time);
   $html .= "<br /><br />";
   $html .= qq(<span id='$html_status'>This page will update automatically.</span> [ <a href="#" onclick="javascript:start_periodic_updates($javascript_delay, '$UPDATE_DIV', '$ticket', '$html_status')">&rarr;</a> ]);
   $html .= "</div>"; 
   $html .= "<div id='blast_queue_stamp'>";  
   $html .= &render_queue_stamp( {
                                'header' => $queue_position,
                                'footer' => $wait_time,
                                'status' => $status });
   $html .= "</div>"; 
   $html .= "<br clear='all' />";
   $html .= &render_evangelism;
   return $html;
}

sub render_ticket_does_not_exist { 
  my $html = qq(We couldn't find that search ticket. You can try again below. Searches remain saved for 7 days.<br /><br />);
  $html .= &render_previous_searches_form;
  return $html;
}

sub render_complete_message {
  my $html = qq(<h1>Search complete</h1>
                Your search has been completed by Ensembl. <a href='#'>View results</a>);
  return $html;
}

sub render_running_message {
  my $html = "Your search is currently being performed by Ensembl. A link to the results will appear on this page once your search is complete.";
  return $html;
}

sub render_pending_message {
    my ($pending, $queue_position, $wait_time) = @_;
    my $html .= qq(Your search has been submitted to Ensembl, and is currently <b>number $queue_position in a queue of $pending searches</b>. Your search will start as soon as a Blast service becomes available, which should be <b>in $wait_time</b>.); 
   return $html;
}

sub render_queue_stamp {
  my $parameters = shift;

  my $header = $parameters->{'header'};
  my $footer = $parameters->{'footer'};
  my $status = $parameters->{'status'};
  my $suffix = "";
  my $class = "pending";

  if ($header / 1) {
    $suffix = &suffix_for_number($header);
  }

  if ($status == 1) {
    $class = "running";
  }

  my $html = qq(
    <div id='blast_queue_stamp_content'>
    <table width='70%' cellpadding='5' cellspacing='0'>
    <tr>
     <td><h1>$header<sup>$suffix</sup></h1></td>
    </tr>
    <tr>
     <td class='time'>$footer</td>
    </tr>
    </table></div>
  );
  return $html;
}

sub suffix_for_number {
  my $number = shift;
  my $suffix = "th";
  if ($number =~ /1$/) { 
    $suffix = "st";
  } elsif ($number =~ /2$/) {
    $suffix = "nd";
  } elsif ($number =~ /3$/) {
    $suffix = "rd";
  }
  return $suffix;
}

sub render_previous_searches_form {
  my $html = qq(
    <div class='wizard_previous'>
      <b>Previous searches</b>
      <div class='wizard_check'>
        <div id='wizard_ticket'>
          <b>Retrieve search results:</b><br /> 
          <form method="get" action="searchview">
            <input type="text" name="ticket" id="ticket" value="Ticket number">
            <input type="submit" value="Look up >" class="red-button">
          </form>
        </div>
        <div id='wizard_login'>
          <b>Your searches</b><br />
	  If you're a member of Ensembl you can <a href="#">log in</a> to view your previous
          search results. <a href="#">Joining</a> takes seconds and is free.
        </div>
      </div>
    </div>
  ); 
  return $html;
}

sub render_evangelism {
  my $html = "<div id='evangelism_container'>";
  $html .= "<div id='evangelism_title'><i>e<font color='#880000'>!</font></i> vangelism while you wait:</div>";
  $html .= "<div id='evangelism_content'>Opossum MonDom 4.0 is now in Ensembl. <a href='#'>&rarr;</a></div>";
  $html .= "</div>";
  return $html;
}

1;
