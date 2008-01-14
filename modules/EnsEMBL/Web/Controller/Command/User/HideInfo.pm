package EnsEMBL::Web::Controller::Command::User::HideInfo;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::Infobox;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->filters->allow) {
    $self->process;
  } else {
    $self->render_message; 
  }
}

sub process {
  my $self = shift;
  my $cgi = new CGI;
  my $box = EnsEMBL::Web::Data::Infobox->new();

  $box->user_id($ENV{'ENSEMBL_USER_ID'});
  $box->name($cgi->param('id'));
  $box->save;

  print "Content-type: text/plain\n\n";
  print "Done:";
}

}

1;
