package EnsEMBL::Web::XS::Test;

use 5.014002;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use EnsEMBL::Web::XS::Test ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
  hello_planet	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('EnsEMBL::Web::XS::Test', $VERSION);

# Preloaded methods go here.

1;
__END__

=head1 NAME

EnsEMBL::Web::XS::Test - Example XS extension

=head1 SYNOPSIS

  use EnsEMBL::Web::XS::Test;
  hello_planet("World");
  hello_planet();

=head1 DESCRIPTION

This is a test XS library for use when debugging XS code and writing new
XS code. Its methods do nothing useful for EnsEMBL beyond assisting
writing other modules and must not be called in production code.

Note that while this is a separate library so that it is not included
in production systems, it is generally a good idea to bundle our own stuff
into a single library to ease deployment and reduce time coding wrappers.

=head2 EXPORT

None by default.

=head1 AUTHOR

EnsEMBL <helpdesk@ensembl.org>

=head1 COPYRIGHT AND LICENSE

Covered by main EnsEMBL licence.

=cut

