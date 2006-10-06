#! /usr/bin/perl -w

use Test::More qw( no_plan );
use strict;

BEGIN {
  use_ok( 'Integration::Task' );
}

my $source = "./checkout";
my $destination = "./checkout/sanger-plugins/head/htdocs";

my $task = Integration::Task->new((
                                   source      => $source,
                                   destination => $destination
                                 ));

isa_ok($task, 'Integration::Task');

ok($task->source eq $source);
ok($task->destination  eq $destination);
