package EnsEMBL::Web::Controller::Command::Filter::DataUser;

use strict;
use warnings;

use EnsEMBL::Web::Object::Data::User;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Controller::Command::Filter);

{

sub user {
  my $self = shift;
  my $reg_user = $ENSEMBL_WEB_REGISTRY->get_user;
  return EnsEMBL::Web::Object::Data::User->new({ id => $reg_user->id });
}

sub inherit {
  my ($self, $parent) = @_;
  unshift @ISA, ref $parent;
  return 1;
}

}

1;
