#! /usr/bin/perl -w

use Test::More qw( no_plan );
use strict;

BEGIN {
  use_ok( 'Integration::Task::Test' );
}

my $target = "one";

my $task = Integration::Task::Test->new(( target => $target ));

isa_ok($task, 'Integration::Task::Test');

ok($task->target eq $target);
