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
                                             'EnsEMBL::One',
                                             'EnsEMBL::Two',
                                             'EnsEMBL::Three',
                                            ],
                               suffix    => "Interface::ZMenu",
                                               ));

isa_ok($locator, 'EnsEMBL::Web::Tools::PluginLocator');
ok($locator->include == 1);

my %children = ('EnsEMBL::One::Interface::ZMenu', 'one',
                'EnsEMBL::Two::Interface::ZMenu', 'two',
                'EnsEMBL::Three::Interface::ZMenu', 'three');

my %results = %{ $locator->call('ident') };
foreach my $child (keys %{ $locator->results }) {
  ok($children{$child} eq $results{$child});
  ok($children{$child} eq $locator->result_for($child));
}
