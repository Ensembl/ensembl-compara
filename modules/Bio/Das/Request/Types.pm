package Bio::Das::Request::Types;
# $Id$
# this module issues and parses the types command, with arguments -dsn, -segment, -categories, -enumerate

=head1 NAME

Bio::Das::Request::Types - The DAS "types" request

=head1 SYNOPSIS

 my @types                = $request->results;
 my $types                = $request->results;

 my $das_command          = $request->command;
 my $successful           = $request->is_success;
 my $error_msg            = $request->error;
 my ($username,$password) = $request->auth;

=head1 DESCRIPTION

This is a subclass of L<Bio::Das::Request> specialized for the "types"
command.  All methods are the same as L<Bio::Das::Request> with the
exception of results(), which has been modified to make it more useful.

=over 4

=item $types = $request->results

In a scalar context, results() returns a hashref in which the keys are
segment strings (in the form "ref:start,end") and the values are
arrayrefs of L<Bio::Das::Type> objects contained within those
segments.

=item @types = $request->results

In a list context, results() returns an array of L<Bio::Das::Type>
objects.

=back

=head1 AUTHOR

Lincoln Stein <lstein@cshl.org>.

Copyright (c) 2003 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=head1 SEE ALSO

L<Bio::Das::Request::Features>, L<Bio::Das::Request>,
L<Bio::Das::HTTP::Fetch>, L<Bio::Das::Segment>, L<Bio::Das::Type>,
L<Bio::Das::Stylesheet>, L<Bio::Das::Source>, L<Bio::RangeI>

=cut

use strict;
use Bio::Das::Type;
use Bio::Das::Segment;
use Bio::Das::Request;
use Bio::Das::Util 'rearrange';

use vars '@ISA';
@ISA = 'Bio::Das::Request';

sub new {
  my $pack = shift;
  my ($dsn,$segments,$categories,$enumerate,$callback) = rearrange([['dsn','dsns'],
								    ['segment','segments'],
								    ['category','categories'],
								    'enumerate',
								    'callback',
								   ],@_);
  my $self = $pack->SUPER::new(-dsn => $dsn,
			       -callback  => $callback,
			       -args => { segment   => $segments,
					  category  => $categories,
					  enumerate => $enumerate,
					} );
  $self;
}

sub command { 'types' }

sub t_DASTYPES {
  my $self = shift;
  my $attrs = shift;
  if ($attrs) {
    $self->clear_results;
  }
  delete $self->{tmp};
}

sub t_GFF {
  # nothing to do here
}

sub t_SEGMENT {
  my $self = shift;
  my $attrs = shift;
  if ($attrs) {    # segment section is starting
    $self->{tmp}{current_segment} = Bio::Das::Segment->new($attrs->{id},$attrs->{start},$attrs->{stop},$attrs->{version});
    $self->{tmp}{current_type}    = undef;
    $self->{tmp}{types}           = [];
  }

  else {  # reached the end of the segment, so push result
    $self->add_object($self->{tmp}{current_segment},$self->{tmp}{types});
  }

}

sub t_TYPE {
  my $self = shift;
  my $attrs = shift;

  if ($attrs) {  # start of tag
    my $type = $self->{tmp}{current_type} = Bio::Das::Type->new($attrs->{id},$attrs->{method},$attrs->{category});
    $type->source($attrs->{source}) if exists $attrs->{source};
  }

  else {
    my $count = $self->char_data;
    my $type = $self->{tmp}{current_type} or return;
    $type->count($count) if defined $count;
    push (@{$self->{tmp}{types}},$type);
  }
}

# override for "better" behavior
sub results {
  my $self = shift;
  my %r = $self->SUPER::results or return;

  # in array context, return the list of types
  return map { @{$_} } values %r if wantarray;

  # otherwise return ref to a hash
  return \%r;
}


1;
