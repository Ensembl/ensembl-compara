package EnsEMBL::Web::Controller::Command::Account::SelectGroup;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use Data::Dumper;

use base 'EnsEMBL::Web::Controller::Command::Account';

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  my $cgi = $self->action->cgi;
  my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;

  my ($records_accessor) = grep { $_ eq $cgi->param('type') } keys %{ $user->relations };
  ## TODO: this should use abstraction limiting facility rather then grep
  my ($user_record)      = grep { $_->id == $cgi->param('id') } $user->$records_accessor;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Owner', {'user_id' => $user_record->user_id});
}

sub process {
  my $self = shift;
  EnsEMBL::Web::Magic::stuff('Account', 'SelectGroup', $self, 'Popup');
}

}

1;
