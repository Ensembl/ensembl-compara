package EnsEMBL::Web::Controller::Action;

use strict;
use warnings;

use CGI;
use Class::Std;
use EnsEMBL::Web::ParameterSet;

{

my %URL :ATTR(:set<url> :get<url> :init_arg<url>);
my %Controller :ATTR(:set<controller> :get<controller>);
my %Action :ATTR(:set<action> :get<action>);
my %Id :ATTR(:set<id> :get<id>);
my %Parameters :ATTR(:set<params> :get<params>);

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_url($args->{url});
  my ($url, $params) = split(/\?/, $self->get_url);
  $self->set_params($self->parse_params($params));
  my ($trash, $base, $controller, $action, $id) = split('/', $url);
  $self->set_controller($controller);
  $self->set_action($action);
  $self->set_id($action);
}

sub script_name {
  my $self = shift;
  return $self->get_controller . "/" . $self->get_action;
}

sub get_named_parameter {
  my ($self, $name, $escaped) = @_;
  my $return = $self->get_params->{$name};
  unless ($escaped) {
    $return = CGI->unescape($return);
  }
  return $return; 
}

sub parse_params { 
  my ($self, $string) = @_;
  my $params = {};
  if ($string) {
    foreach my $p (split(/&|;/, $string)) {
      my ($key, $value) = split(/\=/, $p);
      $params->{$key} = $value;
    }
  } else {
    my $cgi = new CGI;
    foreach my $key (keys %{ $cgi->Vars }) {
      #warn "CHECKING: " . $key;
      my $value = $cgi->param($key);
      $value =~ s/<script(.*?)>/[script$1]/igsm; ## sanitize
      $params->{$key} = $value;
    }
  }
  return $params;
}

}
1;
