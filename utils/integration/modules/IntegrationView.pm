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
  open (OUTPUT, ">", $self->output_location . "/harmony/index.html") or return 0;
  print OUTPUT $self->html_header;
  print OUTPUT "Are you not entertained?";
  print OUTPUT $self->html_footer;
  return 1;
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
