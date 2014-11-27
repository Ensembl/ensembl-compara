use strict;
use warnings;

use Test::More;

use EnsEMBL::Draw::GlyphSet::controller;

my $c = EnsEMBL::Draw::GlyphSet::controller->new();

ok($c, 'Controller module created');

done_testing();
