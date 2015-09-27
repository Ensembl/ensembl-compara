=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::NewTable::Cache;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);
use JSON qw(from_json);

sub new {
  my ($proto,$hub) = @_;
  my $class = ref($proto) || $proto;
  my $self = {
    base => $hub->species_defs->ENSEMBL_TMP_DIR.'/table',
  };
  bless $self,$class;
  mkdir $self->{'base'};
  return $self;
}

sub _key {
  return md5_hex(JSON->new->canonical->encode($_[0]));
}

sub set {
  my ($self,$conf,$data) = @_;

  my $fn = $self->{'base'}.'/table_'._key($conf).'.json';
  open(FN,'>',"$fn.tmp") || return;
  print FN JSON->new->encode($data);
  close FN;
  rename("$fn.tmp",$fn);
}

sub get {
  my ($self,$conf) = @_;
  
  my $fn = $self->{'base'}.'/table_'._key($conf).'.json';
  return undef unless -e $fn;
  open(FN,$fn) || return undef;
  local $/ = undef;
  my $raw = <FN>;
  close FN;
  return JSON->new->decode($raw);
}

1;
