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
use Time::HiRes qw(time gettimeofday tv_interval);


sub new_and_exec {
    my ($class, $cmd, $options) = @_;

    my $debug   = $options->{debug};
    my $timeout = $options->{timeout};

    my $flat_cmd = ref($cmd) ? join_command_args(@$cmd) : $cmd;
    die "'use_bash_pipefail' with array-ref commands are not supported !" if $options->{'use_bash_pipefail'} && ref($cmd);
    my $use_bash_errexit = $options->{'use_bash_errexit'} // ($flat_cmd =~ /;/);
    my $cmd_to_run = $cmd;
    if ($options->{'use_bash_pipefail'} or $use_bash_errexit) {
        $cmd_to_run = ['bash' => ('-o' => 'errexit', $options->{'use_bash_pipefail'} ? ('-o' => 'pipefail') : (), '-c' => $flat_cmd)];
    }

    print STDERR "COMMAND: $flat_cmd\n" if ($debug);
    print STDERR "TIMEOUT: $timeout\n" if ($timeout and $debug);
    my $runCmd = $class->new($cmd_to_run, $timeout);
    $runCmd->run();
    print STDERR "OUTPUT: ", $runCmd->out, "\n" if ($debug);
    print STDERR "ERROR : ", $runCmd->err, "\n\n" if ($debug);
    my $purpose = $options->{description} ? $options->{description} . " ($flat_cmd)" : "run '$flat_cmd'";
    die sprintf("Could not %s, got %s\nSTDOUT %s\nSTDERR %s\n", $purpose, $runCmd->exit_code, $runCmd->out, $runCmd->err) if $runCmd->exit_code && $options->{die_on_failure};
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


sub new {
    my ($class, $cmd, $timeout) = @_;
    my $self = {};
    bless $self, ref($class) || $class;
    $self->{_cmd} = $cmd;
    $self->{_timeout} = $timeout;
    return $self;
}

sub cmd {
    my ($self) = @_;
    return $self->{_cmd};
}

sub timeout {
    my ($self) = @_;
    return $self->{_timeout};
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

sub _run {
    my ($self) = @_;
    my $cmd = $self->cmd;

    my $starttime = time() * 1000;
    local *CATCHERR = IO::File->new_tmpfile;
    my $pid = open3(gensym, \*CATCHOUT, ">&CATCHERR", ref($cmd) ? @$cmd : $cmd);
    $self->{_out} = $self->_read_output(\*CATCHOUT);
    waitpid($pid,0);
    $self->{_exit_code} = $?>>8;
    if ($? && !$self->{_exit_code}) {
        $self->{_exit_code} = 256 + $?;
    }
    $self->{_err} = $self->_read_output(\*CATCHERR);
    $self->{_runtime_msec} = int(time()*1000-$starttime);
    return;
}

sub run {
    my ($self) = @_;
    my $timeout = $self->timeout;
    if (not $timeout) {
        $self->_run();
        return;
    }

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
            $self->_run();
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
        $self->{_err} = sprintf("Command's runtime has exceeded the limit of %s seconds", $timeout);
    }
}

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
