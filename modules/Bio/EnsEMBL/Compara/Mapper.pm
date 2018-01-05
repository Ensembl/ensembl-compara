=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

=pod

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::Mapper - A specialised Mapper object with the ability to report gaps

=head1 DESCRIPTION

This mapper works in the same way as its superclass except it provides a method which is able
to return gaps in a mapper region much faster than normal. It does this by avoiding object
construction and returning the bare minimum information.

=cut

package Bio::EnsEMBL::Compara::Mapper;

use strict;
use warnings;

use base qw/Bio::EnsEMBL::Mapper/;

=head2 gaps_from_mapper

  Arg[1]     : string $id. ID of the 'source' sequence
  Arg[2]     : int $start. start coordinate of the 'source' sequence
  Arg[3]     : int $end. end coordinate of the 'source' sequence
  Arg[4]     : string $type. Nature of the transform. Gives the type of 
               coordinates to be transformed from
  Arg[5]     : int $min_gap_size. The minimum gap size to report. Defaults to 1
  Example    : my $gaps = $mapper->gaps_from_mapper('sequence', 1, 1000, 'sequence', 10);
  Description: Provides access to arrays of gap coordinates available from this 
               mapper for the given region. If no region is given then we will
               assume all gaps are to be reported (where gaps are over the given size)
  Returntype : ArrayRef of Arrays. Each array element is [$gap_start, $gap_end, $gap_length]

=cut

sub gaps_from_mapper {
  my ($self, $id, $start, $end, $type, $min_gap_size) = @_;

  $min_gap_size ||= 1; #Gap size we allow by default is 1
  my @gaps;

  if(! $self->_is_sorted()) {
    $self->_sort();
  }
  
  # Do a binary search for the region to start in
  my ($from, $to) = $type eq $self->{'to'} ? qw/to from/ : qw/from to/;
  my ( $start_idx, $end_idx, $mid_idx, $pair, $self_coord );
  my $hash = $self->{"_pair_$type"};
  my $pairs_array = $hash->{ uc($id) };
  $start_idx = 0;
  $end_idx   = $#{$pairs_array};
  
  # Start and end are set to the first and last mapped position if unset.
  $start ||= $pairs_array->[0]->{$from}->{start};
  $end ||= $pairs_array->[-1]->{$from}->{end};
  
  #If we had a submitted start then we have something to search for. Otherwise skip
  if($start > 1) {
    while ( ( $end_idx - $start_idx ) > 1 ) {
      $mid_idx    = ( $start_idx + $end_idx ) >> 1;
      $pair       = $pairs_array->[$mid_idx];
      $self_coord = $pair->{$from};
      if ( $self_coord->{'end'} < $start ) {
        $start_idx = $mid_idx;
      } else {
        $end_idx = $mid_idx;
      }
    }
  }

  #Take the first available coord as our starting coord
  my $last_unit = $pairs_array->[$start_idx]->{$from};
  
  #It's a gap! If the start is less than our original starting block
  if($start < $last_unit->{start}) {
    my $gap_end = $last_unit->{start} - 1;
    my $gap_diff = ($gap_end - $start)+1;
    push(@gaps, [$start, $gap_end, $gap_diff]) if $gap_diff > $min_gap_size;
  }
  
  #Now loop through the remainder. If we've exhausted the array then we will exit the loop early
  my $array_length = $#{$pairs_array};
  for(my $i = $start_idx+1; $i <= $array_length; $i++) {
    my $pair = $pairs_array->[$i];
    my $unit = $pair->{$from};
    my $last_unit_end = $last_unit->{end};
    #The moment we exceed the last unit end then we must bail
    if($last_unit_end > $end) {
      $last_unit = $unit;
      last;
    }
    my $gap_start = $last_unit->{end}+1;
    my $gap_end = $unit->{start} - 1;
    my $gap_diff = ($gap_end - $gap_start)+1;
    if($gap_diff > $min_gap_size) { #TODO check logic. Min gap size of 10 means nothing unless its 11
      push(@gaps, [$gap_start, $gap_end, $gap_diff]);
    }
    $last_unit = $unit;
  }
  
  #It's a gap! If the end is more than the end of the last block
  if($last_unit->{end} < $end) {
    my $gap_start = $last_unit->{end}+1;
    my $gap_diff = ($end - $gap_start)+1;
    push(@gaps, [$gap_start, $end, $gap_diff]) if $gap_diff > $min_gap_size;
  }
  
  return \@gaps;
}

1;