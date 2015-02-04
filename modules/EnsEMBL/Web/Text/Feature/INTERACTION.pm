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

package EnsEMBL::Web::Text::Feature::INTERACTION;

### Pair of features in a long-range interaction file

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature);

sub feature_1 {
  my $self = shift; 
  return $self->{'__raw__'}[0];
}

sub feature_2 {
  my $self = shift; 
  return $self->{'__raw__'}[1];
}

sub start_1 {
  my $self = shift; 
  return $self->{'start_1'} if $self->{'start_1'};
  my @coords = $self->_split_coords($self->{'__raw__'}[0]);
  return $coords[1]; 
}

sub end_1 {
  my $self = shift; 
  return $self->{'end_1'} if $self->{'end_1'};
  my @coords = $self->_split_coords($self->{'__raw__'}[0]);
  return $coords[2]; 
}

sub start_2 {
  my $self = shift; 
  return $self->{'start_2'} if $self->{'start_2'};
  my @coords = $self->_split_coords($self->{'__raw__'}[1]);
  return $coords[1]; 
}

sub end_2 {
  my $self = shift; 
  return $self->{'end_2'} if $self->{'end_2'};
  my @coords = $self->_split_coords($self->{'__raw__'}[1]);
  return $coords[2]; 
}

sub _seqname { 
  my $self = shift; 
  my @coords = $self->_split_coords($self->{'__raw__'}[0]);
  return $coords[0]; 
}

sub rawstart {
  my $self = shift; 
  return $self->start;
}

sub rawend {
  my $self = shift; 
  return $self->end;
}

sub start {
## If seeking a generic location, return first feature
  my $self = shift; 
  return $self->start_1; 
}

sub end {
## If seeking a generic location, return first feature
  my $self = shift; 
  return $self->end_1; 
}

sub coords {
## Return coordinates of the entire location
  my ($self, $data) = @_; 
  my @coords_1 = $self->_split_coords($data->[0]);
  my @coords_2 = $self->_split_coords($data->[1]);
  return ($coords_1[0], $coords_1[1], $coords_2[2]); 
}

sub _split_coords {
  my ($self, $f) = @_; 
  return split(/,|-|:/, $f);
}

sub _raw_score    { 
  my $self = shift;
  return $self->{'__raw__'}[2];
}

sub score {
  my $self = shift;
  $self->{'score'} = $self->_raw_score unless exists $self->{'score'};
  return $self->{'score'};
}

sub map {
  my( $self, $slice ) = @_;
  my $chr = $self->seqname();
  $chr=~s/^chr//;
  return () unless $chr eq $slice->seq_region_name;
  my $slice_end = $slice->end();
  return () unless $self->start_1 <= $slice_end;
  my $slice_start = $slice->start();
  return () unless $slice_start <= $self->end_2;
  $self->slide( 1 - $slice_start );

  if ($slice->strand == -1) {
    my $flip = $slice->length + 1;
    ($self->{'start_1'}, $self->{'end_1'}) = ($flip - $self->{'end_1'}, $flip - $self->{'start_1'});
    ($self->{'start_2'}, $self->{'end_2'}) = ($flip - $self->{'end_2'}, $flip - $self->{'start_2'});
  }
 
  return $self;
}

sub slide    {
  my $self = shift;
  my $offset = shift;
  $self->{'start_1'} = $self->start_1 + $offset;
  $self->{'end_1'}   = $self->end_1 + $offset;
  $self->{'start_2'} = $self->start_2 + $offset;
  $self->{'end_2'}   = $self->end_2 + $offset;
}


1;
