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

package EnsEMBL::Web::Component::DataExport::ExonSeq;

use strict;
use warnings;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Component::DataExport::Transcript);

sub configure_fasta {
  my $self = shift;
  my @fasta = EnsEMBL::Web::Constants::FASTA_OPTIONS;
  my @fasta_ok;

  foreach (@fasta) {
    push @fasta_ok, $_ unless $_->{'value'} =~ 'coding|cdna|peptide';
  }

  return @fasta_ok;
}

sub configure_fields {
  my ($self, $view_config) = @_;
  my @field_order = $view_config->field_order;

  return {
    'RTF'   => ['extra', @field_order,'variants_as_n'],
    'FASTA' => [qw(extra flanking)],
  };
}

1;
