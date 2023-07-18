#!/usr/bin/env perl
use strict;
use warnings;

$^O = "NOT_LINUX";
my $prog = shift;

do "$prog"
