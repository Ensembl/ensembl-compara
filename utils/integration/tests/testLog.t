#! /usr/bin/perl -w

use Test::More qw( no_plan );
use strict;

BEGIN {
  use_ok( 'Integration::Log' );
}

my $date = time;

my $task = Integration::Log->new((
                                   date => $date,
                                 ));

isa_ok($task, 'Integration::Log');

ok($task->date eq $date);
