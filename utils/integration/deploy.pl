#! /usr/bin/perl -w

use strict;
use warnings;

BEGIN {
  push @INC, "./modules";
}

use Integration;
use Integration::Task::Copy;
use Integration::Task::Checkout;
use Integration::Task::Move;
use Integration::Task::Mkdir;
use Integration::Task::Delete;
use Integration::Task::Rollback;
use Integration::Task::Test::Ping;
use YAML qw(LoadFile);
use Carp;

my $config_file = "./checkout/sanger-plugins/head/conf/deploy.yml"; 
my $config = undef;
if (-e $config_file) {
  $config = LoadFile($config_file);
} else {
  croak "Error opening config file: $config_file\n $!";
}

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

if (-e 'bioperl') {
  my $rm = `rm -r bioperl*`;
}

if (-e 'biomart') {
  my $rm = `rm -r biomart*`;
}

my $checkout_task = Integration::Task::Checkout->new((
                              destination => "checkout",
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
                                     source      => "biomart/biomart-plib",
                                     destination => "checkout/biomart-plib" 
                                     ))
                               );

$integration->add_checkout_task(Integration::Task::Copy->new((
                                     source      => "biomart/biomart-web",
                                     destination => "checkout/biomart-web" 
                                     ))
                               );

my $bioperl_task = Integration::Task::Checkout->new((
                                     destination => "bioperl",
                                     repository  => "cvs.open-bio.org",
                                     root        => "/home/repository/bioperl",
                                     username    => "cvs",
                                     protocol    => "pserver",
                                     name        => "bioperl"
                                   ));

$bioperl_task->add_module('bioperl-live');
$integration->add_checkout_task($bioperl_task);

$integration->add_checkout_task(Integration::Task::Move->new((
                                     source      => "bioperl",
                                     destination => "checkout/bioperl-live" 
                                     ))
                               );

$integration->checkout;

my $rollback_task = Integration::Task::Rollback->new((
                             source      => "/ensemblweb/head/checkout",
                             prefix      => "rollback_"
                           ));

$integration->add_rollback_task($rollback_task);

my $copy_task = Integration::Task::Copy->new((
                             source      => "support/Plugins.pm", 
                             destination => "checkout/conf"
                           ));

my $apache_copy_task = Integration::Task::Copy->new((
                             source      => "/ensemblweb/head/src", 
                             destination => "checkout/src"
                           ));

$integration->add_configuration_task($copy_task);
$integration->add_configuration_task($apache_copy_task);
$integration->add_configuration_task(Integration::Task::Mkdir->new((source => "checkout/img")));
$integration->add_configuration_task(Integration::Task::Mkdir->new((source => "checkout/logs")));
$integration->add_configuration_task(Integration::Task::Mkdir->new((source => "checkout/tmp")));

my $checkout_copy_task = Integration::Task::Copy->new((
                             source      => "checkout", 
                             destination => "/ensemblweb/head"
                           ));

$integration->add_configuration_task($checkout_copy_task);

$integration->stop_command('/ensemblweb/head/checkout/ctrl_scripts/stop_server');
$integration->stop_server;

$integration->configure;

$integration->start_command('/ensemblweb/head/checkout/ctrl_scripts/start_server');
$integration->start_server;

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
