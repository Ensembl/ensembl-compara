#!/usr/local/bin/perl -w

use strict;

my $print = 0;
my $last_print;

while  (<>) {
  if (/^The output \(if any\) follows:$/) {
    $print = 1;
    <>;
    next;
  }
  if (/^PS:$/) {
    last;
  }
  next unless ($print);

  unless (defined $last_print) {
    $last_print = $_;
    print $_;
  } elsif (! ($last_print =~ /^$/ && /^$/)) {
    print $_;
    $last_print = $_;
  }
}

exit 0;
