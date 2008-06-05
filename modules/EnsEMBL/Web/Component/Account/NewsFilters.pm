package EnsEMBL::Web::Component::Account::NewsFilters;

### Module to create user news filter list

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
    $html .= qq(<p class="center"><img src="/img/help/filter_example.gif" alt="Sample screenshot" title="SAMPLE" /></p>);
    $html .= qq(<p class="center">You do not have any filters set, so you will see general headlines.</p>
<p><a href="/common/user/filter_news">Add a news filter &rarr;</a></p>
);
  }

  return $html;
}

1;
