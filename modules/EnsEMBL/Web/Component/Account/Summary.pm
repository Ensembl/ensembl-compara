package EnsEMBL::Web::Component::Account::Summary;

### Module to create user account home page

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Account);
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
  my $sitename = $self->site_name;
=pod

  $html .= qq(<p>This is your $sitename account home page. From here you can manage
                your saved settings, update your details and join or create new
                $sitename groups. To learn more about how to get the most
                from your $sitename account, read our <a href='/info/website/accounts.html'>introductory guide</a>.</p>);
=cut
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($user) {
    $html .= '<p>Logged in as: <strong>'.$user->name.'</strong></p>';
  }
  else {
    $html .= qq(<p><a href="">Log in</a> to your $sitename account, or <a href="/Account/Register">register</a>.</p>);
  }

  return $html;
}

1;
