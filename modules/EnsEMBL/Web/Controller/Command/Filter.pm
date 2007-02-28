package EnsEMBL::Web::Controller::Command::Filter;

use strict;
use warnings;

use Class::Std;

{

my %Action :ATTR(:get<action> :set<action>);

sub redirect {
  return undef;
}

sub user {
  return undef;
}

sub header {
  return "";
}

sub allow {
  return 1;
}

sub message {
  return "";
}

}

1;
