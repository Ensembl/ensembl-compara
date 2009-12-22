package EnsEMBL::Web::Component::Account::Details;

### Module to create user account home page

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::Account);

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

  my $user = $self->object->user;
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
      <p style="margin-top:10px"><a href="/Account/Update" class="modal_link">Update these details &rarr;</a></p>),
      $user->name, $user->email, $user->organisation, 
      $self->pretty_date($user->created_at), $self->pretty_date($user->modified_at),
  );

  return $html;
}

1;
