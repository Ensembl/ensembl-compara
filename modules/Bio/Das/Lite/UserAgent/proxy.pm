#########
# Author:        rmp@sanger.ac.uk
# Maintainer:    rmp@sanger.ac.uk
# Created:       2005-08-23
# Last Modified: $Date$ $Author$
# Source:        $Source $
# Id:            $Id $
# $HeadURL $
#
package Bio::Das::Lite::UserAgent::proxy;
use strict;
use warnings;

our $VERSION  = do { my @r = (q$Revision$ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

sub host     { my $self = shift; return $self->{'host'}; }
sub port     { my $self = shift; return $self->{'port'}; }
sub scheme   { my $self = shift; return $self->{'scheme'}; }

#########
# userinfo, presumably for authenticating to the proxy server.
# Not sure what format this is supposed to be (username:password@ ?)
# Things fail silently if this isn't present.
#
sub userinfo { return q(); }

1;
__END__

=head1 NAME

Bio::Das::Lite::UserAgent::proxy - A derivative of LWP::Parallel::UserAgent for Bio::Das::Lite use

=head1 VERSION

$Revision$

=head1 SYNOPSIS

=head1 DESCRIPTION

A support class for information about a forward proxy server

=head1 SUBROUTINES/METHODS

=head2 host : get/set host

=head2 port : get/set port

=head2 scheme : get/set scheme

=head2 userinfo : stub for authentication? Stops LWP::P::UA from silently failing

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

LWP::Parallel::UserAgent

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007 GRL, by Roger Pettett

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
