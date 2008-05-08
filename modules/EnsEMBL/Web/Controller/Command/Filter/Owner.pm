package EnsEMBL::Web::Controller::Command::Filter::Owner;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Registry;

our @ISA = qw(EnsEMBL::Web::Controller::Command::Filter);

{

my %USER_ID :ATTR(:set<user_id> :get<user_id>);

sub allow {
  my $self = shift;
  my $reg = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY;
  if ($reg->get_user->id == $self->get_user_id) {
    return 1;
  }
  return 0;
}

sub message {
  my $self = shift;
  return "You are not the owner of this record.";
}


}

1;
