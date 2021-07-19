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

package EnsEMBL::Web::SeqDumper;

use strict;
use Bio::EnsEMBL::Utils::SeqDumper;
use IO::String;

our @ISA = qw(Bio::EnsEMBL::Utils::SeqDumper);

=head2 EnsEMBL::Web::SeqDumper

This package is an extension of the Bio::EnsEMBL::Utils::SeqDumper
written so that it can print to a IO::String

=cut

sub dump {
  my ($self, $slice, $format) = @_;

  $format || throw("format arg is required");
  $slice  || throw("slice arg is required");

  my $dump_handler = 'dump_' . lc($format);
  
  my $fh = IO::String->new();
  
  if ($self->can($dump_handler)) {
    $self->$dump_handler($slice, $fh);
  }
  
  my $ref = $fh->string_ref();
  ${$ref} =~ s/\n/\r\n/g;
  
  return ${$ref};
}

1;
