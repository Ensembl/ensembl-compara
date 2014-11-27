use strict;
use warnings;

use Test::More;

use EnsEMBL::Draw::GlyphSet_controller;

my $c = EnsEMBL::Draw::GlyphSet_controller->new();

ok($c, 'Controller module created');

done_testing();
