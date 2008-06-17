package EnsEMBL::Web::Controller::Command::UserData::Attach;

use strict;
use warnings;

use Class::Std;

use base 'EnsEMBL::Web::Controller::Command::UserData';

{

sub BUILD {
  my ($self, $ident, $args) = @_;
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->not_allowed) {
    $self->render_message;
  } else {
    $self->render_page;
  }
}

sub render_page {
use EnsEMBL::Web::Document::Wizard;
EnsEMBL::Web::Document::Wizard::simple_wizard('UserData', 'Attach', 'attach');
}

}

1;
