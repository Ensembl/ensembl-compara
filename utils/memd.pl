#!/usr/local/bin/perl

use strict;
use Cache::Memcached;
use Data::Dumper;

my $memd = new Cache::Memcached::Tags {servers => [ '127.0.0.1:11311' ]};

if ($ARGV[0] =~ /get/i) {
  print $memd->get($ARGV[1])."\n";
} elsif ($ARGV[0] =~ /tags?_delete/i) {
  shift @ARGV;
  print $memd->tags_delete(@ARGV)."\n";
} else {

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

}


package Cache::Memcached::Tags;

use base 'Cache::Memcached';

sub tags_delete {
  my $self = shift;
  my @tags = @_;
  my $sock = $self->get_sock($tags[0]);

  my $cmd = 'tags_delete '.join(' ', @tags)."\r\n";
  my $res = $self->_write_and_read($sock, $cmd);
  return $res;
}

1;