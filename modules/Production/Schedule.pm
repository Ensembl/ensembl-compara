package Production::Schedule;

=pod

=head1 NAME

Production::Schedule - simple graph scheduler for background jobs

=head1 SYNOPSIS

  my $sch = Production::Schedule->new();
  $sch->die_on_error(); # non-zero exit from any process
  my $t1 = $sch->make_task("sleep 10; echo '1' >&2");
  my $t2 = $sch->make_task("sleep 5; echo '2'");
  my $t3 = $sch->make_task("sleep 5 ; echo '3'");
  $t2->wait_for($t1);
  # $sch->dry_run();
  $sch->go();
  print $t2->exit_code();

=head1 DESCRIPTION

Production::Schedule is designed to run jobs in the background asap,
but allowing for interdependencies. You create jobs and then set which
depend on which other jobs. Then after you call go, as many jobs will
be created as can be run and when they are finished their dependencies
are run. When nothing can run any more, go returns.

Process logging by default goes to the STDOUT/STDERR of the parent
process with a prefix indicating the originating job, but this can be
overridden by overriding the ->log() method of each task (eg to write to
a separate file).

This module is designed for a small number of large jobs with complex
interdepencies. In any other situation it will be horribly inefficient.
It should not be used for farm-like problems.

=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 AUTHOR

  Dan Sheppard (ds23@sanger.ac.uk)

=cut

use strict;
use warnings;

use sigtrap qw(die normal-signals);

my @ipc_run_h;

sub new {
  my ($proto,$support) = @_;
  my $class = ref($proto) || $proto;
  my $logger = sub { print "$_[0]\n"; };
  $logger = sub { $support->log("$_[0]\n"); } if($support);
  my $self = {
    tasks => {},
    finished => {},
    idx => 0,
    logger => $logger,
    pumping => {},
    die_on_error => 0,
    dry_run => 0,
  };
  bless $self,$class;
  return $self;
}

sub die_on_error { $_[0]->{'die_on_error'} = 1; }
sub dry_run { $_[0]->{'dry_run'} = 1; }

sub make_task {
  my ($self,$cmd) = @_;

  my $idx = $self->{'idx'}++;
  my $task = $self->{'tasks'}->{$idx} =
    Production::Schedule::Task->new($self,$cmd,$idx);
  $self->{'logger'}->("Task '$cmd' created. It has index $idx.");
  return $task;
}

sub _finished {
  my ($self,$i) = @_;

  my $t = $self->{'tasks'}{$i};
  $self->{'finished'}{$i} = 1;
  die "Task $i failed. Dying!" if $t->exit_code and $self->{'die_on_error'};
}

sub _pump_go {
  my ($self,$i) = @_;

  $self->{'pumping'}{$i} = 1;
}

sub _pump {
  my ($self) = @_;

  foreach my $i (keys %{$self->{'pumping'}}) {
    my $r = $self->{'tasks'}{$i}->_pump();
    delete $self->{'pumping'}{$i} unless $r;
  }
  foreach my $i (keys %{$self->{'tasks'}}) {
    my $t = $self->{'tasks'}{$i};
    next if $self->{'finished'}{$i} or $self->{'pumping'}{$i};
    unless(grep { !$self->{'finished'}{$_}  } $t->_deps()) {
      push @ipc_run_h,$t->_run();
    }
  }
  return !!(keys %{$self->{'pumping'}});
}

sub go {
  my ($self) = @_;

  while($self->_pump()) {
    sleep 1;
  }
}

package Production::Schedule::Task;

use IPC::Run qw(start pumpable finish);

sub new {
  my ($proto,$sch,$task,$idx) = @_;
  my $class = ref($proto) || $proto;
  my $self = {
    task => $task,
    idx => $idx,
    wait_for => [],
    sch => $sch,
  };
  bless $self,$class;
  return $self;
}

sub _deps { return @{$_[0]->{'wait_for'}}; }

sub wait_for {
  my ($self,$wait_for) = @_;

  push @{$self->{'wait_for'}},$wait_for->{'idx'};
  $self->{'sch'}{'logger'}->("Task $self->{'idx'} will wait for task $wait_for->{'idx'}");
}

# Feel free to override.
sub log {
  my ($self,$out,$err) = @_;

  my $str = $err?'STDERR':'STDOUT';
  $self->{'sch'}{'logger'}->("$self->{'idx'}($str):: $out");
}

sub _run {
  my ($self) = @_;

  $self->{'sch'}{'logger'}->("Starting task $self->{'idx'}.");
  my ($out);
  my $task = $self->{'task'};
  if($self->{'sch'}{'dry_run'}) {
    $task = "sleep 5";
  }

  $self->{'h'} = start(["bash","-c",$task],\undef,
                       sub { $self->log($_[0],0) },
                       sub { $self->log($_[0],1) });
  $self->{'sch'}->_pump_go($self->{'idx'});
  return $self->{'h'};
}

sub _pump {
  my ($self) = @_;

  unless(pumpable $self->{'h'}) {
    $self->{'sch'}{'logger'}->("Task $self->{'idx'} finished.");
    finish $self->{'h'};
    $self->{'sch'}->_finished($self->{'idx'});
    return 0;
  }
  IPC::Run::pump_nb $self->{'h'};
  return 1;
}

sub exit_code { return IPC::Run::result $_[0]->{'h'}; }

END { $_->kill_kill for @ipc_run_h; }

1;
