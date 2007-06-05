package EnsEMBL::Web::Controller::Command::User::RemoveInvite;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::Object::Data::Invite;
use EnsEMBL::Web::Document::HTML::SpeciesList;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter(EnsEMBL::Web::Controller::Command::Filter::LoggedIn->new);
  $self->add_filter(EnsEMBL::Web::Controller::Command::Filter::Redirect->new);
  $self->add_filter(EnsEMBL::Web::Controller::Command::Filter::DataUser->new);
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->filters->allow) {
    $self->render_page;
  } else {
    $self->render_message;
  }
}

sub render_page {
  my $self = shift;
  my $invite = EnsEMBL::Web::Object::Data::Invite->new({ id => $self->get_action->get_named_parameter('id') });
  if ($invite) {
    $invite->destroy;
  }
  $self->filters->redirect('/common/user/account');
}

}

1;
