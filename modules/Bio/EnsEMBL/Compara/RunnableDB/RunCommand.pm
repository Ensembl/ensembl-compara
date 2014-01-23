=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::RunCommand

=head1 SYNOPSIS


=head1 DESCRIPTION

This module acts as a layer between the Hive system and running external tools.

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::RunCommand;
use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub run_command {
    my ($self, $cmd) = @_;

    print STDERR "COMMAND: $cmd\n" if ($self->debug);
    my $runCmd = Command->new($cmd);
    $self->compara_dba->dbc->disconnect_when_inactive(1);
    $runCmd->run();
    $self->compara_dba->dbc->disconnect_when_inactive(0);
    print STDERR "OUTPUT: ", $runCmd->out, "\n" if ($self->debug);
    print STDERR "ERROR : ", $runCmd->err, "\n\n" if ($self->debug);
    return $runCmd;
}


package Command;

use strict;
use warnings;
use IO::File;
use Symbol qw/gensym/;
use IPC::Open3;
use Data::Dumper;
use Time::HiRes qw(time gettimeofday tv_interval);


sub new {
    my ($class, $cmd) = @_;
    my $self = {};
    bless $self, ref($class) || $class;
    $self->{_cmd} = $cmd;
    return $self;
}

sub cmd {
    my ($self, $cmd) = @_;
    if (defined $cmd) {
        return $self->new($cmd);
    }
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

sub run {
    my ($self) = @_;
    my $cmd = $self->cmd;

    my $starttime = time() * 1000;
    local *CATCHERR = IO::File->new_tmpfile;
    my $pid = open3(gensym, \*CATCHOUT, ">&CATCHERR", $cmd);
    $self->{_out} = $self->_read_output(\*CATCHOUT);
    waitpid($pid,0);
    $self->{_exit_code} = $?>>8;
    $self->{_err} = $self->_read_output(\*CATCHERR);
    $self->{_runtime_msec} = int(time()*1000-$starttime);
    return;
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
