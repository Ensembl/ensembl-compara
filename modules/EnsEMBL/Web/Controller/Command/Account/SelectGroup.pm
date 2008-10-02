package EnsEMBL::Web::Controller::Command::Account::SelectGroup;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use Data::Dumper;

use base 'EnsEMBL::Web::Controller::Command::Account';

use EnsEMBL::Web::Magic qw(modal_stuff);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  my $cgi = $self->action->cgi;
  my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;

  ## TODO: this replicates some of the filter Owner functionality - move into filter
  my $type = lc($cgi->param('type')).'s';
  my ($records_accessor) = grep { $_ eq $type } keys %{ $user->relations };
  ## TODO: this should use abstraction limiting facility rather then grep
  my ($user_record)      = grep { $_->id == $cgi->param('id') } $user->$records_accessor;
  my $owner_id = 0;
  if ($user_record) {
    $owner_id = $user_record->user_id;
  }
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Owner', {'user_id' => $owner_id});
}

sub process {
  my $self = shift;
  modal_stuff 'Account', 'SelectGroup', $self, 'Popup';
}

}

1;
