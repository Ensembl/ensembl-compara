package EnsEMBL::Web::Component::Account::Configurations;

### Module to create user saved config list

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

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $sitename = $self->site_name;
  my $has_configs = 0;

  if (!$has_configs) {
    $html .= qq(<p class="center"><img src="/img/help/config_example.gif" /></p>);
    $html .= qq(<p class="center">You haven't saved any $sitename view configurations. <a href='/info/website/custom.html#configurations'>Learn more about configurating views &rarr;</a>);

  }

  return $html;
}

1;
