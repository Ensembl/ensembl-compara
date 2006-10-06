#! /usr/bin/perl -w

use Test::More qw( no_plan );
use Test::File;
use strict;

BEGIN {
  use_ok( 'Integration' );
  use_ok( 'Integration::Task::Copy' );
  use_ok( 'Integration::Task::Checkout' );
  use_ok( 'Integration::Task::Move' );
  use_ok( 'Integration::Task::Mkdir' );
}

my $checkout_location = "./checkout";
my $htdocs_location = "./checkout/htdocs";
my $cvs_repository = "cvs.sanger.ac.uk";
my $cvs_root = "/nfs/ensembl/cvsroot/";
my $release = "branch-ensembl-40";
my $cvs_username = "mw4";
my $log_location = "log.yml";

my $integration = Integration->new((
                                    htdocs => $htdocs_location,
                                    log_location => $log_location
                                  ));

if (-e $checkout_location) {
  my $rm = `rm -r $checkout_location`;
}

isa_ok($integration, 'Integration');
isa_ok($integration->view, 'IntegrationView');
ok ($integration->htdocs_location eq $htdocs_location);

my $checkout_task = Integration::Task::Checkout->new((
                              destination => "checkout",
                              repository  => "cvs.sanger.ac.uk",
                              root        => "/nfs/ensembl/cvsroot/",
                              username    => "mw4",
                              name        => "checkout"
                           ));

$checkout_task->add_module('ensembl-website');

$integration->add_checkout_task($checkout_task);

ok ($integration->checkout == 1);

file_exists_ok('checkout/ensembl-draw');
file_exists_ok('checkout/modules');

my $copy_task = Integration::Task::Copy->new((
                             source      => "support/Plugins.pm", 
                             destination => "checkout/conf"
                           ));

$integration->add_configuration_task($copy_task);
$integration->add_configuration_task(Integration::Task::Mkdir->new((source => "checkout/img")));
$integration->add_configuration_task(Integration::Task::Mkdir->new((source => "checkout/logs")));
$integration->add_configuration_task(Integration::Task::Mkdir->new((source => "checkout/tmp")));

ok ($integration->configure == 1);

file_exists_ok('checkout/conf/Plugins.pm');

ok ($integration->test == 100);

$integration->update_log;
file_exists_ok($log_location);
