package EnsEMBL::Web::Controller::Command::Filter;

use strict;
use warnings;

use Class::Std;

{

my %Action :ATTR(:get<action> :set<action>);

sub BUILD {
### We need to attach validation parameters directly to the filter, as
### passing them via CGI rather defeats the purpose!
  my ($self, $ident, $args) = @_;
  if ($args && ref($args) eq 'HASH') {
    while (my ($k, $v) = each (%$args)) {
      my $set_method = 'set_'.$k;
      $self->$set_method($v) if $self->can($set_method);
    }
  }
}

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
