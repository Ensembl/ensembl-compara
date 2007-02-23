package EnsEMBL::Web::Controller::Action;

use strict;
use warnings;

use Class::Std;

{

my %URL :ATTR(:set<url> :get<url> :init_arg<url>);
my %Controller :ATTR(:set<controller> :get<controller>);
my %Action :ATTR(:set<action> :get<action>);
my %Id :ATTR(:set<id> :get<id>);

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_url($args->{url});
  warn "New action with URL: " . $self->get_url;
  my ($url, $params) = split(/\?/, $self->get_url);
  my ($trash, $base, $controller, $action, $id) = split('/', $url);
  $self->set_controller($controller);
  $self->set_action($action);
  $self->set_id($action);
}

sub script_name {
  my $self = shift;
  return $self->get_controller . "/" . $self->get_action;
}

}

1;
