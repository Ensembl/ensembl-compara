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

### Module for retrieving sequences using the EBI dbfetch REST service

package EnsEMBL::Web::ExtIndex::DBFETCH;

use warnings;
use strict;

use EnsEMBL::Web::Exceptions;

use parent qw(EnsEMBL::Web::ExtIndex);

use constant DBFETCH_URL => 'http://www.ebi.ac.uk/Tools/dbfetch/dbfetch/%dbname%/%id%/fasta';

my $DB_NAMES = {
  'DEFAULT'             => 'embl',
  'emblcds'             => 'emblcds',
  'protein_id'          => 'emblcds',
  'refseq'              => 'refseq',
  'refseq_dna'          => 'refseq',
  'refseq_mrna'         => 'refseq',
  'refseq_peptide'      => 'refseq',
  'swiss-2dpage'        => 'uniprotkb',
  'uniprot'             => 'uniprotkb',
  'uniprotkb'           => 'uniprotkb',
  'uniparc'             => 'uniparc',
  'uniprot/swissprot'   => 'uniprotkb',
  'uniprot/sptrembl'    => 'uniprotkb'
};

sub get_sequence {
  ## Abstract method implementation
  ## @param Hashref with keys:
  ##  - id      Id of the object to retrieve sequence for
  ##  - db      Db name for the id provided
  my ($self, $params) = @_;

  my $id      = $params->{'id'} or throw exception('WebException', 'Id not provided');
  my $dbname  = $params->{'db'} or throw exception('WebException', 'DB name not provided');

  my $seq;

  if ($dbname eq 'PUBLIC') {
    $seq = $self->_get_sequence($id, $_) and last for qw(uniprot refseq embl);
  } else {
    $seq = $self->_get_sequence($id, $dbname);
  }

  return $self->output_to_fasta($id, [ split "\n", $seq || '' ]);
}

sub _get_sequence {
  ## @private
  my ($self, $id, $dbname) = @_;

  $dbname = $DB_NAMES->{lc $dbname =~ s/_predicted$//ir} || $DB_NAMES->{'DEFAULT'};
  $id     =~ s/\..+$// if grep { $dbname eq $_ } qw(embl emblcds refseq);

  my $seq = $self->do_http_request('GET', DBFETCH_URL =~ s/%dbname%/$dbname/r =~ s/%id%/$id/r);

  return if !$seq || $seq =~ m/no entries/i;

  return $seq;
}

1;
