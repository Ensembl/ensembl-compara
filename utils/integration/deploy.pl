#! /usr/local/bin/perl

use strict;
use warnings;

BEGIN {
  push @INC, "/ensemblweb/head/integration/modules";
  $SIG{INT} = \&CATCH;
}

use Integration;
use Integration::Task::Copy;
use Integration::Task::Checkout;
use Integration::Task::Move;
use Integration::Task::Mkdir;
use Integration::Task::Delete;
use Integration::Task::Execute;
use Integration::Task::Rollback;
use Integration::Task::Symlink;
use Integration::Task::EDoc;
use Integration::Task::Test::Ping;
use YAML qw(LoadFile);
use Carp;

open (INPUT, "/ensemblweb/head/integration/cvs.update") or die;

my $run = 0;
foreach my $output (<INPUT>) {
  if ($output =~ /^U/) {
    $run = 1;
  }
}

if ($run == 0) {
  print "Everything is up to date - exiting.\n";
#  exit;
} else {
  print "Updates found - syncing server.\n";
}

close INPUT;

my $config_file = "./deploy.yml"; 

if ($ARGV[0]) {
  $config_file = $ARGV[0];
}

print "Using: $config_file\n";

my $config = undef;
if (-e $config_file) {
  $config = LoadFile($config_file);
} else {
  croak "Error opening config file: $config_file\n $!";
}

my $lock = "/ensemblweb/head/integration/lock/locked";
my $checkout_location = $config->{checkout_location}; 
my $htdocs_location = $config->{htdocs_location}; 
my $cvs_repository = $config->{repository}; 
my $cvs_root = $config->{root}; 
my $cvs_username = $config->{username}; 
my $log_location = $config->{log_location}; 
my $proxy = $config->{proxy}; 
my $server = $config->{server}; 

my $integration = Integration->new(( 
                                    htdocs => $htdocs_location,
                                    log_location => $log_location
                                  ));

if (-e $checkout_location) {
  my $rm = `rm -r $checkout_location*`;
}

if (-e 'biomart') {
  my $rm = `rm -r biomart*`;
}

if (-e $lock) {
  print "Locked - exiting\n";
  exit;
} else {
  my $touch = `touch $lock`;
}

my $checkout_task = Integration::Task::Checkout->new((
                              destination => $checkout_location,
                              repository  => $cvs_repository,
                              root        => $cvs_root,
                              username    => $cvs_username,
                              name        => "checkout"
                           ));

$checkout_task->add_module('ensembl-website');
$checkout_task->add_module('ensembl-api');
$checkout_task->add_module('sanger-plugins');

$integration->add_checkout_task($checkout_task);

my $mart_task = Integration::Task::Checkout->new((
                              destination => "biomart",
                              repository  => $cvs_repository,
                              root        => $cvs_root,
                              username    => $cvs_username,
                              release     => "release-0_4",
                              name        => "biomart"
                           ));

$mart_task->add_module('biomart-plib');
$mart_task->add_module('biomart-web');

$integration->add_checkout_task($mart_task);

$integration->add_checkout_task(Integration::Task::Copy->new((
                                     source      => "/ensemblweb/head/integration/biomart/biomart-plib",
                                     destination => "/ensemblweb/head/integration/checkout/biomart-plib" 
                                     ))
                               );

$integration->add_checkout_task(Integration::Task::Copy->new((
                                     source      => "/ensemblweb/head/integration/biomart/biomart-web",
                                     destination => "/ensemblweb/head/integration/checkout/biomart-web" 
                                     ))
                               );

$integration->checkout;

my $rollback_task = Integration::Task::Rollback->new((
                             source      => "/ensemblweb/head/checkout",
                             prefix      => "rollback_"
                           ));

$integration->add_rollback_task($rollback_task);

my $copy_task = Integration::Task::Copy->new((
                             source      => "/ensemblweb/head/integration/support/Plugins.pm", 
                             destination => "/ensemblweb/head/integration/checkout/conf"
                           ));

my $apache_copy_task = Integration::Task::Copy->new((
                             source      => "/ensemblweb/head/src", 
                             destination => "/ensemblweb/head/integration/checkout/src"
                           ));

my $bioperl_link = Integration::Task::Symlink->new((
                             source      => "/ensemblweb/shared/bioperl/bioperl-release-1-2-3", 
                             destination => "/ensemblweb/head/integration/checkout/bioperl-live"
                           ));

$integration->add_configuration_task($copy_task);
$integration->add_configuration_task($apache_copy_task);
$integration->add_configuration_task($bioperl_link);
$integration->add_configuration_task(Integration::Task::Mkdir->new((source => "/ensemblweb/head/integration/checkout/img")));
$integration->add_configuration_task(Integration::Task::Mkdir->new((source => "/ensemblweb/head/integration/checkout/logs")));
$integration->add_configuration_task(Integration::Task::Mkdir->new((source => "/ensemblweb/head/integration/checkout/tmp")));

$integration->add_configuration_task(Integration::Task::EDoc->new((source => "/ensemblweb/head/integration/checkout/utils/edoc", destination => "/ensemblweb/head/integration/checkout/htdocs/info/webcode/docs")));

$integration->add_configuration_task(Integration::Task::Execute->new((source => "/ensemblweb/head/integration/checkout/ctrl_scripts/start_server")));

my $checkout_copy_task = Integration::Task::Copy->new((
                             source      => "/ensemblweb/head/integration/checkout", 
                             destination => "/ensemblweb/head"
                           ));

$integration->add_configuration_task($checkout_copy_task);

$integration->add_configuration_task(Integration::Task::Execute->new((source => "/ensemblweb/head/checkout/ctrl_scripts/stop_server")));
$integration->add_configuration_task(Integration::Task::Execute->new((source => "/ensemblweb/head/checkout/ctrl_scripts/start_server")));

$integration->configure;

my $server_up_test = Integration::Task::Test::Ping->new((
                                               target   => $server,
                                               proxy    => $proxy,
                                               search   => "Mammalian genomes",
                                               name     => "Server start",
                                               critical => "yes"
                                                       ));

$integration->add_test_task($server_up_test);

$integration->test;

if ($integration->critical_fail) {
  warn "CRITICAL FAILURE: " . $integration->test_result . "% pass rate";
  $integration->rollback;
} else {
  $rollback_task->purge;
}

if ($integration->test_result < 100) {
  warn "TESTS FAILED: " . $integration->test_result . "% pass rate";
}

$integration->update_log;
$integration->generate_output;

my $rm = `rm $lock`;

sub CATCH {
  my $sig = shift;
  print "SIGINT caught - exiting";
  my $rm = `rm $lock`;
  exit;
}
