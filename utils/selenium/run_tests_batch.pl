#!/usr/local/bin/perl

use strict;
use lib '../modules';
use Getopt::Long;
use Data::Dumper;

my $conf_file = 'selenium_test.conf';
my $host ;#= 'localhost'; 
my $port = '4444';
my $output_dir = '.';
my $verbose;

GetOptions(
  'conf=s'    => \$conf_file,
  'host=s'  => \$host,
  'port=s'  => \$port,
  'verbose' => \$verbose,
  'output_dir=s' => \$output_dir,
);

die "You must specify a conf file, eg. --conf /path/to/myconf.conf" unless $conf_file;
die "Output dir $output_dir does not exist" unless -d $output_dir;

my $conf = do $conf_file
  || die "Could not load configuration from " . $conf_file;
  
foreach my $opts (@$conf) {
  my $module  = $opts->{module};
  my $url     = $opts->{url};
  my $timeout = $opts->{timeout};
  my @test    = ref $opts->{test} eq 'ARRAY' ? @{$opts->{test}} : ();
  my @skip    = ref $opts->{skip} eq 'ARRAY' ? @{$opts->{skip}} : ();
  
  if (!$module) {
    print "\n\nSkipping bad config - no module name!\n" . Dumper($opts);
    next;
  }
  
  print "\n****************************************\n";
  print " $module\n";
  print "****************************************\n";
  
  if (!$url) {
    print "Skipping - no url supplied.\n";
    next;
  }

  my $start_time = time;
    
    
    my $filepath = "$output_dir/${module}.txt";
    #print "  output file is [$filepath]\n";
    
    my $cmd = qq{perl run_tests.pl --module "$module" --url "$url" --species "$sp" --host "$host" --port "$port"};
    $cmd .= qq{ --timeout "$timeout"} if defined $timeout;
    $cmd .= qq{ --test "$_"} foreach @test;
    $cmd .= qq{ --skip "$_"} foreach @skip; 
    $cmd .= qq{ --verbose} if $verbose; 
    $cmd .= qq{ > "$filepath" 2>&1};
    
    #print "  $cmd\n";
    system $cmd;
    
    my $errors = `grep -c "# Error" "$filepath"`;
    chomp($errors);
    if ($errors > 0) {
      print "  ^ found $errors errors\n";
    } 
  
  printf "\nRuntime was %s secs\n", time - $start_time;
  
}

printf "\nTotal runtime was %s secs\n", time - $^T;
