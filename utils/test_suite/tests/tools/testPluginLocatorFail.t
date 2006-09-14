#! /usr/bin/perl -w

use Test::More qw( no_plan );
use warnings;
use strict;

use vars qw();

BEGIN {
  use_ok( 'EnsEMBL::Web::Tools::PluginLocator' );
}

my $location = `pwd`;
chomp $location;
$location .= "/files/plugins/";
my @plugins = qw(one two three);

foreach my $plugin (@plugins) {
  push @INC, $location . $plugin;
}

my $locator_fail = EnsEMBL::Web::Tools::PluginLocator->new(( 
                               locations => [ 'EnsEMBL::NoNoNo' ],
                               suffix    => "Interface::ZMenu",
                               method    => "ident"
                                                  ));
ok($locator_fail->include == 0);

foreach my $warning (@{ $locator_fail->warnings }) {
  ok($warning =~ /Can't locate EnsEMBL\/NoNoNo\/Interface\/ZMenu.pm/);
}
