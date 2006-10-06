#! /usr/bin/perl -w

use Test::More qw( no_plan );
use strict;

BEGIN {
  use_ok( 'Integration::Task::InplaceEdit' );
}

my $source = "./tests/files/editme.txt";
my $destination = "./tests/files/edited.txt";
my $inplace = "./tests/files/editinplace.txt";
my $search = "one two three";
my $replace = "four five six";

if (-e $destination) {
  my $rm = `rm $destination`;
}

if (-e $inplace) {
  my $rm = `rm $inplace`;
}

my $task = Integration::Task::InplaceEdit->new((
                                   source      => $source,
                                   destination => $destination
                                 ));

isa_ok($task, 'Integration::Task::InplaceEdit');

$task->add_edit($search, $replace);
$task->process;

open (INPUT, $destination);
my @lines = <INPUT>;
close INPUT;

ok($lines[0] eq $replace . "\n");

open (OUTPUT, ">", $inplace);
print OUTPUT "one two three\n";
print OUTPUT "four five six\n";
print OUTPUT "seven eight nine\n";
print OUTPUT "ten\n";
close OUTPUT;

$task->source($inplace);
$task->destination($inplace);
$task->process;

open (INPUT, $inplace);
@lines = <INPUT>;
close INPUT;

ok ($lines[0] eq "four five six\n");
ok ($lines[1] eq "four five six\n");
ok ($lines[2] eq "seven eight nine\n");
ok ($lines[3] eq "ten\n");
