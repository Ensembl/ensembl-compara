use strict;
use warnings;

use Test::More;

use EnsEMBL::Web::Utils::SetUpTest qw/:all/;

use EnsEMBL::Draw::GlyphSet::marker;

######### SETUP #################

## Create some sample objects (we don't want unit tests to depend on a db connection
my $slice = create_slice({
                          'cs_name'         => 'chromosomes',
                          'cs_rank'         => 1,
                          'assembly'        => 'GRCh38',
                          'seq_region_name' => '19',
                          'start'           => 6500000,
                          'end'             => 6800000,
                          'strand'          => 1,
                          });


## We need a fake ImageConfig object for some operations
my $image_config = create_imageconfig($slice);

## Also create a fake track configuration
my $track_config = create_trackconfig({
              'data_type' => 'Test',
              'style'     => 'normal',
              'colour'    => 'green',
              'caption'   => 'My test',
                                      });
## Create the controller glyphset
my $glyphset = EnsEMBL::Draw::GlyphSet::marker->new({
                                                          'container' => $slice, 
                                                          'config'    => $image_config,
                                                          'my_config' => $track_config, 
                                                          'strand'    => 1,
                                                        });

######### TESTS #################

ok($glyphset, "Glyphset 'marker' created");

my $data = $glyphset->get_data;
warn ">>> DATA $data";

### Check that data matches what we expect


done_testing();
