#! /usr/bin/perl -w

use Test::More qw( no_plan );
use warnings;
use strict;

use vars qw();

BEGIN {
  use_ok( 'EnsEMBL::Web::Tools::PluginLocator' );

  my $location = `pwd`;
  chomp $location;
  $location .= "/files/plugins/";
  my @plugins = qw(one two three web);

  foreach my $plugin (@plugins) {
    push @INC, $location . $plugin;
  }
}

my $locator = EnsEMBL::Web::Tools::PluginLocator->new(( 
                               locations => [
                                             'EnsEMBL::Overload'
                                            ],
                               suffix    => "Interface::ZMenu",
                               method    => "ident"
                                                  ));

isa_ok($locator, 'EnsEMBL::Web::Tools::PluginLocator');
ok($locator->include == 1);
ok(EnsEMBL::Overload::Interface::ZMenu->ident() eq 'web');

$locator->call('new');
isa_ok($locator->result_for('EnsEMBL::Overload::Interface::ZMenu'), 'EnsEMBL::Overload::Interface::ZMenu');
ok($locator->result_for('EnsEMBL::Overload::Interface::ZMenu')->ident eq 'web');
