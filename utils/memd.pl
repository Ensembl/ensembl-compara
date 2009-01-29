#!/usr/local/bin/perl

use strict;
use FindBin qw($Bin);
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

  if ($ARGV[0] =~ /version/i) {
    if ($MEMD->version_check) {
      print " all available servers are of correct version\n";
    } else {
      print " one or more servers are of incorrect version\n";
      exit 2;
    }
  } if ($ARGV[0] =~ /get/i) {
    print $MEMD->get($ARGV[1])."\n";
  } elsif ($ARGV[0] =~ /delete/i) {
    shift @ARGV;
    if ($MEMD->delete(@ARGV)) { print "1 item deleted \n"; } else { print "item not found \n"};
  } elsif ($ARGV[0] =~ /flush/i) {
    print " Flushing cache:\n";
    shift @ARGV;
    print $MEMD->delete_by_tags(@ARGV) . " cache items deleted\n";

  } elsif ($ARGV[0] =~ /stats/i) {
    shift @ARGV;
    print " Stats:\n";
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
   print " No memcached server configured or can't connect \n";
}


1;
