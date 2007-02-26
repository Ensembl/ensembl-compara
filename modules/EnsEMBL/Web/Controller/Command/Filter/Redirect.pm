package EnsEMBL::Web::Controller::Command::Filter::Redirect;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Controller::Command::Filter);

{

sub redirect {
  my ($self, $url) = @_;
  CGI::redirect($url);
}

sub inherit {
  my ($self, $parent) = @_;
  unshift @ISA, ref $parent;
  return 1;
}

}

1;
