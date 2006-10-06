#! /usr/bin/perl -w

use Test::More qw( no_plan );
use strict;

BEGIN {
  use_ok( 'Integration::Task::Test::Ping' );
}

my $target = "http://www.google.com";
my $proxy_server = "http://wwwcache.sanger.ac.uk:3128";
my $search = "<title>Google</title>";
my $name = "Google ping test";

my $task = Integration::Task::Test::Ping->new(( 
                                            target => $target,
                                            proxy  => $proxy_server,
                                            search => $search,
                                            name   => $name,
                                            critical => "yes"
                                          ));

isa_ok($task, 'Integration::Task::Test::Ping');

ok($task->target eq $target);
ok($task->proxy eq $proxy_server);
ok($task->name eq $name);
ok($task->critical eq "yes");

ok($task->process == 1);
ok ($task->did_fail == 0);

$task->search("<title>Yahoo!</title>");

ok ($task->process == 0);
ok ($task->did_fail > 0);
