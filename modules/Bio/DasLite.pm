#########
# Author: rmp
# Last Modified: $Date $
# Id:            $Id$
# $HeadURL$
#
# Note: This namespace is now deprecated. Please use Bio::Das::Lite instead.
#
package Bio::DasLite;
use strict;
use warnings;
use base qw(Bio::Das::Lite);

our $VERSION  = do { my @r = (q$Revision$ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };
*Bio::DasLite::DEBUG = *Bio::Das::Lite::DEBUG;

1;

__END__
=head1 NAME

Bio::DasLite - a compatibility wrapper around Bio::Das::Lite

=head1 VERSION

$Revision$

=head1 DESCRIPTION

  The Bio::DasLite namespace is deprecated. Bio::DasLite is a wrapper for Bio::Das::Lite

=head1 SYNOPSIS

See Bio::Das::Lite

=head1 SUBROUTINES/METHODS

See Bio::Das::Lite

=head1 DIAGNOSTICS

See Bio::Das::Lite

=head1 CONFIGURATION AND ENVIRONMENT

See Bio::Das::Lite

=head1 DEPENDENCIES

See Bio::Das::Lite

=head1 INCOMPATIBILITIES

See Bio::Das::Lite

=head1 BUGS AND LIMITATIONS

See Bio::Das::Lite

=head1 AUTHOR

See Bio::Das::Lite

=head1 LICENSE AND COPYRIGHT

See Bio::Das::Lite

=cut
