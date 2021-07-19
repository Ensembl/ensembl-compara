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

package EnsEMBL::Draw::Utils::PairedFeature;

### A quick'n'dirty data module to bridge the gap between ensembl-io, 
### which outputs simple data structures, and the current drawing code, 
### which expects an object 

use strict;
use warnings;
no warnings "uninitialized";

use parent qw/EnsEMBL::Draw::Utils::Feature/;

sub map {
  my ($self, $slice) = @_;
  my $chr = $self->{'seqname'};
  $chr=~s/^chr//;
  return () unless $chr eq $slice->seq_region_name;
  my $slice_end = $slice->end();
  return () unless $self->start_1 <= $slice_end;
  my $slice_start = $slice->start();
  return () unless $slice_start <= $self->end_2;
  $self->slide(1 - $slice_start);

  if ($slice->strand == -1) {
    my $flip = $slice->length + 1;
    ($self->{'start_1'}, $self->{'end_1'}) = ($flip - $self->{'end_1'}, $flip - $self->{'start_1'});
    ($self->{'start_2'}, $self->{'end_2'}) = ($flip - $self->{'end_2'}, $flip - $self->{'start_2'});
  }

  return $self;
}

sub slide    {
  my ($self, $offset) = @_;
  $self->{'start_1'} = $self->start_1 + $offset;
  $self->{'end_1'}   = $self->end_1 + $offset;
  $self->{'start_2'} = $self->start_2 + $offset;
  $self->{'end_2'}   = $self->end_2 + $offset;
}


1;
