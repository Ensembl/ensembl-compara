=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

sub init {
  ## Abstract method implementation
  my $self  = shift;
  my $hub   = $self->hub;

  # retrieve existing session cookie or create a new one
  $self->{'_session_cookie'}  = $hub->get_cookie({'name' => $SiteDefs::ENSEMBL_SESSION_COOKIE, 'encrypted' => 1});
  $self->{'_session_id'}      = $self->{'_session_cookie'}->value || undef; # if no session cookie exists, session id gets set later on a call to session_id method
}

sub rose_manager {
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

sub is_present {
  ## Tells whether session is already present/created or not
  ## @return Boolean
  return exists $self->{'_session_id'};
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

1;
