#!/usr/local/bin/perl

use strict;
use FindBin qw($Bin);
use Cache::Memcached;
use Data::Dumper;

BEGIN{
  unshift @INC, "$Bin/../conf";
  unshift @INC, "$Bin/../modules";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;

  eval{ require EnsEMBL::Web::Cache };
  if ($@){ die "Can't use EnsEMBL::Web::Cache - $@\n"; }
}

my $MEMD = new EnsEMBL::Web::Cache;

if ($MEMD) {

  if ($ARGV[0] =~ /get/i) {
    print $MEMD->get($ARGV[1])."\n";
  } elsif ($ARGV[0] =~ /(tags?)?_?delete/i) {
    shift @ARGV;
    print $MEMD->delete_by_tags(@ARGV)."\n";
  } elsif ($ARGV[0] =~ /flush/i) {
    print "Flushing cache:\n";
    print $MEMD->delete_by_tags." cache items deleted\n";
  } elsif ($ARGV[0] =~ /stats/i) {
    shift @ARGV;
    print "Stats:\n";
    print Dumper($MEMD->stats(@ARGV))."\n";
#  } else {
#  
#    my $debug_key_list = $MEMD->get('debug_key_list');
#    my $key_list = {};
#    
#    if ($debug_key_list) {
#      if (my $pattern = $ARGV[0]) {
#    
#        %$key_list = map { $_ => $debug_key_list->{$_} }
#                       grep { /$pattern/ }
#                          keys %$debug_key_list;
#    
#      } else {
#        $key_list = $debug_key_list;
#      }
#      
#      print Dumper($key_list);
#    } else {
#      print "No debug_key_list found \n";
#    }
#  
  }
} else {
   print "No memcached server configured or can't connect \n";
}


1;