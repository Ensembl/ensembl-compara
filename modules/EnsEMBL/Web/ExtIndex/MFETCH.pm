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

package EnsEMBL::Web::ExtIndex::MFETCH;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ExtIndex);

sub get_sequence {
  my ($self, $params) = @_;

  my $id  = $params->{'id'} or return;
  my $db  = $params->{'db'};
  my $sd  = $self->hub->species_defs;
  my $str = $id;

  # hack to get a CCDS record using mfetch - need a wildcard for version
  if ($db eq 'CCDS') {
    $id  .= '.*' unless $id =~ /\.\d{1,3}$/;
    $str  = qq(-d refseq -i ccds:${id}&div:NM -v fasta);
  }

  # get the sequence from the server
  my $server = $self->get_server($sd->ENSEMBL_MFETCH_SERVER, $sd->ENSEMBL_MFETCH_PORT);
  my @output;

  print $server "$str \n";

  for ($server->getlines) {
    last if @output && $_ =~ /^>/m; # only return one sequence (more than one can have the same CCDS attached)
    push @output, $_;
  }

  $server->close;

  return $self->output_to_fasta($params->{'id'}, \@output);
}

1;
