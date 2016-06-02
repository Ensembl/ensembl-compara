use strict;
use warnings;

use Test::More;

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::Utils::SetUpTest qw/:all/;

use EnsEMBL::Draw::GlyphSet::marker;

######### SETUP #################

## Create some sample objects (we don't want unit tests to depend on a db connection
my $hub   = EnsEMBL::Web::Hub->new;
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
use Data::Dumper;
warn ">>> DATA ".Dumper($data);

### Check that data matches what we expect


done_testing();
