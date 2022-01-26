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

package EnsEMBL::Web::QueryStore::Source::SpeciesDefs;

use strict;
use warnings;

use EnsEMBL::Web::DBSQL::DBConnection;

sub new {
  my ($proto,$sd) = @_;

  my $class = ref($proto) || $proto;
  my $self = { _sd => $sd };
  bless $self,$class;
  return $self;
}

sub all_tables {
  my ($self,$species,$type) = @_;

  my $db_name = 'DATABASE_'.uc $type;
  my $info = $self->{'_sd'}->get_config($species,'databases');
  return {} unless $info and $info->{$db_name} and $info->{$db_name}{'tables'};
  return [ keys %{$info->{$db_name}{'tables'}} ];
}

sub table_info {
  my ($self,$species,$type,$table) = @_;

  return $self->{'_sd'}->table_info_other($species,$type,$table);
}

sub config {
  my ($self,$species,$var) = @_;

  return $self->{'_sd'}->get_config($species,$var);
}

sub multi {
  my ($self,$type,$species) = @_;

  return $self->{'_sd'}->multi($type,$species);
}

sub multi_val {
  my ($self,$type,$species) = @_;

  return $self->{'_sd'}->multi_val($type,$species);
}

sub multiX {
  my ($self,$type) = @_;

  return $self->{'_sd'}->multiX($type);
}

sub list_databases {
  my ($self,$species) = @_;

  my @dbs = (keys %{$self->config($species,'databases')||{}},
             @{$self->multi_val('compara_like_databases')||[]});
  # Remove DATABASE_, convert rest to lc
  @dbs = map { s/^DATABASE_//; $_ = lc $_; } @dbs;
  return \@dbs;
}

1;
