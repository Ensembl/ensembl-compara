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
  my @plugins = qw(one two three);

  foreach my $plugin (@plugins) {
    push @INC, $location . $plugin;
  }
}

my $locator = EnsEMBL::Web::Tools::PluginLocator->new(( 
                               locations => [
                                             'EnsEMBL::Web',
                                             'EnsEMBL::One',
                                             'EnsEMBL::Two',
                                             'EnsEMBL::Three',
                                            ],
                               suffix    => "Interface::ZMenu",
                               method    => "ident"
                                                  ));

isa_ok($locator, 'EnsEMBL::Web::Tools::PluginLocator');
ok($locator->include == 1);
ok(!$locator->warnings);

ok(EnsEMBL::One::Interface::ZMenu->ident() eq 'one');
ok(EnsEMBL::Two::Interface::ZMenu->ident() eq 'two');
ok(EnsEMBL::Three::Interface::ZMenu->ident() eq 'three');
ok(!EnsEMBL::Web::Interface::ZMenu->ident());
