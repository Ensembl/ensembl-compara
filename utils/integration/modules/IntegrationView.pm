package IntegrationView;

use strict;
use warnings;

{

my %OutputLocation_of;
my %Server_of;

sub new {
  ### c
  ### Inside out view class for rendering output from Integration servers in HTML.
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $OutputLocation_of{$self} = defined $params{output} ? $params{output} : "";
  $Server_of{$self} = defined $params{server} ? $params{server} : undef;
  return $self;
}

sub server {
  ### a
  my $self = shift;
  $Server_of{$self} = shift if @_;
  return $Server_of{$self};
}

sub output_location {
  ### a
  my $self = shift;
  $OutputLocation_of{$self} = shift if @_;
  return $OutputLocation_of{$self};
}

sub message {
  my ($self, $message, $colour) = @_;
  $self->output_location($self->server->htdocs_location);
  if (-e $self->output_location) {
    open (OUTPUT, ">", $self->output_location . "/ssi/status.html") or die "$!: " . $self->output_location . "/ssi/status.html";
    print OUTPUT qq(
<div id="col-note" class="col-note-) . $colour . qq(">

<div id="col-note-status">
  <b>Integration status: </b> ) . $message . qq(
</div>
<div id="col-note-link">
  <a href="/harmony/">More &rarr;</a>
</div>

<br clear="all" />

</div>
                 );
  }
}

sub generate_html {
  my $self = shift;
  $self->output_location($self->server->htdocs_location);
  my $now = gmtime;
  open (OUTPUT, ">", $self->output_location . "/harmony/index.html") or return 0;
  print OUTPUT $self->html_header;
  print OUTPUT "<h3>Harmony</h3>";
  print OUTPUT "<h4>Last update: $now</h4>";
  if ($self->server->critical_fail eq 'yes') {
    my $rollback_event = $self->server->log->latest_ok_event;
    my $rollback_build = $rollback_event->{build};
    my $failed_event = $self->server->log->latest_event;
    my $failed_build = $failed_event->{build};
    print OUTPUT "<b>Build $failed_build failed with critical errors on " . $failed_event->{date} . ".</b> Harmony rolled back this server to build $rollback_build (" . $rollback_event->{date}. ")";

  } else {
    print OUTPUT "<b>This version of Ensembl is synchronised with the CVS head branch</b>\n";
  }
  print OUTPUT $self->test_results;
  print OUTPUT "<ul>\n";
  print OUTPUT "<li><a href='http://head.ensembl.org'>Return home</a></li>";
  print OUTPUT "<li><a href='about.html'>About Harmony</a></li>";
  print OUTPUT "<\ul>\n";
  print OUTPUT $self->html_footer;
  return 1;
}

sub test_results {
  my $self = shift;
  my $total = 0;
  my $passed = 0;
  my $failed = 0;
  my $critical = 0;
  foreach my $test (@{ $self->server->tests }) {
    $total++;
    if ($test->did_fail) {
      $failed++;
      if ($test->critical eq "yes") {
        $critical++;
      }
    } else {
      $passed++;
    }
  }
  my $html = "<h3>Tests</h3>";
  $html .= "Tests run: $total<br />\n";
  $html .= "Tests passed: $passed<br />\n";
  $html .= "Tests failed: $failed<br />\n";
  $html .= "Critical failures: $critical<br />\n";
  return $html;
}

sub html_header {
  my $self = shift;
  my $html = "";
  $html = qq(
    <html>
    <head>
      <title>Harmony : Ensembl continuous integration server</title>
    </head>
    <body>
  );

  return $html; 
}

sub html_footer {
  my $self = shift;
  my $html = "</body></html>";
  return $html; 
}

sub DESTROY {
  ### d
  my $self = shift;
  delete $OutputLocation_of{$self};
  delete $Server_of{$self};
}

}


1;
