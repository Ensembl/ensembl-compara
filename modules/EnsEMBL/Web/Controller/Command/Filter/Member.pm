package EnsEMBL::Web::Controller::Command::Filter::Member;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Registry;
use EnsEMBL::Web::Data::Group;
use EnsEMBL::Web::Data::User;

our @ISA = qw(EnsEMBL::Web::Controller::Command::Filter);

{

my %GROUP_ID :ATTR(:set<group_id> :get<group_id>);

sub allow {
  my $self = shift;
  my $reg = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY;

  my $group = EnsEMBL::Web::Data::Group->new({id => $self->get_group_id});
  my $user = $reg->get_user;
  if ($user->is_member_of($group)) {
    return 1;
  }

  return 0;
}

sub message {
  my $self = shift;
  return "You are not a member of this group.";
}

}

1;
