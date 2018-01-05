=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


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

Questions can be posted to the dev mailing list: http://lists.ensembl.org/mailman/listinfo/dev

=cut

package Bio::EnsEMBL::Compara::Production::Projection::RunnableDB::RunnableLogger;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

=head2 new()

  Arg[DEBUG]  : Indicates if debug mode is on.
  Arg[STDERR] : Indicates we need to write out to STDERR
  Arg[TRACE]  : Indicates if trace mode is on (defaults to 0)
  Description : Constructor for the logger

=cut

sub new {
  my ( $class, @args ) = @_;
  my $self = bless( {}, ref($class) || $class );
  my ( $debug, $stderr, $trace ) = rearrange( [qw(debug stderr trace)], @args );
  $self->_debug($debug);
  $self->_stderr($stderr);
  $self->_trace($trace);
  return $self;
}

sub _debug {
  my ($self, $_debug) = @_;
  $self->{_debug} = $_debug if defined $_debug;
  return $self->{_debug};
}

sub _stderr {
  my ($self, $_stderr) = @_;
  $self->{_stderr} = $_stderr if defined $_stderr;
  return $self->{_stderr};
}

sub _trace {
  my ($self, $_trace) = @_;
  $self->{_trace} = $_trace if defined $_trace;
  return $self->{_trace};
}

=head2 fatal()

Issues an Ensembl warning with the message

=cut

sub fatal {
  my ($self, $message) = @_;
  $self->_print("FATAL: $message");
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
  $self->_print("ERROR: $message");
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
  $self->_print("WARN: $message");
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
  $self->_print("INFO: $message");
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
  $self->_print("DEBUG: $message");
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
  $self->_print("TRACE: $message");
  return;
}

=head2 is_trace()

Returns true if debug was given as true during construction

=cut

sub is_trace {
  my ($self) = @_;
  return $self->_trace();
}

sub _print {
  my ($self, $msg) = @_;
  if($self->_stderr()) {
    print STDERR $msg, "\n";
  }
  else {
    print STDOUT $msg, "\n";
  }
  return;
}

1;