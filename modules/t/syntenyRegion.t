#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;

use Bio::EnsEMBL::Compara::SyntenyRegion;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );
my $synteny_region_adaptor = $compara_db_adaptor->get_SyntenyRegionAdaptor();
my $dnafrag_region_adaptor = $compara_db_adaptor->get_DnaFragRegionAdaptor();

my $sth = $compara_db_adaptor->dbc->prepare("SELECT synteny_region_id, method_link_species_set_id FROM synteny_region LIMIT 1");
$sth->execute();
my ($synteny_region_id, $method_link_species_set_id) = $sth->fetchrow_array();
$sth->finish();

# 
# 1
# 
subtest "Test Bio::EnsEMBL::Compara::SytenyRegion new(void) method", sub {
  my $synteny_region = new Bio::EnsEMBL::Compara::SyntenyRegion();
  isa_ok($synteny_region, "Bio::EnsEMBL::Compara::SyntenyRegion", "check object");
  done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::SyntenyRegion new(ALL) method", sub {
  my $synteny_region = new Bio::EnsEMBL::Compara::SyntenyRegion(-adaptor => $synteny_region_adaptor,
                                                                -dbID => $synteny_region_id,
                                                                -method_link_species_set_id => $method_link_species_set_id);


  isa_ok($synteny_region, "Bio::EnsEMBL::Compara::SyntenyRegion", "check object");
  
  is($synteny_region->adaptor, $synteny_region_adaptor, "adaptor"); 
  is($synteny_region->dbID, $synteny_region_id, "synteny_region_id"); 
  is($synteny_region->method_link_species_set_id, $method_link_species_set_id, "method_link_species_set_id"); 

  done_testing();
};


subtest "Test getter/setter Bio::EnsEMBL::Compara::SyntenyRegion methods", sub {
    my $synteny_region = new Bio::EnsEMBL::Compara::SyntenyRegion();
    ok(test_getter_setter($synteny_region, "adaptor", $synteny_region_adaptor));
    ok(test_getter_setter($synteny_region, "dbID", $synteny_region_id));
    ok(test_getter_setter($synteny_region, "method_link_species_set_id", $method_link_species_set_id));

    my $regions = $dnafrag_region_adaptor->fetch_all_by_synteny_region_id($synteny_region_id);

    ok(test_getter_setter($synteny_region, "regions", $regions));

    done_testing();
};


subtest "Test Bio::EnsEMBL::Compara::SyntenyRegion::get_all_DnaFragRegions method", sub {
    my $regions = $dnafrag_region_adaptor->fetch_all_by_synteny_region_id($synteny_region_id);
    my $synteny_region = new Bio::EnsEMBL::Compara::SyntenyRegion(-adaptor => $synteny_region_adaptor,
                                                                  -dbID    => $synteny_region_id,
                                                                 -regions  => $regions);

    my $dnafrag_regions = $synteny_region->get_all_DnaFragRegions();
    foreach my $dnafrag_region (@$dnafrag_regions) {
        foreach my $region (@$regions) {
            if ($dnafrag_region->dnafrag_id == $region->dnafrag_id) {
                is_deeply($dnafrag_region, $region);
            }
        }
    }

    done_testing();
};

done_testing();
