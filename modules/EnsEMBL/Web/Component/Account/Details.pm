package EnsEMBL::Web::Component::Account::Details;

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

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $dir = '/'.$ENV{'ENSEMBL_SPECIES'};
  $dir = '' if $dir !~ /_/;
  $html .= sprintf(qq(<dl class="summary">
                <dt>User name</dt>
                  <dd>%s</dd>
                <dt>Email address</dt>
                  <dd>%s</dd>
                <dt>Organisation</dt>
                  <dd>%s</dd>
                <dt>Date registered</dt>
                  <dd>%s</dd>
                <dt>Last updated</dt>
                  <dd>%s</dd>
              </dl>
      <p style="margin-top:10px"><a href="%s/Account/Update?_referer=%s" class="modal_link">Update these details &rarr;</a></p>),
      $user->name, $user->email, $user->organisation, 
      $self->pretty_date($user->created_at), $self->pretty_date($user->modified_at),
      $dir, CGI::escape($self->object->param('_referer')),
  );


  return $html;
}

1;
