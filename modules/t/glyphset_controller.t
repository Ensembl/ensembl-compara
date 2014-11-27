use strict;
use warnings;

use Test::More;

use EnsEMBL::Draw::GlyphSet::controller;
use EnsEMBL::Web::Tree;

## Create a fake track configuration
my $tree = EnsEMBL::Web::Tree->new;
ok($tree, 'Creating config tree...');

my $config = {
              'data_type' => 'Test',
              'style'     => 'normal',
              'colour'    => 'green',
              };

my $node = $tree->create_node('test', $config);
ok($node, 'Configuration created');

my $args = {'my_config' => $node, 'config' => {}}; 

## Create the controller glyphset
my $glyphset = EnsEMBL::Draw::GlyphSet::controller->new($args);

## Tests
ok($glyphset, 'Controller module created');

#my $output = $glyphset->render;

done_testing();
