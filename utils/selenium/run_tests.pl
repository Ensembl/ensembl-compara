# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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
 - configure species to test (optional)

 The purpose of the latter file is to remove dependency on the web code.
 Instead, a helper script is used to dump some useful parts of the
 web configuration, which should then be eyeballed to ensure it looks OK.

  Note: Configuration files must be placed in utils/selenium/conf, but they can be
  in any plugin that is configured in Plugins.pm

  Example of usage:

  perl run_tests.pl --release=80 --config=ensembl.conf --tests=link_checker.conf --species=release_80_species.conf
=cut

use strict;
use warnings;
no warnings 'uninitialized';

use FindBin qw($Bin);
use File::Basename qw( dirname );
use Getopt::Long;

use LWP::UserAgent;
use JSON qw(from_json);

use vars qw( $SCRIPT_ROOT $SERVERROOT );

BEGIN {
  $SCRIPT_ROOT = dirname($Bin);
  ($SERVERROOT = $SCRIPT_ROOT) =~ s#utils##;
  unshift @INC,"$SERVERROOT/modules";  
  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;    
}

my ($release, $config, $tests, $species);

GetOptions(
  'release=s' => \$release,
  'config=s'  => \$config,
  'tests=s'   => \$tests,
  'species=s' => \$species,
);

die 'Please provide configuration files!' unless ($config && $tests);

## Find config files
my ($config_path, $tests_path, $species_path) = find_configs($SERVERROOT);

die "Couldn't find configuration file $config!" unless $config_path;
die "Couldn't find configuration file $tests!" unless $tests_path;

## Read configurations
my $CONF          = read_config($config_path); 
my $TESTS         = read_config($tests_path); 
my $SPECIES       = read_config($species_path);

## Validate main configuration
unless ($CONF->{'host'}) {
  die "You must specify the selenium host, e.g. 127.0.0.1";
}

unless ($CONF->{'url'} && $CONF->{'url'} =~ /^http/) {
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

print "Configuration OK - running tests...";

my $browser = $CONF->{'browser'}  || 'firefox';
my $port    = $CONF->{'port'}     || '4444';
my $timeout = $CONF->{'timeout'}  || 50000;
my $verbose = $CONF->{'verbose'}  || 0;

=pod
# check to see if the selenium server is online(URL returns OK if server is online).
my $ua = LWP::UserAgent->new(keep_alive => 5, env_proxy => 1);
$ua->timeout(10);
my $response = $ua->get("http://$host:$port/selenium-server/driver/?cmd=testComplete");
if($response->content ne 'OK') { 
  print "\nSelenium Server is offline or IP Address is wrong !!!!\n";
  exit;
}
=cut

## Basic config for test modules
my $test_config = {
                    url     => $CONF->{'url'},
                    host    => $CONF->{'host'},
                    port    => $port,
                    browser => $browser,
                    conf    => {
                                release => $release,
                                timeout => $timeout,
                                },
                    verbose => $verbose,  
                  };


## Separate out the tests by species/non-species
my $test_suite = {
                  'non_species' => [],
                  'species'     => {},
                  };

foreach my $module (@{$TESTS->{'modules'}}) {
  my $species = $module->{'species'} || [];
  if ($species eq 'all') {
  }
  elsif (scalar(@$species)) {
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

## Run any non-species-specific tests first 
foreach my $module (@{$test_suite->{'non_species'}}) {
  my $module_name = $module->{'name'};
  run_test($module_name, $test_config, $module->{'tests'});    
}

## Loop through the relevant tests for each species
foreach my $sp (keys %{$test_suite->{'species'}}) {
  foreach my $module (@{$test_suite->{'species'}{$sp}}) {
    my $module_name = $module->{'name'};
    $test_config->{'species'} = $species;
    run_test($module_name, $test_config, $module->{'tests'});    
  }
}

print "TEST RUN COMPLETED\n\n";

################# SUBROUTINES #############################################

sub run_test {
  my ($module, $config, $tests) = @_;

  ## Try to use the package
  my $package = "EnsEMBL::Selenium::Test::$module";
  eval("use $package");
  if ($@) {
    write_to_log("TEST FAILED: Couldn't use $package\n$@");
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
    write_to_log("TEST FAILED: No methods specified for test module $package");
    return;
  }

  my $object = $package->new(%{$config||{}});

  ## Run the tests
  foreach my $name (@test_names) {
    my $method = 'test_'.$name;
    my @params = ();
    if ($has_test_params) {
      @params = @{$tests->{$name}||[]};
    }
    if ($object->can($method)) {
      my $error = $object->$method(@params);
      write_to_log($error) if $error;
    }
    else {
      write_to_log("TEST FAILED: No such method $method in package $package");
    }
  }
}

sub write_to_log {
  my $message = shift;
  ## TODO Replace with proper logging
  print "$message\n";
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
