package EnsEMBL::Web::Controller::Command::Filter::Admin;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Registry;
use EnsEMBL::Web::Object::Data::Group;
use EnsEMBL::Web::Object::Data::User;

our @ISA = qw(EnsEMBL::Web::Controller::Command::Filter);

{

my %GROUP_ID :ATTR(:set<group_id> :get<group_id>);

sub allow {
  my $self = shift;
  if ($self->get_group_id) {
    my $reg = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY;
    my $group = EnsEMBL::Web::Object::Data::Group->new({id=>$self->get_group_id});
    my $user = EnsEMBL::Web::Object::Data::User->new({id=>$reg->get_user->id});
    if ($user->is_administrator_of($group)) {
      return 1;
    }
  }
  return 0;
}

sub message {
  my $self = shift;
  return "You are not an administrator of this group.";
}

sub inherit {
  my ($self, $parent) = @_;
  unshift @ISA, ref $parent;
  return 1;
}

}

1;
