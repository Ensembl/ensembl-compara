#!/usr/local/bin/perl

use strict;
use Cache::Memcached;
use Data::Dumper;

my $memd = new Cache::Memcached {servers => [ '127.0.0.1:11211' ]};
my $debug_key_list = $memd->get('debug_key_list');
my $key_list = {};

if ($debug_key_list) {
  if (my $pattern = $ARGV[0]) {

    %$key_list = map { $_ => $debug_key_list->{$_} }
                   grep { /$pattern/ }
                      keys %$debug_key_list;

  } else {
    $key_list = $debug_key_list;
  }
  
  print Dumper($key_list);
} else {
  print "No debug_key_list found \n";
}
