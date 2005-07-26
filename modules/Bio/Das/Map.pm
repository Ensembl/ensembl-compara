package Bio::Das::Map;
# $Id$

use strict;
require Exporter;

use Bio::Root::RootI;
use Bio::Location::Simple;


our @ISA = qw(Exporter Bio::Root::RootI);
our @EXPORT = ();
our @EXPORT_OK = qw(print_location);
our $VERSION = '1.01';

use constant REF     => 0;
use constant OFFSET  => REF +1;
use constant LEN     => OFFSET + 1;

use constant SRC_SEG  => 0;
use constant TARG_SEG => SRC_SEG+1;
use constant FLIPPED  => TARG_SEG + 1;


my %DATA;

# coordinate mapping service

sub new {
  my $class = shift;
  my $name  = shift;
  my $self = bless \(my $fly);
  $DATA{$self}{name} = $name || $self;
  $self;
}

sub DESTROY {
  my $self = shift;
  delete $DATA{$self};
}

sub name {
  my $self = shift;
  my $d = $DATA{$self}{name};
  $DATA{$self}{name} = shift if @_;
  $d;
}

sub clip {
  my $self = shift;
  my $d = $DATA{$self}{clip};
  $DATA{$self}{clip} = shift if @_;
  $d;
}

sub add_segment {
  my $self = shift;
  my ($src,$target) = @_;  # either [ref,start,stop,strand] triplets or Bio::LocationI objects
  my ($src_ref,$src_offset,$src_len,$src_strand)     = $self->_location2offset($src);
  my ($targ_ref,$targ_offset,$targ_len,$targ_strand) = $self->_location2offset($target);
  my $src_seg   = [$src_ref,$src_offset,$src_len];
  my $targ_seg  = [$targ_ref,$targ_offset,$targ_len];
  my $alignment = [$src_seg,$targ_seg,$src_strand ne $targ_strand];
  $DATA{$self}{segments}{$src_ref}{$src_ref,$src_offset,$src_len}     = $src_seg;
  $DATA{$self}{segments}{$targ_ref}{$targ_ref,$targ_offset,$targ_len} = $targ_seg;
  push @{$DATA{$self}{alignments}{$src_ref}{child}},$alignment;
  push @{$DATA{$self}{alignments}{$targ_ref}{parent}},$alignment;
}

sub resolve {
  my $self = shift;
  my @result = $self->_resolve($self->_location2offset(@_));
  return $self->_offset2location(\@result);
}

sub project {
  my $self     = shift;
  my ($location,$target) = @_;
  my @location = $self->_location2offset($location);
  return $self->_offset2location([$self->_map2map(@location,$target,'parent'),
				  $self->_map2map(@location,$target,'child')]
				);
}

sub expand_segments {
  my $self = shift;
  my @parents  = $self->super_segments(@_);
  my @children = $self->sub_segments(@_);
  my ($me)     = $self->_offset2location([[$self->_location2offset(@_)]]);
  return (@parents,$me,@children);
}

# return mapping of all subsegments
sub sub_segments {
  my $self = shift;
  my @result = $self->_segments($self->_location2offset(@_),'child');
  return $self->_offset2location(\@result);
}

# return mapping of all subsegments
sub super_segments {
  my $self = shift;
  my @result = $self->_segments($self->_location2offset(@_),'parent');
  return $self->_offset2location(\@result);
}

sub _segments {
  my $self = shift;
  my ($ref,$offset,$len,$strand,$relationship) = @_;  # relationship = 'parent', 'child'
  my $alignments  = $self->_lookup_alignment($relationship,$ref,$offset,$len,$strand);
  my @result;
  for my $a (@$alignments) {
    my ($src,$targ) = $relationship eq 'parent' ? @{$a}[1,0] : @{$a}[0,1];
    my ($t_ref,$t_offset,$t_len,$t_strand) = 
      $self->_map_and_clip([$offset,$len,$strand],$src,$targ,$a->[2]);
    push @result,[$t_ref,$t_offset,$t_len,$t_strand];
    push @result,$self->_segments($t_ref,$t_offset,$t_len,$t_strand,$relationship);  # recurse
  }
  @result;
}

sub print_location {
  print $_->seq_id,':',$_->start,'..',$_->end," (",$_->strand,")\n" foreach @_;
}

# map given segment to all top-level coordinates by following parents
sub _resolve {
  my $self = shift;
  my ($ref,$offset,$len,$strand) = @_;

  my $alignments = $self->_lookup_alignment('parent',$ref,$offset,$len,$strand);
  my @result;

  push @result,[$ref,$offset,$len,$strand] unless @$alignments;

  for my $a (@$alignments) {
    my ($p_ref,$p_offset,$p_len,$p_strand) = $self->_map_and_clip([$offset,$len,$strand],$a->[1],$a->[0],$a->[2]);
    push @result,$self->_resolve($p_ref,$p_offset,$p_len,$p_strand); #recursive invocation
  }
  @result;
}

sub _map2map {
  my $self = shift;
  my ($ref,$offset,$len,$strand,$target,$relationship) = @_;  # relationship = 'parent', 'child'

  my $alignments  = $self->_lookup_alignment($relationship,$ref,$offset,$len,$strand);
  my @result;

  for my $a (@$alignments) {
    my ($src,$targ) = $relationship eq 'parent' ? @{$a}[1,0] : @{$a}[0,1];
    my ($p_ref,$p_offset,$p_len,$p_strand) = $self->_map_and_clip([$offset,$len,$strand],$src,$targ,$a->[2]);
    if ($p_ref eq $target) {
      push @result,[$p_ref,$p_offset,$p_len,$p_strand];
    } else {  # keep searching recursively
      push @result,$self->_map2map($p_ref,$p_offset,$p_len,$p_strand,$target,$relationship); #recursive invocation
    }
  }
  @result;
}

sub _offset2location {
  my $self = shift;
  my $array = shift;
  return map {
    my ($ref,$offset,$len,$strand) = @$_;
    Bio::Location::Simple->new(-seq_id  => $ref,
			       -start  => $offset+1,
			       -end    => $offset+$len,
			       -strand => $strand);
  } @$array;

}

sub lookup_segments {
  my $self   = shift;
  my $result = $self->_lookup_segments(@_);
  map {
    my ($ref,$offset,$len) = @$_;
    Bio::Location::Simple->new(-seq_id  => $ref,
			       -start  => $offset+1,
			       -end    => $offset+$len,
			       -strand => +1);
  } @$result;
}


# simple lookup of segments overlapping requested range
sub _lookup_segments {
  my $self    = shift;
  return [values %{$DATA{$self}{segments}{shift()}}] if @_ == 1;

  my ($ref,$offset,$len,$strand)     = $self->_location2offset(@_);

  my @search_space = values %{$DATA{$self}{segments}{$ref}} or return;
  my @result;
  for my $candidate (@search_space) {
    next unless $candidate->[OFFSET]+$candidate->[LEN] > $offset
      && $candidate->[OFFSET] < $offset + $len;
    push @result,$candidate;
  }
  return \@result;
}

sub _lookup_alignment {
  my $self = shift;
  my ($relationship,$ref,$offset,$len,$strand) = @_;
  my @result;

  my $search_space = $DATA{$self}{alignments}{$ref}{$relationship};
  for my $candidate (@$search_space) {
    my $seg = $relationship eq 'parent' ? $candidate->[1] : $candidate->[0];
    next unless $seg->[OFFSET]+$seg->[LEN] > $offset
      && $seg->[OFFSET] < $offset + $len;
    push @result,$candidate;
  }
  \@result;
}

sub _map_and_clip {
  my $self = shift;
  my ($range,$source,$dest,$flip) = @_;
  my ($offset,$len,$strand) = @$range;
  my $clip = $self->clip;

#  $offset = $flip ? $dest->[OFFSET] + $source->[OFFSET] - $offset
  $offset = $flip ? ($dest->[OFFSET] + $dest->[LEN] - 1) + $source->[OFFSET] - ($offset + $len - 1)
                  : $offset + $dest->[OFFSET]-$source->[OFFSET];

  if ($clip) {
    $offset  = $dest->[OFFSET]                       if $offset < $dest->[OFFSET];
    $len     = $dest->[OFFSET]+$dest->[LEN]-$offset  if $offset+$len > $dest->[OFFSET]+$dest->[LEN];
  }

  return ($dest->[REF],$offset,$len,$flip ? -$strand : $strand);
}

sub _location2offset {
  my $self  = shift;
  return ($_[0],$_[1]-1,$_[2]-$_[1]+1,+1)    if @_ == 3;  # (ref,offset,len)
  return ($_[0],$_[1]-1,$_[2]-$_[1]+1,$_[3]) if @_ >= 4;  # (ref,offset,len,strand)

  my $thing = shift;

  my ($ref,$offset,$len,$strand);
  if (ref($thing) eq 'ARRAY') {
    my ($id,$start,$end,$str) = @$thing;
    $offset  = $start - 1;
    $len     = $end - $start + 1;
    $strand  = +1 unless defined $strand;
    $ref     = $id;
    $strand  = $str || +1;
  }

  elsif (ref($thing) && $thing->isa('Bio::LocationI')) {
    $ref    = $thing->seq_id;
    $offset = $thing->start - 1;
    $len    = $thing->end - $thing->start + 1;
    $strand = $thing->strand || +1;
  }

  else {
    $self->throw('not a valid location object or array');
  }

  return ($ref,$offset,$len,$strand);
}


1;

__END__

=head1 NAME

Bio::Das::Map - Resolve map coordinates

=head1 SYNOPSIS

 use Bio::Das::Map 'print_location';

 my $m = Bio::Das::Map->new('my_map');
 $m->add_segment(['chr1',100,1000],['c1.1',1,901]);
 $m->add_segment(['chr1',1001,2000],['c1.2',501,1500]);
 $m->add_segment(['chr1',2001,4000],['c1.1',3000,4999]);
 $m->add_segment(['c1.1',4000,4999],['c1.1.1',1,1000]);

 my @abs_locations = $m->resolve('c1.1.1',500=>600);
 print_location(@abs_locations);

 for my $location (@abs_locations) {
    my @rel_locations = $m->project($location,'c1.1.1');
    print_location(@rel_locations);

    my @all_rel_locations = $m->sub_segments($location);
    print_location(@all_rel_locations);
 }


=head1 DESCRIPTION

This module provides the infrastructure for handling relative
coordinates in sequence annotations.  You use it by creating a "map"
that relates a set of sequence segment pairs.  The segments are
related in a parent/child relationship so that you can move "up" or
"down" in the hierarchy.  However the exact meaning of the paired
relationships is up to you; it can be chromosome->contig->clone,
scaffold->supercontig->contig->read, or whatever you wish.

Once the map is created you can perform the following operations:

=over 4

=item resolution to absolute coordinates

Given a sequence segment somewhere in the map, the resolve() call will
move up to the topmost level, translating the coordinates into
absolute coordinates.

=item directed projection to relative coordinates

Given a sequence segment somewhere in the map, the project() call will
attempt to project the coordinate downward into the specified
coordinate system, changing it into the corresponding relative
coordinates.

=item undirected projection

Given a sequence segment somewhere in the map, the sub_segments() call
will return all possible coordinates relative to the children of this
segment.  The super_segments() performs the opposite operation, moving
upwards in the hierarchy.

=back

Here is an example using ASCII art:

        100          1000           2000             4000
   chr1 |---------------|--------------|----------------|
        .               ..             .                .
        1             901.           3000    4000    4999
   c1.1 |---------------|.             .|-------|-------|
                         .             .        .       .
                       501           1500       .       .
   c1.2                  |-------------|        .       .
                                                .       .
                                                1    1000
   c1.1.1                                       |-------|


These relationships can be described with the following code fragment:

 my $m = Bio::Das::Map->new('my_map');
 $m->add_segment(['chr1',100,1000]  => ['c1.1',1,901]);
 $m->add_segment(['chr1',1001,2000] => ['c1.2',501,1500]);
 $m->add_segment(['chr1',2001,4000] => ['c1.1',3000,4999]);
 $m->add_segment(['c1.1',4000,4999] => ['c1.1.1',1,1000]);

A call to resolve() can now be used to transform a segment relative to
"c1.1.1" into "chr1" coordinates:

 my @chr1_coordinates = $m->resolve('c1.1.1',500=>600);

This will return the segment chr1:3500..3600.

Conversely a call to project() can be used to transform a segment
relative to "chr1" into "c1.1.1" coordinates:

 my @c1_1_1_coordinates = $m->project('chr1',3500=>3600,'c1.1.1');

As expected, this returns the segment c1.1.1:500..600.

=head1 METHODS

=over 4

=item $map = Bio::Das::Map->new('map_name')

Create a new Bio::Das::Map, optionally giving it name "map_name."

=item $name = $map->name(['new_name'])

Get or set the map name.

=item $clip_flag = $map->clip([$new_clip_flag])

Get or set the "clip" flag.  If the clip flag is set to a true value,
then requests for operations on coordinate ranges that are outside the
list of segments contained within the map will be clipped to that
portion of the coordinate range within known segments.  If the flag is
false, then the coordinate mapping routines will perform linear
extrapolation on those portions of the segments that are outside the
map.

The default is false.

=item $map->add_segment($segment1 => $segment2)

Establish a parent/child relationship between $segment1 and
$segment2. The two segments can be array references or Bio::LocationI
objects.  In the former case, the format of the array reference is:

  [$coordinate_system_name,$start,$end [,$strand]

$coordinate_system_name is any sequence ID.  $start and $end are the
usual BioPerl 1-based coordinates with $start <= $end.  The $strand is
one of +1, 0 or -1.  If not provided the strand is assumed to be +1.
A strand of zero is equivalent to a strand of +1 for the coordinate
calculations.

Bio::LocationI objects can be used for either or both of the
segments. For example:

 $map->add_segment(Bio::Location::Simple->new(-seq_id=>'chr1',-start=>4001,-end=>5000),
                   Bio::Location::Simple->new(-seq_id=>'c1.3',-start=>10,-end=>1009));

You can think of this operation as adding an alignment between two
sequences.

=item @abs_segments = $map->resolve($location)

Given a location, the resolve() method returns a list of corresponding
absolute coordinates by recursively following all parent segments
until it reaches a segment that has no parent.  There may be several
segments that satisfy this criteria, or none at all.  

The argument is either a Bio::LocationI, or an array reference of the
form [$seqid,$start,$end,$strand].  The returned list consists of a
set of Bio::Location::Simple objects.

=item @rel_segments = $map->project($location,$seqid)

Given a location and a sequence ID, the project() method attempts to
project the location into the coordinates specified by $seqid.
$location can be a Bio::LocationI object, or an array reference in the
format described earlier.  The method returns a list of zero or more
Bio::Location::Simple objects.

=item @subsegments = $map->sub_segments($location)

This method returns all Bio::LocationI segments that can be reached by
following $location's children downward.  $location is either a
Bio::LocationI or an array reference.  @subsegments are
Bio::Location::Simple objects.

=item @supersegments = $map->super_segments($location)

This method returns all Bio::LocationI segments that can be reached by
following $location's parents upwards.  $location is either a
Bio::LocationI or an array reference.  The return value is a list of
zero or more Bio::Location::Simple objects.

=item @allsegments = $map->expand_segments($location)

Returns all Bio::LocationI segments that are equivalent to the given
location, including the original location itself.  $location is either
a Bio::LocationI or an array reference.  The return value is a list of
one or more Bio::Location::Simple objects.

=item @segments = $map->lookup_segments($location)

Return a list of all segments that directly overlap the specified
location (without traversing alignments).  The location can be given
as an array reference or a Bio::LocationI.  As a special case, if you
provide a single argument containing a sequence ID, the method will
return all segments that use this sequence ID for their coordinate
system.

The return value is a list of zero or more Bio::Location::Simple
objects.

=item print_location($location)

This is a utility function (B<not> an object method) which given a
location will print it to STDOUT in the format:

  seqid:start..end (strand)

This function is not imported by default, but you can request that it
be imported into the caller's namespace by calling:

  use Bio::Das::Map 'print_location';

=back

=head1 LIMITATIONS

Everything is done in memory with unsorted data structures, which
means that large maps will have memory and/or performance problems.

=head1 AUTHOR

Lincoln Stein <lstein@cshl.org>.

Copyright (c) 2004 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=head1 SEE ALSO

L<Bio::Das::Request>, L<Bio::Das::HTTP::Fetch>,
L<Bio::Das::Segment>, L<Bio::Das::Type>, L<Bio::Das::Stylesheet>,
L<Bio::Das::Source>, L<Bio::RangeI>

