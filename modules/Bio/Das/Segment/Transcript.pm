package Bio::Das::Segment::Transcript;

# this is a very crude transcript model
# it allows introns, exons and cds's
# no provision for utrs, splice sites, etc.

use strict;
use Bio::Das::Type;

use vars qw($VERSION @ISA);
@ISA = qw(Bio::Das::Segment::Feature);

# this is the type that we return
my $type = Bio::Das::Type->new('transcript','composite','transcription');

$VERSION = '0.01';

*sub_seqFeature = *merged_segments = *segments = \&exons;

sub start {
  my $self = shift;
  my $d;
  if (defined $self->{start}) {
    $d = $self->{start};
  } else {
    my @exons = $self->exons;
    $d = $exons[0]->start;
  }
  $self->{start} = shift if @_;  # explicitly set start
  $d;
}

sub stop {
  my $self = shift;
  my $d;
  if (defined $self->{stop}) {
    $d = $self->{stop};
  } else {
    my @exons = sort {$a->stop <=> $b->stop} $self->exons;
    $d = $exons[-1]->stop;
  }
  $self->{stop} = shift if @_;  # explicitly set start
  $d;
}

sub type     { $type }

sub add_cds {
  my $self = shift;
  my $segment = shift;
  $self->{cds} ||= [];
  push @{$self->{cds}},$segment;
}

sub add_exon {
  my $self = shift;
  my $segment = shift;
  $self->{exons} ||= [];
  push @{$self->{exons}},$segment;
  $self->{start} = $segment->start if $self->{start} > $segment->start;
  $self->{stop}  = $segment->stop  if $self->{stop}  < $segment->stop;
}

sub add_intron {
  my $self = shift;
  my $segment = shift;
  $self->{introns} ||= [];
  push @{$self->{introns}},$segment;
}

# return explicit exons
sub exons {
  my $self = shift;
  my $s = $self->{exons} or return;
  # the explicit assignment to @s is preventing some sort of weird
  # behavior in perl5.00503 involving scalar context on sort.
  my @s = sort {$a->start <=> $b->start} @{$s};
  @s;
}

# return explicit introns
sub introns {
  my $self = shift;
  my $s = $self->{introns} or return;
  my @s = sort {$a->start <=> $b->start} @{$s};
  @s;
}

# return explicit cds
sub cds {
  my $self = shift;
  my $s = $self->{cds} or return;
  my @s = sort {$a->start <=> $b->start} @{$s};
  @s;
}

1;

__END__

=head1 NAME

Bio::Das::Segment::Transcript - A transcript model

=head1 SYNOPSIS

  use Bio::Das;

  # contact a DAS server using the "elegans" data source
  my $das      = Bio::Das->new('http://www.wormbase.org/db/das' => 'elegans');

  # fetch a segment
  my $segment  = $das->segment(-ref=>'CHROMOSOME_I',-start=>10_000,-stop=>20_000);

  # get the transcripts
  my @transcript = $segment->features('transcript');

  # get the introns and exons from the first transcript
  my @introns = $transcript[0]->introns;
  my @exons   = $transcript[0]->exons;

  # get CDS - but this probably doesn't belong here
  my @cds     = $transcript[0]->cds;

=head1 DESCRIPTION

A Bio::Das::Segment::Transcript is a subclass of
Bio::Das::Segment::Feature that is specialized for representing the
union of introns and exons of a transcriptional unit.  It inherits all
the methods of its parent class, and adds methods for retrieving its
component parts.

The feature type of a Bio::Das::Segment::Transcript is "transcript"
and its method is "composite."

=head2 OBJECT CREATION

Bio::Das::Segment::Transcript objects are created by calling the
features() method of a Bio::Das::Segment object created earlier.  See
L<Bio::Das::Segment> for details.

=head2  OBJECT METHODS

All Bio::Das::Segment::Feature methods are available.  In particular,
the start() and stop() methods will return the start and end of the
most proximal and distal exons.

In addition, this class adds or implements the following methods:

=over 4

=item @introns = $feature->introns

The introns() method returns the introns of the transcript.  Each
intron is a Bio::Das::Segment::Feature object of type "intron".

=item @exons = $feature->exons

This method returns the exons.

=item @cds = $feature->cds

This method returns the CDS features associated with the transcript.
Since this has more to do with translation than transcription, it is
possible that this method will be deprecated in the future.

=item @segments = $feature->sub_seqFeature

This is an alias for exons(), and is compatible with the
Bio::SeqFeatureI interface.

=head1 AUTHOR

Lincoln Stein <lstein@cshl.org>.

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=head1 SEE ALSO

L<Bio::Das>, L<Bio::Das::Type>, L<Bio::Das::Segment>,
L<Bio::Das::Segment::Feature>, L<Bio::SeqFeatureI>

=cut

