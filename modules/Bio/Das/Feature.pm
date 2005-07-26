package Bio::Das::Feature;

use strict;
use vars qw($VERSION @ISA);
use overload '""' => 'toString',
             cmp  => '_cmp';

use Bio::Root::Root;
use Bio::Das::Util;  # for rearrange

# we follow the SeqFeatureI interface but don't actually need
# to load it.
use Bio::SeqFeatureI;
@ISA = qw(Bio::Root::Root Bio::SeqFeatureI Bio::PrimarySeqI);
$VERSION = '0.90';

# aliases for Ace::Sequence::Feature compatibility
*subtype   = \&method;
*segments  = *sub_seqFeature = \&get_SeqFeatures;
*display_id= *info      = *display_name   = \&label;
*seq_id    = \&refseq;
*make_link = \&link;
*desc      = \&description;

sub new {
  my $class = shift;
  my ($segment,$id,$start,$stop) = rearrange([qw(segment id start stop)],@_);
  return bless { segment => $segment,
		 id     => $id,
		 start  => $start,
		 stop   => $stop,
	       },$class;
}

sub clone {
  my $self = shift;
  my %new  = %$self;
  my $clone =  bless \%new,ref $self;
  if (ref(my $t = $clone->type)) {
    my $type = $t->can('clone') ? $t->clone : bless {%$t},ref $t;
    $clone->type($type);
  }

  if (ref(my $g = $clone->group)) {
    my $group = $g->can('clone') ? $g->clone : bless {%$g},ref $g;
    $clone->group($group);
  }
  $clone;
}

sub segment {
  my $self = shift;
  my $d    = $self->{segment};
  $self->{segment} = shift if @_;
  $d;
}

sub start {
  my $self = shift;
  my $d    = $self->{start};
  $self->{start} = shift if @_;
  $d;
}

sub stop {
  my $self = shift;
  my $d    = $self->{stop};
  $self->{stop} = shift if @_;
  $d;
}

sub length {my $self = shift; $self->stop-$self->start+1}

sub refseq { shift->segment->refseq }

sub id {
  my $self = shift;
  my $d = $self->{id};
  $self->{id} = shift if @_;
  $d;
}

sub label {
  my $self = shift;
  my $d = $self->{label};
  $self->{label} = shift if @_;
  $d;
}

sub notes {
  my $self = shift;
  return unless exists $self->{note};
  @{$self->{note}};
}

sub note {
  my $self = shift;
  my $d = $self->{note};
  $self->{note} = shift if @_;
  $d;
}

sub add_note {
  my $self = shift;
  push @{$self->{note}},shift;
}

sub target {
  my $self = shift;
  my $d = $self->{target};
  if (@_) {
    my ($id,$start,$stop) = @_;
    $self->{target} = [ $id,$start,$stop ];
  }
  return unless $d;
  return wantarray ? @$d        # (id,start,stop,label) in list context
                   : ref($self)->new($self->segment,@$d);# a Feature object in scalar context
}

sub target_id {
  my $self = shift;
  return $self->{'target'}[0] if exists $self->{'target'} && ref $self->{'target'} eq 'ARRAY';
}

sub target_start {
  my $self = shift;
  return $self->{'target'}[1] if exists $self->{'target'} && ref $self->{'target'} eq 'ARRAY';
}

sub target_stop {
  my $self = shift;
  return $self->{'target'}[2] if exists $self->{'target'} && ref $self->{'target'} eq 'ARRAY';
}

sub type {
  my $self = shift;
  my $d = $self->{type};
  $self->{type} = shift if @_;
  $d;
}

sub method {
  my $self = shift;
  my $type = $self->type or return;
  $type->method(@_);
}

sub category {
  my $self = shift;
  my $type = $self->type or return;
  eval {$type->category} || $type->method;
}

sub reference {
  my $self = shift;
  my $type = $self->type or return;
  $type->reference;
}

sub score {
  my $self = shift;
  my $d = $self->{score};
  $self->{score} = shift if @_;
  $d;
}

sub orientation {
  my $self = shift;
  my $d = $self->{orientation};
  $self->{orientation} = shift if @_;
  $d;
}

sub phase {
  my $self = shift;
  my $d = $self->{phase};
  $self->{phase} = shift if @_;
  $d;
}

sub group {
  my $self = shift;
  my $d = $self->{group};
  $self->{group} = shift if @_;
  $d;
}

sub group_type {
  my $self = shift;
  my $d = $self->{group_type};
  $self->{group_type} = shift if @_;
  $d;
}

sub group_label {
  my $self = shift;
  my $d = $self->{group_label};
  $self->{group_label} = shift if @_;
  $d;
}

sub link {
  my $self = shift;
  my $d = $self->{link};
  $self->{link} = shift if @_;
  $d;
}

sub link_label {
  my $self = shift;
  my $d = $self->{link_label};
  $self->{link_label} = shift if @_;
  $d;
}

sub add_link {
  my $self = shift;
  push @{$self->{link}},shift;
}

sub add_link_label {
  my $self = shift;
  push @{$self->{link_label}},shift;
}

sub links {
  my $self = shift;
  return unless exists $self->{link};
  @{$self->{link}};
}

sub link_labels {
  my $self = shift;
  return unless exists $self->{link_label};
  @{$self->{link_label}};
}

sub target_label {
  my $self = shift;
  my $d = $self->{target_label};
  $self->{target_label} = shift if @_;
  $d;
}

sub description {
  my $self = shift;
  $self->note || $self->link_label || $self->target_label;
}

sub end { shift->stop(@_) }

sub toString {
  my $self = shift;
  return $self->label || $self->id || ref($self);
}

# for aceperl compatibility
sub strand {
  my $s = shift->{orientation};
  return 0 if $s eq '.';
  return '+1' if $s eq '+';
  return '-1' if $s eq '-';
  $s;
}

sub reversed {
  return shift->strand eq '-';
}

sub seq {
  my $self = shift;
  my $seg    = $self->segment or return;
  my $das    = $seg->das or return;
  my $newseg = $das->segment($self->seq_id,$self->start,$self->end);
  my $dna = $newseg->dna;
  if ($self->strand < 0) {
    $dna =~ tr/gatcGATC/ctagCTAG/;
    $dna = reverse $dna;
  }
  $dna;
}

=head2 get_SeqFeatures

 Title   : get_SeqFeatures
 Usage   : @feat = $feature->get_SeqFeatures([$method])
 Function: get subfeatures
 Returns : a list of Bio::DB::GFF::Feature objects
 Args    : a feature method (optional)
 Status  : Public

This method returns a list of any subfeatures that belong to the main
feature.  For those features that contain heterogeneous subfeatures,
you can retrieve a subset of the subfeatures by providing a method
name to filter on.

=cut

sub get_SeqFeatures {
  my $self = shift;
  my $type = shift;
  my $subfeat = $self->{subfeatures} or return;
  $self->sort_features;
  my @a;
  if ($type) {
    my $features = $subfeat->{lc $type} or return;
    @a = @{$features};
  } else {
    @a = map {@{$_}} values %{$subfeat};
  }
  return @a;
}

=head2 add_subfeature

 Title   : add_subfeature
 Usage   : $feature->add_subfeature($feature)
 Function: add a subfeature to the feature
 Returns : nothing
 Args    : a Bio::DB::GFF::Feature object
 Status  : Public

This method adds a new subfeature to the object.  It is used
internally by aggregators, but is available for public use as well.

=cut

sub add_subfeature {
  my $self    = shift;
  my $feature = shift;
  my $type = $feature->method;
  my $subfeat = $self->{subfeatures}{lc $type} ||= [];
  push @{$subfeat},$feature;
}

=head2 adjust_bounds

 Title   : adjust_bounds
 Usage   : $feature->adjust_bounds
 Function: adjust the bounds of a feature
 Returns : ($start,$stop,$strand)
 Args    : none
 Status  : Public

This method adjusts the boundaries of the feature to enclose all its
subfeatures.  It returns the new start, stop and strand of the
enclosing feature.

=cut

# adjust a feature so that its boundaries are synched with its subparts' boundaries.
# this works recursively, so subfeatures can contain other features
sub adjust_bounds {
  my $self = shift;
  my $t = $self->{target};

  if (my $subfeat = $self->{subfeatures}) {
    for my $list (values %$subfeat) {
      for my $feat (@$list) {

	# fix up our bounds to hold largest subfeature
	my($start,$stop,$strand) = $feat->adjust_bounds;
	$self->{fstrand} = $strand unless defined $self->{fstrand};
	if ($start <= $stop) {
	  $self->{start} = $start if !defined($self->{start}) || $start < $self->{start};
	  $self->{stop}  = $stop  if !defined($self->{stop})  || $stop  > $self->{stop};
	} else {
	  $self->{start} = $start if !defined($self->{start}) || $start > $self->{start};
	  $self->{stop}  = $stop  if !defined($self->{stop})  || $stop  < $self->{stop};
	}

	# fix up endpoints of targets too
	my $st = $feat->{target};
	next unless $t && $st;
	($start,$stop) = (@{$st}[1,2]);
	if ($start < $stop) {
	  $t->[1] = $start if !defined($t->[1]) || $start < $t->[1];  # start
	  $t->[2] = $stop  if !defined($t->[2]) || $stop  > $t->[2];  # stop
	} else {
	  $t->[1] = $start if !defined($t->[1]) || $start > $t->[1];  # start
	  $t->[2] = $stop  if !defined($t->[2]) || $stop  < $t->[2];
	}
      }
    }
  }

  ($self->{start},$self->{stop},$self->strand);
}

=head2 sort_features

 Title   : sort_features
 Usage   : $feature->sort_features
 Function: sort features
 Returns : nothing
 Args    : none
 Status  : Public

This method sorts subfeatures in ascending order by their start
position.  For reverse strand features, it sorts subfeatures in
descending order.  After this is called sub_SeqFeature will return the
features in order.

This method is called internally by merged_segments().

=cut

# sort features
sub sort_features {
  my $self = shift;
  return if $self->{sorted}++;
  my $strand = $self->strand or return;
  my $subfeat = $self->{subfeatures} or return;
  for my $type (keys %$subfeat) {
      $subfeat->{$type} = [map { $_->[0] }
			   sort {$a->[1] <=> $b->[1] }
			   map { [$_,$_->start] }
			   @{$subfeat->{$type}}] if $strand > 0;
      $subfeat->{$type} = [map { $_->[0] }
			   sort {$b->[1] <=> $a->[1]}
			   map { [$_,$_->start] }
			   @{$subfeat->{$type}}] if $strand < 0;
  }
}

=head2 compound

 Title   : compound
 Usage   : $flag = $f->compound([$newflag])
 Function: get or set the compound flag
 Returns : a boolean
 Args    : a new flag (optional)
 Status  : Public

This method gets or sets a flag indicated that the feature is not a
primary one from the DAS server, but the result of aggregation.

=cut

sub compound  {
  my $self = shift;
  my $d    = $self->{compound};
  $self->{compound} = shift if @_;
  $d;
}

sub primary_tag { shift->type   }
sub class       { shift->method }
sub source_tag  { shift->method }
sub source      {
  my $type = shift->type;
  my ($method,$source) = split ':',$type;
  return $source;
}
sub has_tag     { undef         }
sub all_tags    {
  my $self = shift;
  return ($self->primary_tag,$self->source_tag);
}
sub gff_string {
  my $self = shift;
  return join "\t",(
		    $self->refseq,
		    $self->method,
		    $self->type,
		    $self->start,
		    $self->end,
		    $self->score,
		    $self->{orientation},
		    $self->phase,
		    "group " . $self->group ." ; link " . $self->link
		    );
}

sub _cmp {
  my $self = shift;
  my ($b,$reversed) = @_;
  my $a = $self->toString;
  ($a,$b) = ($b,$a) if $reversed;
  $a cmp $b;
}

1;

__END__

=head1 NAME

Bio::Das::Segment::Feature - A genomic annotation

=head1 SYNOPSIS

  use Bio::Das;

  # contact a DAS server using the "elegans" data source
  my $das      = Bio::Das->new('http://www.wormbase.org/db/das' => 'elegans');

  # fetch a segment
  my $segment  = $das->segment(-ref=>'CHROMOSOME_I',-start=>10_000,-stop=>20_000);

  # get features from segment
  for my $feature ($segment->features) {
     my $id     = $feature->id;
     my $label  = $feature->label;
     my $type   = $feature->type;
     my $category  = $feature->category;
     my $refseq = $feature->refseq;
     my $reference = $feature->reference;
     my $start  = $feature->start;
     my $stop   = $feature->stop;
     my $score  = $feature->score;
     my $orientation = $feature->orientation;
     my $phase  = $feature->phase;
     my $link   = $feature->link;
     my $group  = $feature->group;
     my @subs   = $feature->sub_seqFeature;
  }

=head1 DESCRIPTION

A Bio::Das::Segment::Feature object contains information about a
feature on the genome retrieve from a DAS server.  Each feature --
also known as an "annotation" -- has a start and end position on the
genome relative to a reference sequence, as well as a human-readable
label, a feature type, a category, and other information.  Some
features may have subfeatures.  The attributes of a feature are
described at http://biodas.org.

=head2 OBJECT CREATION

Bio::Das::Segment::Feature objects are created by calling the
features() method of a Bio::Das::Segment object created earlier.  See
L<Bio::Das::Segment> for details.

=head2  OBJECT METHODS

The following methods provide access to the attributes of a feature.
Most are implemented as read/write accessors: calling them without an
argument returns the current value of the attribute.  Calling the
methods with an argument sets the attribute and returns its previous
value.

=over 4

=item $id = $feature->id([$newid])

Get or set the feature ID.  This is an identifier for the feature,
unique across the DAS server from which it was retrieved.

=item $label = $feature->label([$newlabel])

Get or set the label for the feature.  This is an optional
human-readable label that may be used to display the feature in text
form.  You may use the ID if label() returns undef.

=item $type = $feature->type([$newtype])

Get or set the type of the feature. This is a required attribute.  The
value returned is an object of type Bio::Das::Type, which contains
information about the type of the annotation and the method used to
derive it.

=item $segment = $feature->([$newsegment])

Get or set the Bio::Das::Segment from which this feature was derived.

=item $source  = $feature->source

Get the Bio::Das object from which this feature was retrieved.  This
method is a front end to the associated segment's source() method, and
is therefore read-only.

=item $refseq   = $feature->refseq

Get the reference sequence on which this feature's coordinates are
based.  This method is a front end to the associated segment's
refseq() method, and is therefore read-only.

=item $start = $feature->start([$newstart])

Get or set the starting position of the feature, in refseq
coordinates.

=item $stop = $feature->stop([$newstop])

Get or set the stopping position of the feature, in refseq
coordinates.

=item $isreference = $feature->stop([$newreference])

Get or set the value of the "reference" flag, which is true if the
feature can be used as a sequence coordinate landmark.

=item $method = $feature->method

Return the ID of the method used to derive this feature.  This is a
front end to the feature type's method() method (redundancy intended)
and is therefore read-only.

=item $category = $feature->category

Return the ID of the category in which this feature calls.  This is a
front end to the feature type's category() method and is therefore
read-only.

=item $score = $feature->score([$newscore])

Get or set the score of this feature, a floating point number which
might mean something in the right context.

=item $orientation = $feature->orientation([$neworientation])

Get or set the orientation of this feature relative to the genomic
reference sequence.  This is one of the values +1, 0 or -1.

=item $phase = $feature->phase([$newphase])

Get or set the phase of the feature (its position relative to a
reading frame).  The returned value can be 0, 1, 2 or undef if the
phase is irrelevant to this feature type.

=item $group = $feature->group([$newgroup])

Get or set the group ID for the feature.  Groups are used to group
together logically-related features, such as the exons of a gene
model.

=item $url = $feature->link([$newurl])

Get or set the URL that will return additional information about the
feature.

=item $label = $feature->link_label([$newlabel])

Get or set the label that the DAS server recommends should be used for
the link.

=item $note = $feature->note([$newnote])

Get or set the human-readable note associated with the feature.

=item $target = $feature->target

=item ($target,$start,$stop) = $feature->target

=item $feature->target($target,$start,$stop)

These three methods get or set the target that is optionally
associated with alignments.  In a scalar context, target() returns the
ID of the target, while in an array context, the method returns a
three-element list consisting of the target ID, and the start and end
position of the alignment.

You may pass a three-element list to change the target and range.

=item $target_label = $feature->target_label([$newlabel])

This method returns an optional label assigned to the target.

=item $description = $feature->description

This method returns a human-readable description of the feature.  It
returns the value of note(), link_label() or target_label(), in that
priority.

=item @segments = $feature->segments

=item @segments = $feature->sub_seqFeature

These methods are aliases.  Both return an array of sub-parts of the
feature in the form of Das::Sequence::Feature objects.  Currently
(March 2001) this is only implemented for grouped objects of type
"similarity" and for transcripts (the union of introns and exons in a
group).

=head2 Bio::SeqFeatureI METHODS

In addition to the methods listed above, Bio::Das::Segment::Feature
implements all the methods required for the Bio::SeqFeatureI class.

=head2 STRING OVERLOADING

When used in a string context, Bio::Das::Segment::Feature objects
invoke the toString() method.  This returns the value of the feature's
label, or invokes the inherited Bio::Das::Segment->toString() method
if no label is available.

=head1 AUTHOR

Lincoln Stein <lstein@cshl.org>.

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=head1 SEE ALSO

L<Bio::Das>, L<Bio::Das::Type>, L<Bio::Das::Segment>,
L<Bio::Das::Transcript>, L<Bio::Das::Segment::GappedAlignment>,
L<Bio::RangeI>

=cut
