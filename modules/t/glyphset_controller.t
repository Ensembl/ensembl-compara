use strict;
use warnings;

use Test::More;

use Bio::EnsEMBL::CoordSystem;
use Bio::EnsEMBL::Slice;
use EnsEMBL::Web::Tree;
use EnsEMBL::Web::Hub;

use EnsEMBL::Draw::GlyphSet::controller;

## Create some sample objects (we don't want unit tests to depend on a db connection
my $cs = Bio::EnsEMBL::CoordSystem->new(-NAME    => 'chromosome',
                                        -VERSION => 'GRCh38',
                                        -RANK    => 1,
                                        ); 
my $slice =  Bio::EnsEMBL::Slice->new(-coord_system     => $cs,
                                      -seq_region_name  => '19',
                                      -start            => 6500000,
                                      -end              => 6800000,
                                      -strand           => 1,
                                      );

## Also create a fake track configuration
my $tree = EnsEMBL::Web::Tree->new;
ok($tree, 'Creating config tree...');

my $config = {
              'data_type' => 'Test',
              'style'     => 'normal',
              'colour'    => 'green',
              };

my $node = $tree->create_node('test', $config);
ok($node, 'Configuration created');

my $hub = EnsEMBL::Web::Hub->new;
ok($hub, 'Hub created');

## Create the controller glyphset
my $glyphset = EnsEMBL::Draw::GlyphSet::controller->new({
                                                          'container' => $slice, 
                                                          'my_config' => $node, 
                                                          'config' => {'hub' => $hub},
                                                        });

## Tests
ok($glyphset, 'Controller module created');

my $output = $glyphset->render;

done_testing();
