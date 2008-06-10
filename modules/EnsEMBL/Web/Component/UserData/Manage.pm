package EnsEMBL::Web::Component::UserData::Manage;

### Module to create user data home page

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::UserData);
use EnsEMBL::Web::Form;
use EnsEMBL::Web::RegObj;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return undef;
}

sub content {
  my $self = shift;
  my $html;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $sitename = $self->site_name;
  if ($user && $user->id) {
    $html .= '<p>You have lots of data!</p>';
  }
  else {
    $html .= "<p>Log into your $sitename account to manage your saved data</p>";
  }
  return $html;
}

1;
