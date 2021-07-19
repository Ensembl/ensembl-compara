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

package EnsEMBL::Draw::Utils::Feature;

### A quick'n'dirty data module to bridge the gap between ensembl-io, 
### which outputs simple data structures, and the current drawing code, 
### which expects an object 

use strict;
use warnings;
no warnings "uninitialized";

our $AUTOLOAD;

sub new {
  my ($class, $data) = @_;
  bless $data, $class;
  return $data;
}

sub map {
  my ($self, $slice) = @_;
  my $chr = $self->{'seqname'};
  $chr =~ s/^chr//;
  return () unless $chr eq $slice->seq_region_name;
  my $start = $self->rawstart();
  my $slice_end = $slice->end();
  return () unless $start <= $slice_end;
  my $end   = $self->rawend();
  my $slice_start = $slice->start();
  return () unless $slice_start <= $end;
  $self->slide(1 - $slice_start);

  if ($slice->strand == -1) {
    my $flip = $slice->length + 1;
    ($self->{'start'}, $self->{'end'}) = ($flip - $self->{'end'}, $flip - $self->{'start'});
  }

  return $self;
}

sub slide    {
  my ($self, $offset) = @_;
  $self->{'start'} = $self->rawstart + $offset;
  $self->{'end'}   = $self->rawend + $offset;
}

sub AUTOLOAD {
  my $self = shift;
  my $method = $AUTOLOAD =~ s/.*:://r;
  return $self->{$method};
}

sub DESTROY {}

1;
