package Bio::Das::Segment::GappedAlignment;

use strict;
use vars qw($VERSION @ISA);
@ISA = qw(Bio::Das::Segment::Feature);

$VERSION = '0.01';

*segments = \&sub_seqFeature;

sub start {
  my $self = shift;
  my @merged = $self->merged_segments or return $self->SUPER::start(@_);
  $merged[0]->start;
}

sub stop {
  my $self = shift;
  my @merged = $self->merged_segments or return $self->SUPER::stop(@_);
  $merged[-1]->stop;
}

sub target {
  my $self = shift;
  my @merged = $self->merged_segments or return $self->SUPER::target;
  my ($t1,$s1,$e1) = $merged[0]->target;
  my ($t2,$s2,$e2) = $merged[-1]->target;
  return wantarray ? ($t1,$s1,$e2) : $t1;
}

sub add_segment {
  my $self = shift;
  my $segment = shift;
  $self->{segments} ||= [];
  push @{$self->{segments}},$segment;
}

# return subparts
sub sub_seqFeature {
  my $self = shift;
  my $s = $self->{segments} or return;
  @{$s};
}

sub merged_segments {
  my $self = shift;
  return @{$self->{merged_segs}} if $self->{merged_segs};
  my @s = $self->segments or return;

  # this statement was failing with an undefined object error,
  # which was very hard to track down
  #  my @segs = sort {$a->start <=> $b->start} @s;

  # the following is a reasonable workaround, but it
  # bears further investigation
  my %starts = map {$_ => $_->start} @s;
  my @segs  = sort {$starts{$a} <=> $starts{$b}} @s;

  # attempt to merge overlapping segments
  my @merged;
  for my $s (@segs) {
    my $previous = $merged[-1];
    if ($previous && $previous->end+1 >= $s->start) {
      $previous->{stop} = $s->end;     # extend current segment
    } else {
      my $clone = bless {%$s},ref($s); # copy segment (don't mess with originals)
      push @merged,$clone;
    }
  }
  $self->{merged_segs} = \@merged;
  return @merged;
}

1;

__END__

=head1 NAME

Bio::Das::Segment::GappedAlignment - A Gapped Aligment

=head1 SYNOPSIS

  use Bio::Das;

  # contact a DAS server using the "elegans" data source
  my $das      = Bio::Das->new('http://www.wormbase.org/db/das' => 'elegans');

  # fetch a segment
  my $segment  = $das->segment(-ref=>'CHROMOSOME_I',-start=>10_000,-stop=>20_000);

  # get the alignments
  my @alignments = $segment->features(-category=>'similarity');

  # get the segments from the first alignment
  my @segments = $alignments[0]->segments;

  # get the merged segments from the first alignment
  my @merged = $alignments[0]->merged_segments;

  # get segments the seqFeatureI way:
  my @segments = $alignments[0]->sub_seqFeature;

=head1 DESCRIPTION

A Bio::Das::Segment::GappedAlignment is a subclass of
Bio::Das::Segment::Feature that is specialized for representing
interrupted alignments.  It inherits all the methods of its parent
class, and adds methods for retrieving the individual aligned regions.

=head2 OBJECT CREATION

Bio::Das::Segment::GappedAlignment objects are created by calling the
features() method of a Bio::Das::Segment object created earlier.  See
L<Bio::Das::Segment> for details.

=head2  OBJECT METHODS

All Bio::Das::Segment::Feature methods are available.  In particular,
the start() and stop() methods will return the start and end of the
most proximal and distal aligned segments.  The target() method works
in the same way.

In addition, this class adds or implements the following methods:

=over 4

=item @segments = $feature->segments

The segments() method returns the aligned segments.  Each segment is a
Bio::Das::Segment::Feature object of category "similarity" (or
"homology" for compatibility with earlier versions of the spec).  The
segments are returned exactly as they were presented by the DAS
server, and in the same order.

=item @segments = $feature->merged_segments

This method works like segments() but adjusts the boundaries of the
segments so that overlapping segments are merged into single

=item @segments = $feature->sub_seqFeature

This is an alias for segments(), and is compatible with the
Bio::SeqFeatureI interface.

=back

=head1 AUTHOR

Lincoln Stein <lstein@cshl.org>.

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=head1 SEE ALSO

L<Bio::Das>, L<Bio::Das::Type>, L<Bio::Das::Segment>,
L<Bio::Das::Transcript>, L<Bio::Das::Segment::Feature>,
L<Bio::RangeI>

=cut

