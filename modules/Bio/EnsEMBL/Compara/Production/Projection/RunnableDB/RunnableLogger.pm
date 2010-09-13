#
# You may distribute this module under the same terms as perl itself
#

=pod

=head1 NAME

Bio::EnsEMBL::Compara::Production::Projection::RunnableDB::RunnableLogger

=head1 DESCRIPTION

This class is a mirror of the calls we can expect to use on a L<Log::Log4perl>
logger class. This allows runnables to use Log4perl should it exist on 
a user's @INC otherwise it defaults to the more normal logging to stdout. It
does not provide catagory support just the basic logging interface.

=head1 AUTHOR

Andy Yates (ayatesatebiacuk)

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the dev mailing list: dev@ensembl.org

=cut

package Bio::EnsEMBL::Compara::Production::Projection::RunnableDB::RunnableLogger;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception ();

=head2 new()

  Arg[DEBUG]  : Indicates if debug mode is on.
  Description : Constructor for the logger

=cut

sub new {
  my ( $class, @args ) = @_;
  my $self = bless( {}, ref($class) || $class );
  my ( $debug ) = rearrange( [qw(debug)], @args );
  $self->_debug($debug);
  return $self;
}

sub _debug {
  my ($self, $_debug) = @_;
  $self->{_debug} = $_debug if defined $_debug;
  return $self->{_debug};
}

=head2 fatal()

Issues an Ensembl warning with the message

=cut

sub fatal {
  my ($self, $message) = @_;
  Bio::EnsEMBL::Utils::Exception::warning($message);
  return; 
}

=head2 is_fatal()

Always returns true

=cut

sub is_fatal {
  return 1;
}

=head2 error()

Issues an Ensembl warning with the message

=cut

sub error {
  my ($self, $message) = @_;
  Bio::EnsEMBL::Utils::Exception::warning($message);
  return;
}

=head2 is_error()

Always returns true

=cut

sub is_error {
  return 1;
}

=head2 warning()

Issues an Ensembl warning with the message

=cut

sub warning {
  my ($self, $message) = @_;
  Bio::EnsEMBL::Utils::Exception::warning($message);
  return;
}

=head2 is_warning()

Always returns true

=cut

sub is_warning {
  return 1;
}

=head2 info()

Prints the message to STDOUT

=cut

sub info {
  my ($self, $message) = @_;
  print $message;
  return;
}

=head2 is_info()

Always returns true

=cut

sub is_info {
  my ($self) = @_;
  return 1;
}

=head2 debug()

Prints to STDOUT if the object was contstructed with the debug flag on

=cut

sub debug {
  my ($self, $message) = @_;
  return unless $self->is_debug();
  print $message;
  return;
}

=head2 is_debug()

Returns true if debug was given as true during construction

=cut

sub is_debug {
  my ($self) = @_;
  return $self->_debug();
}

=head2 trace()

Prints the message to STDOUT if is_trace() responded true

=cut

sub trace {
  my ($self, $message) = @_;
  return unless $self->is_trace();
  print $message;
  return;
}

=head2 is_trace()

Returns true if debug was given as true during construction

=cut

sub is_trace {
  my ($self) = @_;
  return $self->_debug();
}

1;