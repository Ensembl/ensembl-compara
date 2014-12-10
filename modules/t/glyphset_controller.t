use strict;
use warnings;

use Test::More;

use Bio::EnsEMBL::CoordSystem;
use Bio::EnsEMBL::Slice;
use EnsEMBL::Web::Tree;
use EnsEMBL::Web::Hub;
use EnsEMBL::Web::ImageConfig;

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


## We need a fake ImageConfig object for some operations
my $hub = EnsEMBL::Web::Hub->new;
ok($hub, 'Hub created');

my $image_config = EnsEMBL::Web::ImageConfig->new($hub);

## Set up some sample values for our test image
my $margin      = 5;
my $label_start = $margin;
my $label_width = 100;
my $image_width = 1000;

my $panel_start = $label_start + $label_width + $margin;
my $panel_width = $image_width - $panel_start - $margin;
my $x_scale     = $panel_width / $slice->length;

$image_config->{'transform'}->{'scalex'}         = $x_scale; 
$image_config->{'transform'}->{'absolutescalex'} = 1;
$image_config->{'transform'}->{'translatex'}     = $panel_start;

ok($image_config, 'ImageConfig created');

## Also create a fake track configuration
my $tree = EnsEMBL::Web::Tree->new;
ok($tree, 'Creating config tree...');

my $config = {
              'data_type' => 'Test',
              'style'     => 'normal',
              'colour'    => 'green',
              'caption'   => 'My test',
              };

my $node = $tree->create_node('test', $config);
ok($node, 'Configuration created');

## Create the controller glyphset
my $glyphset = EnsEMBL::Draw::GlyphSet::controller->new({
                                                          'container' => $slice, 
                                                          'config'    => $image_config,
                                                          'my_config' => $node, 
                                                          'strand'    => 1,
                                                        });

## Tests
ok($glyphset, 'Controller module created');

my $output = $glyphset->render;

done_testing();
