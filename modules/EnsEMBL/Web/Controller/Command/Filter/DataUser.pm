package EnsEMBL::Web::Controller::Command::Filter::DataUser;

use strict;
use warnings;

use EnsEMBL::Web::Object::Data::User;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Controller::Command::Filter);

{

sub user {
  my ($self, $id) = @_;
  my $get_id = $id;
  if (!$id) {
    my $get_id = $ENSEMBL_WEB_REGISTRY->get_user->id;
  }
  return EnsEMBL::Web::Object::Data::User->new({ id => $get_id });
}

sub inherit {
  my ($self, $parent) = @_;
  unshift @ISA, ref $parent;
  return 1;
}

}

1;
