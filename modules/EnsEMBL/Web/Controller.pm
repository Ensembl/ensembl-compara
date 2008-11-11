package EnsEMBL::Web::Controller;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::Root;
use EnsEMBL::Web::Controller::Action;

{

my %URL        :ATTR(:set<url> :get<url>);
my %Connection :ATTR(:set<connections> :get<connections>);

sub BUILD {
    my( $self, $ident, $arg_ref ) = @_;
    ## Common error message node
    $self->add_connection({'Message' => 'EnsEMBL::Web::Controller::Command::Message'});
}

sub add_connections {
  my ($self, $connections) = @_;
  unless( $self->get_connections ) {
    $self->set_connections({});
  }
#  my $action = undef;
  foreach my $action (keys %{ $connections }) {
    $self->set_connection( $action, $connections->{$action});
  }
}

sub add_connection {
  my ($self, $connections) = @_;
  $self->add_connections( $connections );
}

sub get_connection {
  my ($self, $key) = @_;
  #warn "Getting: " . $key . ": " . $self->get_connections->{$key};
  return $self->get_connections->{$key};
}

sub set_connection {
  my ($self, $key, $value) = @_;
  $self->get_connections->{$key} = $value;
}

sub dispatch {
  my ($self, $url) = @_;
  #warn "Dispatch: $url";
  $self->set_url($url);
  $self->process;
}

sub get_action {
  my $self = shift;
  return EnsEMBL::Web::Controller::Action->new({ url => $self->get_url });
}

sub process {
  my $self = shift;
  my $action = $self->get_action;
  my $found = 0;

  #warn "ACTION: $action -> ",$action->get_action;
  my $action_key = $action->get_action;
  my $connections = $self->get_connections;
  if( $self->get_connections->{$action_key} ) {
    $self->command( $action );
  } else {
    warn "NO ROUTES FOUND FOR: " . $action->get_url;
  }
}

sub command {
  my ($self, $action) = @_;
  my $class = $self->get_connection($action->get_action);
  if (EnsEMBL::Web::Root::dynamic_use(undef, $class)) {
    warn "Dispatching to: " . $class . " (" . $action->get_action . ")";
    my $command = $class->new({'action'=>$action});
    $command->render;
  } else {
    warn "Cannot use $class";
  }
}

}

1;
