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

package EnsEMBL::Web::ExtIndex::PFETCH;

use strict;
use warnings;

use Sys::Hostname;

use parent qw(EnsEMBL::Web::ExtIndex);

sub get_sequence {
  my ($self, $params) = @_;

  # Get the ID to pfetch
  my $str = $params->{'id'} or return;

  # Additional options
  $str .= " -D"         if ($params->{'options'} || '') eq 'desc';
  $str .= " $1"         if ($params->{'options'} || '') =~ /(-d\s+\w+)/;
  $str .= " -d public"  if $params->{'db'} eq 'PUBLIC';
  $str  = " -a $str"    if $params->{'db'} =~ /UNIPROT/;
  $str .= " -r"         if $params->{'strand_mismatch'};

  # Get the pfetch server
  my $sd      = $self->hub->species_defs;
  my $server  = $self->get_server($sd->ENSEMBL_PFETCH_SERVER, $sd->ENSEMBL_PFETCH_PORT);

  print $server sprintf("--client %s %s \n", hostname, $str);

  my @output  = $server->getlines;

  $server->close;

  return $self->output_to_fasta($params->{'id'}, \@output);
}

1;
