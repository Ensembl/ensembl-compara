#########
# Author:        rpettett@cpan.org
# Maintainer:    rpettett@cpan.org
# Created:       2005-08-23
# Last Modified: $Date$ $Author$
# Source:        $Source $
# Id:            $Id $
# $HeadURL $
#
package Bio::Das::Lite::UserAgent;
use strict;
use warnings;
use base qw(LWP::Parallel::UserAgent);

our $VERSION  = do { my @r = (q$Revision$ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

our %STATUS_TEXT = (
                    200 => '200 OK',
                    400 => '400 Bad command (command not recognized)',
                    401 => '401 Bad data source (data source unknown)',
                    402 => '402 Bad command arguments (arguments invalid)',
                    403 => '403 Bad reference object',
                    404 => '404 Requested object unknown',
                    405 => '405 Coordinate error',
                    500 => '500 Server error',
                    501 => '501 Unimplemented feature',
                   );

sub new {
  my ($class, %args) = @_;
  my $self = LWP::Parallel::UserAgent->new(%args);
  bless $self, $class;
  return $self;
}

sub on_failure {
  my ($self, $request, $response, $entry)   = @_;
  $self->{'statuscodes'}                  ||= {};
  if (my $das_status = $response->header('X-DAS-Status')) {
    $self->{'statuscodes'}->{$request->url()} = $STATUS_TEXT{ $das_status } || $das_status;
  } else {
    $self->{'statuscodes'}->{$request->url()} = $response->status_line();
  }
  return;
}

sub on_return {
  my @args = @_;
  return on_failure(@args);
}

sub statuscodes {
  my ($self, $url)         = @_;
  $self->{'statuscodes'} ||= {};
  return $url?$self->{'statuscodes'}->{$url}:$self->{'statuscodes'};
}

1;

__END__

=head1 NAME

Bio::Das::Lite::UserAgent - A derivative of LWP::Parallel::UserAgent for Bio::Das::Lite use

=head1 VERSION

$Revision$

=head1 SYNOPSIS

=head1 DESCRIPTION

A subclass of LWP::Parallel::UserAgent supporting forward proxies

=head1 SUBROUTINES/METHODS

=head2 new : Constructor

Call with whatever LWP::P::UA usually has

=head2 on_failure : internal error propagation method

=head2 on_return : internal error propagation method

=head2 statuscodes : helper for tracking response statuses keyed on url

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

LWP::Parallel::UserAgent

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rpettett@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007 GRL, by Roger Pettett

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
