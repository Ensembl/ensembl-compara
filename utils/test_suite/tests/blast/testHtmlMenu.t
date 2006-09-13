#! /usr/bin/perl -w

use Test::More qw( no_plan );
use strict;

BEGIN {
  use_ok( 'EnsEMBL::Web::Document::HTML::Menu' );
}

my $menu= EnsEMBL::Web::Document::HTML::Menu->new;

my $type = "bulletted";
my $caption = "caption";
my %options = ( 'priority' => 1 );

my $john = "john";
$menu->add_block($john, $type, $caption, %options);

my $paul = "paul";
$menu->add_block($paul, $type, $caption, %options);

my $george = "george";
$menu->add_block($george, $type, $caption, %options);

my $ringo = "ringo";
$menu->add_block($ringo, $type, $caption, %options);

my @blocks = $menu->blocks;

ok(@blocks eq '4', '4 blocks');
ok($blocks[0] eq $john, 'john present');
ok($blocks[1] eq $paul, 'paul present');
ok($blocks[2] eq $george, 'george present');
ok($blocks[3] eq $ringo, 'ringo present');

$menu->delete_block($george);
@blocks = $menu->blocks;

ok(@blocks eq '3', '3 blocks');
ok($blocks[0] eq $john, 'john present');
ok($blocks[1] eq $paul, 'paul present');
ok($blocks[2] eq $ringo, 'ringo present, george absent');
