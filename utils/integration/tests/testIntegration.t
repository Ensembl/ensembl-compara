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
my $htdocs_location = "./checkout/sanger-plugins/head/htdocs";
my $cvs_repository = "cvs.sanger.ac.uk";
my $cvs_root = "/nfs/ensembl/cvsroot/";
my $release = "branch-ensembl-40";
my $cvs_username = "mw4";

my $integration = Integration->new(( htdocs => $htdocs_location ));

if (-e $checkout_location) {
  my $rm = `rm -r $checkout_location`;
}

if (-e 'bioperl') {
  my $rm = `rm -r bioperl`;
}

if (-e 'biomart') {
  my $rm = `rm -r biomart`;
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
$checkout_task->add_module('ensembl-api');
$checkout_task->add_module('sanger-plugins');

$integration->add_checkout_task($checkout_task);

my $mart_task = Integration::Task::Checkout->new((
                              destination => "biomart",
                              repository  => "cvs.sanger.ac.uk",
                              root        => "/nfs/ensembl/cvsroot/",
                              username    => "mw4",
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

ok ($integration->checkout == 1);

file_exists_ok('checkout/ensembl');
file_exists_ok('checkout/ensembl-draw');
file_exists_ok('checkout/modules');
file_exists_ok('checkout/sanger-plugins');
file_exists_ok('checkout/bioperl-live');
file_exists_ok('checkout/biomart-plib');
file_exists_ok('checkout/biomart-web');

my $copy_task = Integration::Task::Copy->new((
                             source      => "support/Plugins.pm", 
                             destination => "checkout/conf"
                           ));

my $apache_copy_task = Integration::Task::Copy->new((
                             source      => "support/src", 
                             destination => "checkout/src"
                           ));

$integration->add_configuration_task($copy_task);
$integration->add_configuration_task($apache_copy_task);
$integration->add_configuration_task(Integration::Task::Mkdir->new((source => "checkout/img")));
$integration->add_configuration_task(Integration::Task::Mkdir->new((source => "checkout/logs")));
$integration->add_configuration_task(Integration::Task::Mkdir->new((source => "checkout/tmp")));

ok ($integration->configure == 1);

file_exists_ok('checkout/conf/Plugins.pm');
file_exists_ok('checkout/src/httpd');

ok ($integration->test == 100);
ok ($integration->generate_output == 1);
