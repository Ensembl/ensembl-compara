=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Tools::FailOver::ORM;

use strict;
use warnings;

use EnsEMBL::Web::Exceptions;
use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_require);

use parent qw(EnsEMBL::Web::Tools::FailOver);

# DB type to be tested
sub db_type { die('Need to specify this in child class') }

sub new {
  my $proto = shift;

  my $db_type = $proto->db_type;
  my $self    = $proto->SUPER::new("orm-$db_type");
  my $db      = dynamic_require('ORM::EnsEMBL::Rose::DbConnection', 1);

  $self->{'db'}   = $db && $db->new(type => $db_type);

  return $self;
}

sub fail_for          { return 60; }
sub failure_dir       { return $SiteDefs::ENSEMBL_FAILUREDIR; }
sub min_initial_dead  { return 0; }
sub successful        { return $_[1]; }

sub attempt {
  my ($self,$endpoint,$payload,$tryhard) = @_;

  my $db_alive = 0;

  if ($self->{'db'}) {
    try {
      $self->{'db'}->init_dbh;
      $db_alive = 1;
    } catch {};
  }

  return $db_alive;
}

1;
