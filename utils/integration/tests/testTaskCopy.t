#! /usr/bin/perl -w

use Test::More qw( no_plan );
use strict;

BEGIN {
  use_ok( 'Integration::Task::Copy' );
}

my $source = "./tests/files/copyme.txt";
my $destination = "./tests/files/copied.txt";

if (-e $destination) {
  my $rm = `rm $destination`;
}

my $task = Integration::Task::Copy->new((
                                   source      => $source,
                                   destination => $destination
                                 ));

isa_ok($task, 'Integration::Task::Copy');

ok($task->source eq $source);
ok($task->destination  eq $destination);

my $content = "this is a test\n";

open (OUTPUT, ">", $source); 
print OUTPUT $content;
close OUTPUT;

$task->process;

open (INPUT, $destination);
my @lines = <INPUT>;
close INPUT;

ok($lines[0] eq $content);
