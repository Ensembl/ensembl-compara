package Bio::Das::Request::Dnas;
# $Id$
# this module issues and parses the types command, with arguments -dsn, -segment, -categories, -enumerate

=head1 NAME

Bio::Das::Request::Dnas - The DAS "dna" request

=head1 SYNOPSIS

 my @dnas                 = $request->results;
 my $dnas                 = $request->results;

 my $dsn                  = $request->dsn;
 my $das_command          = $request->command;
 my $successful           = $request->is_success;
 my $error_msg            = $request->error;
 my ($username,$password) = $request->auth;

=head1 DESCRIPTION

This is a subclass of L<Bio::Das::Request> specialized for the "dna"
command.  It is used to retrieve the DNA corresponding to a set of
segments on a set of DAS servers.

=head2 METHODS

All methods are the same as L<Bio::Das::Request> with the exception of
results(), which has been overridden to produce specialized behavior.

=over 4

=cut

use strict;
use Bio::Das::Segment;
use Bio::Das::Request;
use Bio::Das::Util 'rearrange';

use vars '@ISA';
@ISA = 'Bio::Das::Request';

sub new {
  my $pack = shift;
  my ($dsn,$segments,$callback) = rearrange([['dsn','dsns'],
					     ['segment','segments'],
					     'callback'
					    ],@_);

  my $self = $pack->SUPER::new(-dsn => $dsn,
			       -callback => $callback,
			       -args => {
					 segment   => $segments,
					} );

  $self;
}

sub command { 'dna' }

sub t_DASDNA {
  my $self = shift;
  my $attrs = shift;
  if ($attrs) {
    $self->clear_results;
  }
  delete $self->{tmp};
}

sub t_SEQUENCE {
  my $self = shift;
  my $attrs = shift;
  if ($attrs) {    # segment section is starting
    $self->{tmp}{current_segment} = Bio::Das::Segment->new($attrs->{id},$attrs->{start},$attrs->{stop},$attrs->{version});
  }

  else {  # reached the end of the segment, so push result
    $self->{tmp}{current_dna} =~ s/\s//g;
    $self->add_object($self->{tmp}{current_segment},$self->{tmp}{current_dna});
  }

}

sub t_DNA {
  my $self = shift;
  my $attrs = shift;

  if ($attrs) {  # start of tag
    $self->{tmp}{current_dna}     = '';
  }

  else {
    my $dna = $self->char_data;
    $self->{tmp}{current_dna} .= $dna;
  }
}

=item $results = $request->results

In a scalar context, results() returns a hashref in which the keys are
segment strings (in the form "ref:start,end") and the values are the
DNAs corresponding to those segments.

=item @results = $request->results

In a list context, results() returns a list of the DNAs in the order
in which the segments were requested.

=cut

# override for "better" behavior
sub results {
  my $self = shift;
  my %r = $self->SUPER::results or return;

  # in array context, return the list of dnas
  return values %r if wantarray;

  # otherwise return ref to a hash in which the keys are segments and the values
  # are DNAs
  return \%r;
}

=head1 AUTHOR

Lincoln Stein <lstein@cshl.org>.

Copyright (c) 2001 Cold Spring Harbor Laboratory

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=head1 SEE ALSO

L<Bio::Das::Request>, L<Bio::Das::HTTP::Fetch>,
L<Bio::Das::Segment>, L<Bio::Das::Type>, L<Bio::Das::Stylesheet>,
L<Bio::Das::Source>, L<Bio::RangeI>

=cut

1;
