package Bio::Das::Request::Entry_points;
# $Id$
# this module issues and parses the entry_points command, with the ref argument

=head1 NAME

Bio::Das::Request::Entry_points - The DAS "entry_points" request

=head1 SYNOPSIS

 my @entry_points         = $request->results;
 my $das_command          = $request->command;
 my $successful           = $request->is_success;
 my $error_msg            = $request->error;
 my ($username,$password) = $request->auth;

=head1 DESCRIPTION

This is a subclass of L<Bio::Das::Request> specialized for the
"entrypoints" command.  It is used to retrieve the entry points
(landmarks) known to a set of DAS servers.

All methods are as described in L<Bio::Das::Request>.

=cut

use strict;
use Bio::Das::DSN;
use Bio::Das::Request;
use Bio::Das::Util 'rearrange';

use vars '@ISA';
@ISA = 'Bio::Das::Request';

sub new {
  my $pack = shift;
  my ($dsn,$ref,$callback) = rearrange(['dsn',
					'ref',
					'callback',
				       ],@_);

  return $pack->SUPER::new(-dsn=>$dsn,
			   -callback=>$callback,
			   -args   => {ref => $ref}
			  );
}

sub command { 'entry_points' }

# top-level tag
sub t_DASEP {
  my $self  = shift;
  my $attrs = shift;
  if ($attrs) {  # section is starting
    $self->clear_results;
  }
  $self->{current_ep} = undef;
}

sub t_ENTRY_POINTS {
# nothing to do there
}

# segment is beginning
sub t_SEGMENT {
  my $self  = shift;
  my $attrs = shift;
  if ($attrs) {    # segment section is starting
    $self->{current_ep} = Bio::Das::Segment->new($attrs->{id},
						 $attrs->{start}||1,
						 $attrs->{stop}||$attrs->{size},
						 $attrs->{version}||'1.0');
    $self->{current_ep}->size($attrs->{size});
    $self->{current_ep}->class($attrs->{class});
    $self->{current_ep}->orientation($attrs->{orientation});
    $self->{current_ep}->subparts(1) if defined $attrs->{subparts} 
      && $attrs->{subparts} eq 'yes';
  }
  else {  # reached the end of the segment, so push result
    $self->add_object($self->{current_ep});
  }
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

