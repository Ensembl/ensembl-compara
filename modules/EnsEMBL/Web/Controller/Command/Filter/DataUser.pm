package EnsEMBL::Web::Controller::Command::Filter::DataUser;

use strict;
use warnings;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Controller::Command::Filter);

{

sub user {
  my ($self, $id) = @_;

  if ($id) {
    return EnsEMBL::Web::Data::User->new({ id => $id });
  }

  return $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;
}

sub inherit {
  my ($self, $parent) = @_;
  unshift @ISA, ref $parent;
  return 1;
}

}

1;
