package EnsEMBL::Web::Controller::Action;

use strict;
use warnings;

use CGI;
use Class::Std;

{

my %URL :ATTR(:set<url> :get<url> :init_arg<url>);
my %CGI :ATTR(:set<cgi> :get<cgi> );
my %Controller :ATTR(:set<controller> :get<controller>);
my %Action :ATTR(:set<action> :get<action>);
my %Species :ATTR(:set<species> :get<species>);
my %Id :ATTR(:set<id> :get<id>);

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_url($args->{url});
  $self->set_cgi(new CGI);
  my ($url, $params) = split(/\?/, $self->get_url);
  my @path_bits = split /\//, $url;
  my $species = $ENV{'ENSEMBL_SPECIES'};
  $species = '' if $species !~ /_/;

  $self->set_controller($ENV{'ENSEMBL_TYPE'});
  $self->set_species($species);
  $self->set_action($path_bits[-1]);
}

sub cgi {
  my $self = shift;
  return $self->get_cgi;
}

sub script_name {
  my $self = shift;
  return $self->get_species . '/' . $self->get_controller . '/' . $self->get_action;
}

}
1;
