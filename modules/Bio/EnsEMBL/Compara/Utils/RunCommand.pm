=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::Utils::RunCommand

=head1 DESCRIPTION

This module is a wrapper around open3() that captures the standard output,
the standard error, the error code, and the running time.
It is used to run external commands in the Compara pipelines.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Utils::RunCommand;

use strict;
use warnings;

use IO::File;
use Symbol qw/gensym/;
use IPC::Open3;
use Data::Dumper;
use Time::HiRes qw(time);


sub new_and_exec {
    my ($class, $cmd, $options) = @_;

    my $debug   = $options->{debug};
    my $timeout = $options->{timeout};

    my $flat_cmd = ref($cmd) ? join_command_args(@$cmd) : $cmd;
    die "'use_bash_pipefail' with array-ref commands are not supported !" if $options->{'use_bash_pipefail'} && ref($cmd);
    my $use_bash_errexit = $options->{'use_bash_errexit'} // ($flat_cmd =~ /;/);
    my $cmd_to_run = ref($cmd) ? $cmd : [$cmd];
    if ($options->{'use_bash_pipefail'} or $use_bash_errexit) {
        $cmd_to_run = ['bash' => ('-o' => 'errexit', $options->{'use_bash_pipefail'} ? ('-o' => 'pipefail') : (), '-c' => $flat_cmd)];
    }

    my $runCmd = {
        _cmd        => $cmd_to_run,
        _purpose    => $options->{description} ? $options->{description} . " ($flat_cmd)" : "run '$flat_cmd'",
    };
    $runCmd->{_pipe_stdin}  = $options->{pipe_stdin}  if $options->{pipe_stdin};
    $runCmd->{_pipe_stdout} = $options->{pipe_stdout} if $options->{pipe_stdout};
    bless $runCmd, ref($class) || $class;

    print STDERR "COMMAND: $flat_cmd\n" if ($debug);
    print STDERR "TIMEOUT: $timeout\n" if ($timeout and $debug);
    $runCmd->run($timeout);
    print STDERR $runCmd->exit_code ? 'FAILURE' : 'SUCCESS', " !\n" if ($debug);
    print STDERR "STANDARD OUTPUT: ", $runCmd->out, "\n" if ($debug);
    print STDERR "STANDARD ERROR : ", $runCmd->err, "\n\n" if ($debug);

    if (($runCmd->exit_code >= 256) or (($options->{'use_bash_pipefail'} or $use_bash_errexit) and ($runCmd->exit_code >= 128))) {
        # The process was killed. Perhaps a MEMLIMIT ? Wait a little bit to
        # allow the job scheduler to kill this process too
        sleep(30);
    }
    $runCmd->die_with_log if $runCmd->exit_code && $options->{die_on_failure};
    return $runCmd;
}


my %shell_characters = map {$_ => 1} qw(< > |);
sub join_command_args {

    my @new_args = ();
    foreach my $a (@_) {
        if ($shell_characters{$a} or $a =~ /^[a-zA-Z0-9_\/\-]+\z/) {
            push @new_args, $a;
        } else {
            # Escapes the single-quotes and protects the arguments
            $a =~ s/'/'\\''/g;
            push @new_args, "'$a'";
        }
    }

    return join(' ', @new_args);
}


sub cmd {
    my ($self) = @_;
    return $self->{_cmd};
}

sub out {
    my ($self) = @_;
    return $self->{_out};
}

sub err {
    my ($self) = @_;
    return $self->{_err};
}

sub runtime_msec {
    my ($self) = @_;
    return $self->{_runtime_msec};
}

sub exit_code {
    my ($self) = @_;
    return $self->{_exit_code};
}


=head2 die_with_log

  Example     : $run_command->die_with_log();
  Description : Standard method to "die" with a message made of properties of this job. This ensures
                consistency across runnables and pipelines
  Returntype  : None

=cut

sub die_with_log {
    my ($self) = @_;
    die sprintf("Could not %s, got %s\nSTDOUT %s\nSTDERR %s\n", $self->{_purpose}, $self->exit_code, $self->out, $self->err);
}


=head2 _run_with_stdin_pipe

  Description : Run the command with open3, by connecting the "pipe_stdin"
                function to the file handle of the child's standard input.
  Returntype  : Integer (exit code)

=cut

sub _run_with_stdin_pipe {
    my ($self) = @_;
    local *CATCHOUT = IO::File->new_tmpfile;
    local *CATCHERR = IO::File->new_tmpfile;
    my $pid = open3(\*CATCHIN, ">&CATCHOUT", ">&CATCHERR", @{$self->cmd});
    $self->{_pipe_stdin}->(\*CATCHIN);
    waitpid($pid,0);
    my $rc = $?;
    $self->{_out} = $self->_read_output(\*CATCHOUT);
    $self->{_err} = $self->_read_output(\*CATCHERR);
    return $rc;
}


=head2 _run_no_stdin

  Description : Run the command with open3, by closing the child's standard
                input. The standard output can be connected to the "pipe_stdout"
                function or will be accumulated into a string (like the standard
                error).
  Returntype  : Integer (exit code)

=cut

sub _run_no_stdin {
    my ($self) = @_;
    local *CATCHERR = IO::File->new_tmpfile;
    my $pid = open3(gensym, \*CATCHOUT, ">&CATCHERR", @{$self->cmd});
    if ($self->{_pipe_stdout}) {
        $self->{_pipe_stdout}->(\*CATCHOUT);
        $self->{_out} = '<sent to '.$self->{_pipe_stdout}.'>';
    } else {
        $self->{_out} = $self->_read_output(\*CATCHOUT);
    }
    waitpid($pid,0);
    my $rc = $?;
    $self->{_err} = $self->_read_output(\*CATCHERR);
    return $rc;
}


=head2 _run_wrapper

  Example     : $d->_run_wrapper();
  Description : Wrapper around _run_with_stdin_pipe and _run_no_stdin that
                also measures the runtime (in milliseconds) and processes
                the return code.
  Returntype  : None

=cut

sub _run_wrapper {
    my ($self) = @_;

    my $starttime = time() * 1000;
    my $rc = $self->{_pipe_stdin} ? $self->_run_with_stdin_pipe : $self->_run_no_stdin;
    $self->{_exit_code} = $rc >> 8;
    if ($rc && !$self->{_exit_code}) {
        $self->{_exit_code} = 256 + $rc;
    }
    $self->{_runtime_msec} = int(time()*1000-$starttime);
}


=head2 run

  Description : High-level function to run the command
  Returntype  : None

=cut

sub run {
    my ($self, $timeout) = @_;
    if (defined $timeout) {
        $self->_run_with_timeout($timeout);
    } else {
        $self->_run_wrapper;
    }
}


=head2 _run_with_timeout

  Description : Runs the command with a maximum allowed runtime
  Returntype  : None

=cut

sub _run_with_timeout {
    my $self = shift;
    my $timeout = shift;

    ## Adapted from the TimeLimit pacakge: http://www.perlmonks.org/?node_id=74429
    my $die_text = "_____RunCommandTimeLimit_____\n";
    my $old_alarm = alarm(0);        # turn alarm off and read old value
    {
        local $SIG{ALRM} = 'IGNORE'; # ignore alarms in this scope

        eval
        {
            local $SIG{__DIE__};     # turn die handler off in eval block
            local $SIG{ALRM} = sub { die $die_text };
            alarm($timeout);         # set alarm
            $self->_run_wrapper();
        };

        # Note the alarm is still active here - however we assume that
        # if we got here without an alarm the user's code succeeded -
        # hence the IGNOREing of alarms in this scope

        alarm 0;                     # kill off alarm
    }

    alarm $old_alarm;                # restore alarm

    if ($@) {
        # the eval returned an error
        die $@ if $@ ne $die_text;
        $self->{_exit_code} = -2;
        $self->{_err} = "Command's runtime has exceeded the limit of $timeout seconds";
    }
}


=head2 _read_output

  Argument[1] : $fh file handle
  Description : Read the entire content of the file, by first rewinding back to its beginning
  Returntype  : String

=cut

sub _read_output {
    my ($self, $fh) = @_;
    seek($fh, 0, 0);
    my $msg = "";
    while(<$fh>) {
        $msg .= $_;
    }
    close($fh);
    return $msg;
}

1;
