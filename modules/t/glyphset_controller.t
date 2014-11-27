use strict;
use warnings;

use Test::More;

use EnsEMBL::Draw::GlyphSet::controller;
use EnsEMBL::Web::Tree;

## Create a fake track configuration
my $tree = EnsEMBL::Web::Tree->new;
my $config = {
              'data_type' => 'Test',
              'style'     => 'normal',
              };

my $node = $tree->create_node('test', $config);
my $args = {'my_config' => $node}; 

## Create the controller glyphset
my $glyphset = EnsEMBL::Draw::GlyphSet::controller->new($args);

## Tests
ok($glyphset, 'Controller module created');

done_testing();
