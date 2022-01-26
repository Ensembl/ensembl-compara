# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2022] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#!/usr/local/bin/perl

=pod
  Wrapper script for selenium tests. 
  Takes one argument (release number) plus three JSON configuration files:
  - configure Selenium environment
  - select which tests are run in a particular batch
  - configure species to test (optional - defaults to release_<VERSION>_species.conf)

  The purpose of the latter file is to remove dependency on the web code.
  Instead, a helper script dump_species_to_json.pl is used to dump some useful parts
  of the web configuration, which should then be eyeballed to ensure it looks OK.

  Note: Configuration files must be placed in utils/selenium/conf, but they can be
  in any plugin that is configured in Plugins.pm

  Example of usage:

  perl run_tests.pl --release=80 --config=ensembl.conf --tests=link_checker.conf --species=release_80_species.conf

  Important note: the DEBUG flag allows you to run dummy tests that don't rely on selenium,
  so that you can check this script and the base test modules for errors
=cut

use strict;
use warnings;
no warnings 'uninitialized';

use FindBin qw($Bin);
use File::Basename qw( dirname );
use Getopt::Long;
use Data::Dumper;

use LWP::UserAgent;
use JSON qw(from_json);

use EnsEMBL::Selenium;

use vars qw( $SCRIPT_ROOT $SERVERROOT );

BEGIN {
  $SCRIPT_ROOT = dirname($Bin);
  ($SERVERROOT = $SCRIPT_ROOT) =~ s#utils##;
  unshift @INC,"$SERVERROOT/modules";  
  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs; SiteDefs->import; };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;    
}

my ($release, $config, $tests, $species, $verbose, $DEBUG);

GetOptions(
  'release=s' => \$release,
  'config=s'  => \$config,
  'tests=s'   => \$tests,
  'species=s' => \$species,
  'verbose=s' => \$verbose,
  'DEBUG'   => \$DEBUG,
);

die 'Please provide configuration files!' unless ($config && $tests);

if (!$species) {
  $species = sprintf('release_%s_species.conf', $release);
}

## Find config files
my ($config_path, $tests_path, $species_path) = find_configs($SERVERROOT);

die "Couldn't find configuration file $config!" unless $config_path;
die "Couldn't find configuration file $tests!" unless $tests_path;

## Read configurations
my $CONF          = read_config($config_path); 
my $TESTS         = read_config($tests_path); 
my $SPECIES       = read_config($species_path);

 $release ||= $CONF->{'release'};
my $url     = $CONF->{'url'};
my $host    = $CONF->{'host'};
my $port    = $CONF->{'port'}     || '4444';
my $browser = $CONF->{'browser'}  || 'firefox';
my $timeout = $CONF->{'timeout'}  || 50000;

## Validate main configuration
unless ($host) {
  die "You must specify the selenium host, e.g. 127.0.0.1";
}

unless ($url && $url =~ /^http/) {
  die "You must specify a url to test against, eg. http://www.ensembl.org";
}

unless (($TESTS->{'modules'} && scalar(@{$TESTS->{'modules'}||[]}))
        || ($TESTS->{'modules'} && scalar(@{$TESTS->{'modules'}||[]}))) {
  die "You must specify at least one test module, eg. ['Generic']";
}

unless (ref($TESTS->{'modules'}[0]) eq 'HASH' 
          && $TESTS->{'modules'}[0]{'tests'} 
            && scalar(@{$TESTS->{'modules'}[0]{'tests'}||[]})) {
  die "You must specify at least one test method, eg. ['homepage']";
}

unless ($release) {
  die "You must specify a release version!";
}


print "Configuration OK - running tests...\n";

## Allow overriding of verbosity on command line or in configurations
unless (defined($verbose)) {
  $verbose = defined($TESTS->{'verbose'}) ? $TESTS->{'verbose'}
                : defined($CONF->{'verbose'}) ? $CONF->{'verbose'} 
                : 0;
}

my $ua;

unless ($DEBUG) {
  ## Check to see if the selenium server is online 
  $ua = LWP::UserAgent->new(keep_alive => 5, env_proxy => 1);
  $ua->timeout(10);
  my $response = $ua->get("http://$host:$port/selenium-server/driver/?cmd=testComplete");
  if ($response->content ne 'OK') { 
    die "Selenium Server is offline or host configuration is wrong !!!!\n";
  }
}

## Basic config for test modules
my $test_config = {
                    url         => $url,
                    timeout     => $timeout,
                    verbose     => $verbose,  
                    conf        => {'release' => $release},
                    sel_config  => { 
                                      ua          => $ua,
                                      host        => $host,
                                      port        => $port,
                                      browser     => $browser,
                                      browser_url => $CONF->{'url'},
                                    },
                  };


## Separate out the tests by species/non-species
my $test_suite = {
                  'non_species' => [],
                  'species'     => {},
                  };

foreach my $module (@{$TESTS->{'modules'}}) {
  my $species = $module->{'species'} || [];
  if ($species eq 'all') {
    my @keys = keys %$SPECIES;
    $species = \@keys;   
    $module->{'species'} = '';
  }
  if (scalar(@$species)) {
    foreach my $sp (@$species) {
      if ($test_suite->{'species'}{$sp}) {
        push @{$test_suite->{'species'}{$sp}}, $module;
      }
      else {
        $test_suite->{'species'}{$sp} = [$module];
      }
    }
  }
  else {
    push @{$test_suite->{'non_species'}}, $module,
  }
}

#if ($DEBUG) {
#  print Dumper($test_suite);
#}

our $pass = 0;
our $fail = 0;

my ($sec, $min, $hour, $day, $month, $year) = gmtime;
my $timestamp = sprintf('%s%02d%02d_%02d%02d%02d', $year+1900, $month+1, $day, $hour, $min, $sec);

mkdir('test_reports') unless -e 'test_reports';
(my $log_filename = $tests) =~ s/\.conf//;

my $pass_log_filename = sprintf('test_reports/%s_%s_%s.log', $log_filename, 'pass', $timestamp); 
my $fail_log_filename = sprintf('test_reports/%s_%s_%s.log', $log_filename, 'fail', $timestamp); 

our $pass_log;
our $fail_log;
open $pass_log, '>>', $pass_log_filename;;
open $fail_log, '>>', $fail_log_filename;;

## Run any non-species-specific tests first 
foreach my $module (@{$test_suite->{'non_species'}}) {
  my $module_name = $module->{'name'};
  run_test($module_name, $test_config, $module->{'tests'});    
}

## Loop through the relevant tests for each species
foreach my $sp (keys %{$test_suite->{'species'}}) {
  print "\n\n======= TESTING SPECIES $sp:\n";
  foreach my $module (@{$test_suite->{'species'}{$sp}}) {
    my $module_name = $module->{'name'};
    $test_config->{'species'} = {'name' => $sp, %{$SPECIES->{$sp}}};
    run_test($module_name, $test_config, $module->{'tests'});    
  }
}

close($pass_log);
close($fail_log);

my $total = $pass + $fail;
my $plural = $total == 1 ? '' : 's';

print "\n==========================\n";
print "TEST RUN COMPLETED!\n";
print "Ran $total test$plural:\n";
print " - $pass succeeded\n";
print " - $fail failed\n";

if ($tests_path =~ /debug/) {
  print "\n\nIgnore this next message - it simply means that no real selenium tests 
  were run, because we were only testing the harness, not the website\n";
}

################# SUBROUTINES #############################################

sub run_test {
### Run a set of tests within a test module
### Note that there are three report codes:
###   'pass' means the selenium test passed
###   'fail' means the test ran but did not pass
###   'bug' means there was a problem running the test
  my ($module, $config, $tests) = @_;

  ## Try to use the package
  my $package = "EnsEMBL::Selenium::Test::$module";
  print "... Running test module $package...\n";
  eval("use $package");
  if ($@) {
    write_to_log('bug', "Couldn't use $package\n$@", 'run_tests.pl');
    return;
  }

  my (@test_names, $has_test_params);
  if (ref($tests) eq 'ARRAY') {
    @test_names = @{$tests||[]};
  }
  else { 
    @test_names = keys %{$tests||{}};
    $has_test_params = 1;
  }

  unless (@test_names) {
    write_to_log('bug', "No methods specified for test module $package", 'run_tests.pl');
    return;
  }

  my ($object, $error) = $package->new(%{$config||{}});

  if ($error) {
    ## Variable $object is actually an error code
    ## N.B. In this situation, 'pass' is treated as an error
    ## because it means we are aborting this module's tests
    ## (e.g. if it's a Variation test and species has no variation)
    write_to_log($object, $error, $module);
  }
  elsif (!$object || ref($object) !~ /Test/) {
    write_to_log('fail', "Could not instantiate object from package $package"); 
    return;
  }
  else {
    ## Check that site being tested is up
    my @response = $object->check_website;
    if ($response[0] eq 'fail') {
      write_to_log($response[0], "ABORTING TESTS ON $module: ".$response[1], $response[2], $response[3]);
      return;
    }

    ## Run the tests
    foreach my $name (@test_names) {
      my $method = 'test_'.$name;
      my @params = ();
      if ($has_test_params) {
        @params = @{$tests->{$name}||[]};
      }
      if ($object->can($method)) {
        print "...... Trying test method $method...\n";
        my @response = ($object->$method(@params));
        foreach (@response) {
          if (ref($_) eq 'ARRAY') {
            if ($config->{'verbose'} || $_->[0] ne 'pass') { 
              write_to_log(@$_);
            }
            $_->[0] eq 'pass' ? $pass++ : $fail++;
          }
          elsif ($_) {
            $pass++;
          }
          else {
            write_to_log('fail', "Unknown error from $method in $package");
            $fail++;
          }
        }
      }
      else {
        write_to_log('bug', "No such method $method in package $package", 'run_tests.pl');
      }
    }
  }
}

sub write_to_log {
### Write a status line
### TODO Replace with proper logging
  my ($code, $message, $module, $method) = @_;

  my ($sec, $min, $hour, $day, $month, $year) = gmtime;
  my $timestamp = sprintf('at %02d:%02d:%02d on %02d-%02d-%s', $hour, $min, $sec, $day, $month+1, $year+1900);
  
  my $line = uc($code);
  $line    .= " in $module" if $module;
  $line    .= " ::$method" if $method;
  $line    .= " - $message $timestamp\n";

  my $log = $code eq 'pass' ? $pass_log : $fail_log;

  if ($log) {
    print $log $line;
  }
  else {
    print $line; 
  }
}

sub read_config {
### Read a config file and convert from JSON to a perl hash
  my $path = shift;
  my $data = {};
  my $json;
  {
    local $/;
    my $fh;
    if ($path) {
      open $fh, '<', $path;
      $json .= $_ for <$fh>;
      close $fh;
    }
  }
  if ($json) {
    $data = from_json($json);
  }
  return $data;
}

sub find_configs {
### Go through plugins and find the first config file of each type
  my $SERVERROOT = shift; 
  my ($config_path, $tests_path, $species_path);

  my @all_plugins = @{$SiteDefs::ENSEMBL_PLUGINS || []};
  push @all_plugins, ('root', $SERVERROOT);

  while (my ($plugin_name, $dir) = splice @all_plugins, 0, 2) {
    my $path = $dir.'/utils/selenium/conf/'.$config;
    if (!$config_path && $config && -e $path) {
      $config_path = $path;
    }
    $path = $dir.'/utils/selenium/conf/'.$tests;
    if (!$tests_path && $tests && -e $path) {
      $tests_path = $path;
    }
    $path = $dir.'/utils/selenium/conf/'.$species;
    if (!$species_path && $species && -e $path) {
      $species_path = $path;
    }
  }

  return ($config_path, $tests_path, $species_path);
}
