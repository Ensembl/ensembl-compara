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

package EnsEMBL::Web::Tools::FailOver::DB;

use strict;
use warnings;

use DBI;

use parent qw(EnsEMBL::Web::Tools::FailOver);

sub db_details {
  ## should return {'host' => ?, 'port' => ?, 'username' => ?, 'password' => ?, 'database' => ?}
  die('Need to specify this in child class');
}

sub new {
  my ($proto, $hub, $species_defs) = @_;

  my $self    = bless {'hub' => $hub, 'species_defs' => $species_defs || $hub->species_defs}, $proto;
  my $details = $self->db_details;
  my $prefix  = sprintf 'db-%s-%s-%s-%s', $details->{'host'}, $details->{'port'}, $details->{'username'}, $details->{'database'};

  $self->{'prefix'} = $prefix;

  return $self;
}

sub hub               { return $_[0]{'hub'}; }
sub species_defs      { return $_[0]{'species_defs'}; }
sub fail_for          { return 60; }
sub failure_dir       { return $SiteDefs::ENSEMBL_FAILUREDIR; }
sub min_initial_dead  { return 0; }
sub successful        { return $_[1]; }

sub attempt {
  my ($self,$endpoint,$payload,$tryhard) = @_;

  my $details = $self->db_details;

  my $dbh = DBI->connect(
    sprintf('dbi:mysql:database=%s;host=%s;port=%s', $details->{'database'}, $details->{'host'}, $details->{'port'}),
    $details->{'username'},
    $details->{'password'},
    { RaiseError => 0, PrintError => 0 }
  );

  if ($dbh) {
    $dbh->disconnect;
    return 1;
  }

  return 0;
}

1;
