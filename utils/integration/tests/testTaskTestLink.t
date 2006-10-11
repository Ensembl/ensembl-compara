#! /usr/bin/perl -w

use Test::More qw( no_plan );
use Test::File;
use strict;

BEGIN {
  use_ok( 'Integration::Task::Test::Links' );
}

my $target = "http://head.ensembl.org/info/helpdesk";
my $base = "head.ensembl.org/info/helpdesk";
my $proxy_server = "http://wwwcache.sanger.ac.uk:3128";
my $name = "Help page link check";
my $list = "./tests/files/links.log";

my $task = Integration::Task::Test::Links->new(( 
                                            target => $target,
                                            proxy  => $proxy_server,
                                            name   => $name,
                                            list   => $list,
                                            base   => $base,
                                            critical => "no"
                                          ));

isa_ok($task, 'Integration::Task::Test::Links');

ok($task->target eq $target);
ok($task->proxy eq $proxy_server);
ok($task->name eq $name);
ok($task->list eq $list);
ok($task->critical eq "no");

ok($task->process == 1);
file_exists_ok($task->list);
