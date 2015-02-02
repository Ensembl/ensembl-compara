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
  my @coords = $self->_split_coords($self->{'__raw__'}[0]);
  return $coords[1]; 
}

sub end_1 {
  my $self = shift; 
  my @coords = $self->_split_coords($self->{'__raw__'}[0]);
  return $coords[2]; 
}

sub start_2 {
  my $self = shift; 
  my @coords = $self->_split_coords($self->{'__raw__'}[1]);
  return $coords[1]; 
}

sub end_2 {
  my $self = shift; 
  my @coords = $self->_split_coords($self->{'__raw__'}[1]);
  return $coords[2]; 
}

sub _seqname { 
  my $self = shift; 
  my @coords = $self->_split_coords($self->{'__raw__'}[0]);
  return $coords[0]; 
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
## If seeking a generic location, return first feature
  my $self = shift; 
  my @coords = $self->_split_coords($self->{'__raw__'}[0]);
  $coords[0] =~ s/chr//;
  return @coords; 
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

1;
