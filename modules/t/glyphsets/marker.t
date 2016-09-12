use strict;
use warnings;

use Test::More;
use Test::Deep;
use EnsEMBL::Web::Utils::UnitTest qw/:all/;

use EnsEMBL::Draw::GlyphSet::marker;

######### SETUP #################

## Create some sample objects (we don't want unit tests to depend on 
## a web server or db connection)
my $hub = create_hub({
                      'species' => 'Homo_sapiens',
                      'type'    => 'Location',
                      'action'  => 'View',
                      });

ok($hub, "Hub created...");

my $slice = create_slice($hub, {
                          'species'         => 'Homo_sapiens',
                          'cs_name'         => 'chromosome',
                          'cs_rank'         => 1,
                          'assembly'        => 'GRCh38',
                          'seq_region_name' => '17',
                          'start'           => 64322400,
                          'end'             => 64323900,
                          'strand'          => 1,
                          });

## We need a fake ImageConfig object for some operations
my $image_config = create_imageconfig($slice, $hub);

## Also create a fake track configuration
my $track_config = create_trackconfig;

## Now create the glyphset
my $glyphset = EnsEMBL::Draw::GlyphSet::marker->new({
                                                          'container' => $slice, 
                                                          'config'    => $image_config,
                                                          'my_config' => $track_config, 
                                                          'strand'    => 1,
                                                        });


########## EXAMPLE DATA ################

my $sample_data = [{'features' => [ 
                            {
                              'label_colour' => '#000000',
                              'href' => '/Homo_sapiens/ZMenu/Marker?db=core;m=RH11719;track=test',
                              'colour' => '#000000',
                              'label' => 'RH11719',
                              '_unique' => 'RH11719:323096:323243',
                              'end' => 844,
                              'start' => 697,
                            },
                            {
                              'label_colour' => '#000000',
                              'href' => '/Homo_sapiens/ZMenu/Marker?db=core;m=BV209439;track=test',
                              'colour' => '#000000',
                              'label' => 'BV209439',
                              '_unique' => 'BV209439:323048:323650',
                              'end' => 1251,
                              'start' => 649
                            },
                            {
                              'label_colour' => '#000000',
                              'href' => '/Homo_sapiens/ZMenu/Marker?db=core;m=D17S1992;track=test',
                              'colour' => '#000000',
                              'label' => 'D17S1992',
                              '_unique' => 'D17S1992:323632:323810',
                              'end' => 1411,
                              'start' => 1233
                            },
                           {
                              'label_colour' => '#000000',
                              'href' => '/Homo_sapiens/ZMenu/Marker?db=core;m=G60155;track=test',
                              'colour' => '#000000',
                              'label' => 'G60155',
                              '_unique' => 'G60155:322529:322719',
                              'end' => 320,
                              'start' => 130
                            },
                            {
                              'label_colour' => '#000000',
                              'href' => '/Homo_sapiens/ZMenu/Marker?db=core;m=RH17926;track=test',
                              'colour' => '#000000',
                              'label' => 'RH17926',
                              '_unique' => 'RH17926:322529:322671',
                              'end' => 272,
                              'start' => 130
                            },
                ]}];

######### TESTS #################

ok($glyphset, "Glyphset 'marker' created");

my $returned_data = $glyphset->get_data;

### Check that data matches what we expect
cmp_deeply($returned_data, $sample_data, 'Checking glyphset data matches expected features');

done_testing();
