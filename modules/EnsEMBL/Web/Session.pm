=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Session;

use strict;
use warnings;

use ORM::EnsEMBL::DB::Session::Manager::Session;
use ORM::EnsEMBL::DB::Session::Manager::Record;

use parent qw(EnsEMBL::Web::RecordManager);

use overload qw("" to_string bool to_boolean);

sub init {
  ## Abstract method implementation
  my $self  = shift;
  my $hub   = $self->hub;
  return unless $hub->r;

  # retrieve existing session cookie or create a new one
  my $cookie        = $hub->get_cookie($SiteDefs::ENSEMBL_SESSION_COOKIE, 1);
  my $cookie_host   = $SiteDefs::ENSEMBL_SESSION_COOKIEHOST;
  my ($actual_host) = split /\s*\,\s*/, ($hub->r->headers_in->{'X-Forwarded-Host'} || $hub->r->headers_in->{'Host'});

  if ($cookie_host && $actual_host =~ /$cookie_host$/) { # only use ENSEMBL_SESSION_COOKIEHOST if it's same or a subdomain of the actual domain
    $cookie->domain($cookie_host);
    $cookie->bake if $cookie->value;
  }

  $self->{'_session_cookie'}  = $cookie;
  $self->{'_session_id'}      = $cookie->value || undef; # if no session cookie exists, session id gets set later on a call to session_id method
}

sub record_rose_manager {
  ## Abstract method implementation
  return 'ORM::EnsEMBL::DB::Session::Manager::Record';
}

sub record_type {
  ## Abstract method implementation
  return 'session';
}

sub record_type_id {
  ## Abstract method implementation
  return shift->session_id;
}

sub session_id {
  ## Returns existing session id for the session or creates a new one if required
  ## @return Numeric String
  my $self = shift;

  if (!$self->{'_session_id'}) {

    my $session_id = ORM::EnsEMBL::DB::Session::Manager::Session->create_session_id;

    $self->{'_session_cookie'}->bake($session_id);
    $self->{'_session_id'} = $session_id;
  }

  # we have a session id now, so we are likely to make some changes to session records
  $self->_begin_transaction;

  return $self->{'_session_id'};
}

sub to_string {
  ## Get the session id if session object is used as a string
  ## @return (String) Session id
  return $_[0]->{'_session_id'} || '';
}

sub to_boolean {
  ## Tells whether session is already present/created or not
  ## @return Boolean
  return !!$_[0]->{'_session_id'};
}


use EnsEMBL::Web::Attributes;
sub get_data :Deprecated('Use get_record_data') {
  my $self = shift;
  return $self->get_record_data({@_});
}

1;
