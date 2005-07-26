package Bio::Das::Request::Dsn;
# $Id$
# this module issues and parses the dsn command, with no arguments

=head1 NAME

Bio::Das::Request::Dsn - The DAS "dsn" request

=head1 SYNOPSIS

 my @dsn                  = $request->results;
 my $das_command          = $request->command;
 my $successful           = $request->is_success;
 my $error_msg            = $request->error;
 my ($username,$password) = $request->auth;

=head1 DESCRIPTION

This is a subclass of L<Bio::Das::Request> specialized for the "dsn"
command.  It is used to retrieve the data sources known to a set of
DAS servers.

The results() method returns a list of L<Bio::Das::DSN> objects.  All
other methods are as described in L<Bio::Das::Request>.

=cut

use strict;
use Bio::Das::DSN;
use Bio::Das::Request;
use Bio::Das::Util 'rearrange';

use vars '@ISA';
@ISA = 'Bio::Das::Request';

#sub new {
#  my $pack = shift;
#  my ($base,$callback) = rearrange(['dsn',
#				    'callback'
#				   ],@_);
#
#  return $pack->SUPER::new(-dsn=>$base,-callback=>$callback);
#}

sub command { 'dsn' }

# top-level tag
sub t_DASDSN {
  my $self  = shift;
  my $attrs = shift;
  if ($attrs) {  # section is starting
    $self->clear_results;
  }
  $self->{current_dsn} = undef;
}

# the beginning of a dsn
sub t_DSN {
  my $self = shift;
  my $attrs = shift;
  if ($attrs) {  # tag starts
    $self->{current_dsn} = Bio::Das::DSN->new($self->dsn->base);
  } else {
    $self->add_object($self->{current_dsn});
  }
}

sub t_SOURCE {
  my $self  = shift;
  my $attrs = shift;
  my $dsn = $self->{current_dsn} or return;
  if ($attrs) {
    $dsn->id($attrs->{id});
  } else {
    my $name = $self->trim($self->{char_data});
    $dsn->name($name);
  }
}

sub t_MAPMASTER {
  my $self  = shift;
  my $attrs = shift;
  my $dsn = $self->{current_dsn} or return;
  if ($attrs) {
    ; # do nothing here
  } else {
    my $name = $self->char_data;
    $dsn->master($name);
  }
}

sub t_DESCRIPTION {
  my $self  = shift;
  my $attrs = shift;
  my $dsn = $self->{current_dsn} or return;
  if ($attrs) {
    ; # do nothing here
  } else {
    my $name = $self->{char_data};
    $dsn->description($name);
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

