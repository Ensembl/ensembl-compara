#! /usr/bin/perl -w

use Test::More qw( no_plan );
use Test::File;
use strict;

BEGIN {
  use_ok( 'Integration::Log::YAML' );
}

my $date = time;
my $location = "tests/files/log.yml";

if (-e $location) {
  my $rm = `rm $location`;
}

my $log = Integration::Log::YAML->new((
                                   date     => $date,
                                   location => $location
                                 ));

isa_ok($log, 'Integration::Log::YAML');

ok(@{ $log->log } == 0);
ok($log->new_build_number == 1);
$log->add_event({date => time, event => "event_1", status => "ok"});
$log->add_event({date => time, event => "event_2", status => "failed"});
$log->add_event({date => time, build => 20, event => "event_3", status => "ok"});
ok(@{ $log->log } == 3);

$log->save;
file_exists_ok($location);
$log->load;

ok($log->log->[0]->{event} eq "event_1");
ok($log->log->[1]->{event} eq "event_2");
ok($log->log->[0]->{status} eq "ok");
ok($log->log->[1]->{status} eq "failed");
ok($log->log->[0]->{status} eq "ok");
ok($log->log->[1]->{status} eq "failed");
ok($log->log->[0]->{build} == 1);
ok($log->log->[1]->{build} == 2);
ok($log->log->[2]->{build} == 20);
