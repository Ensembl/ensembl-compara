#! /usr/bin/perl -w

use Test::More qw( no_plan );
use strict;

BEGIN {
  use_ok( 'Integration::Task::Checkout' );
}

my $destination = "./tests/checkout/";
my $repository = "cvs.sanger.ac.uk";
my $root = "/nfs/ensembl/cvsroot/";
my $username = "mw4";
my $name = "sanger-plugins";

if (-e $destination) {
  my $rm = `rm $destination`;
}

my $task = Integration::Task::Checkout->new((
                                   destination => $destination,
                                   repository  => $repository,
                                   root        => $root,
                                   username    => $username, 
                                   name        => $name 
                                 ));

isa_ok($task, 'Integration::Task::Checkout');

ok($task->destination  eq $destination);
ok($task->repository   eq $repository);
ok($task->root         eq $root);
ok($task->username     eq $username);
ok($task->name         eq $name);
ok($task->protocol     eq "ext");

ok(@{ $task->modules } eq 0);
$task->add_module('sanger-plugins');
ok(@{ $task->modules } eq 1);
$task->process;
