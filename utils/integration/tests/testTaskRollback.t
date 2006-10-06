#! /usr/bin/perl -w

use Test::More qw( no_plan );
use Test::File;
use strict;

BEGIN {
  use_ok( 'Integration::Task::Rollback' );
}

my $prefix = "rollback_";
my $source = "tests/files/testdir";

my $task = Integration::Task::Rollback->new(( 
                                         source => $source,
                                         prefix => $prefix
                                          ));

isa_ok($task, 'Integration::Task::Rollback');

ok($task->prefix eq $prefix);
ok($task->source eq $source);
ok($task->destination eq "tests/files/rollback_testdir");

file_exists_ok($source);

ok($task->process == 1);
file_exists_ok($task->destination);

ok($task->purge == 1);
file_not_exists_ok($task->destination);

my $mk = `mkdir $source`;
file_exists_ok($source);

ok($task->process == 1);
file_not_exists_ok($source);
file_exists_ok($task->destination);

ok($task->rollback == 1);
file_exists_ok($source);
file_not_exists_ok($task->destination);
