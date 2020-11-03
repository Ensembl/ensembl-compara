#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use strict;
use warnings;

use Test::More;
use Test::Exception;

use Bio::EnsEMBL::Compara::Locus;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( 'multi' );
my $compara_db_adaptor = $multi->get_DBAdaptor( 'compara' );

##
#####################################################################

my $dnafrag_altregion_adaptor = $compara_db_adaptor->get_DnaFragAltRegionAdaptor();
isa_ok($dnafrag_altregion_adaptor, 'Bio::EnsEMBL::Compara::DBSQL::DnaFragAltRegionAdaptor', 'dnafrag_altregion_adaptor');

##
#####################################################################
my $sth = $multi->get_DBAdaptor( 'compara' )->dbc->prepare('SELECT
      dnafrag_id, length, df.name, df.genome_db_id, coord_system_name
    FROM dnafrag df left join genome_db gdb USING (genome_db_id)
    WHERE gdb.name = "homo_sapiens" AND is_reference = 1 ORDER BY dnafrag_id DESC LIMIT 1');
$sth->execute();
my ($dnafrag_id, $dnafrag_length, $dnafrag_name, $genome_db_id, $coord_system_name) =
  $sth->fetchrow_array();
$sth->finish();

subtest 'Test Bio::EnsEMBL::Compara::DBSQL::DnaFragAltRegionAdaptor fetch_by_dbID() method', sub {

    # This is the dbID of a dnafrag that has an alt-region defined
    my $dnafrag_id = 13708879;
    my $alt_region = $dnafrag_altregion_adaptor->fetch_by_dbID($dnafrag_id);
    isa_ok($alt_region, 'Bio::EnsEMBL::Compara::Locus', 'alt_region');
    is($alt_region->dnafrag_id, $dnafrag_id, 'Checking dbID');
    is($alt_region->dnafrag_start, 1000000, 'Checking dnafrag_start');
    is($alt_region->dnafrag_end, 1500000, 'Checking dnafrag_end');

    $alt_region = $dnafrag_altregion_adaptor->fetch_by_dbID(-$dnafrag_id);
    is($alt_region, undef, 'Fetching by dbID with wrong dbID returns undef');

    done_testing();
};

subtest 'Test Bio::EnsEMBL::Compara::DBSQL::DnaFragAltRegionAdaptor fetch_all_by_dbID_list() method', sub {

    # This is the dbID of a dnafrag that has an alt-region defined
    my $dnafrag_id = 13708879;
    my $alt_regions = $dnafrag_altregion_adaptor->fetch_all_by_dbID_list([$dnafrag_id]);
    is(ref($alt_regions), 'ARRAY', 'Got an array');
    is(scalar(@$alt_regions), 1, 'Of 1 elmeent');

    my $alt_region = $alt_regions->[0];
    isa_ok($alt_region, 'Bio::EnsEMBL::Compara::Locus', 'alt_region');
    is($alt_region->dnafrag_id, $dnafrag_id, 'Checking dbID');
    is($alt_region->dnafrag_start, 1000000, 'Checking dnafrag_start');
    is($alt_region->dnafrag_end, 1500000, 'Checking dnafrag_end');

    $alt_regions = $dnafrag_altregion_adaptor->fetch_all_by_dbID_list([-$dnafrag_id]);
    is(ref($alt_regions), 'ARRAY', 'Got an array');
    is(scalar(@$alt_regions), 0, 'Of 0 elmeents');

    done_testing();
};

subtest 'Test Bio::EnsEMBL::Compara::DBSQL::DnaFragAltRegionAdaptor store_or_update() and delete_by_dbID() methods', sub {

    # The default value of $dnafrag_id is a dnafrag that has no alt-region
    my $alt_region = $dnafrag_altregion_adaptor->fetch_by_dbID($dnafrag_id);
    is($alt_region, undef, "No alt-region for dnafrag_id=$dnafrag_id");

    $alt_region = new Bio::EnsEMBL::Compara::Locus(
        -DNAFRAG_ID     => $dnafrag_id,
        -DNAFRAG_START  => 34,
        -DNAFRAG_END    => 45,
    );
    $dnafrag_altregion_adaptor->store_or_update($alt_region);
    $alt_region = $dnafrag_altregion_adaptor->fetch_by_dbID($dnafrag_id);
    ok($alt_region, 'Got something');
    isa_ok($alt_region, 'Bio::EnsEMBL::Compara::Locus', 'alt_region');
    is($alt_region->dnafrag_id, $dnafrag_id, 'Checking dbID');
    is($alt_region->dnafrag_start, 34, 'Checking dnafrag_start');
    is($alt_region->dnafrag_end, 45, 'Checking dnafrag_end');

    $alt_region->dnafrag_start(35);
    $alt_region->dnafrag_end(46);
    $dnafrag_altregion_adaptor->store_or_update($alt_region);
    $alt_region = $dnafrag_altregion_adaptor->fetch_by_dbID($dnafrag_id);
    ok($alt_region, 'Got something after updating');
    isa_ok($alt_region, 'Bio::EnsEMBL::Compara::Locus', 'alt_region');
    is($alt_region->dnafrag_id, $dnafrag_id, 'Checking dbID');
    is($alt_region->dnafrag_start, 35, 'Checking dnafrag_start');
    is($alt_region->dnafrag_end, 46, 'Checking dnafrag_end');

    $dnafrag_altregion_adaptor->delete_by_dbID($dnafrag_id);
    $alt_region = $dnafrag_altregion_adaptor->fetch_by_dbID($dnafrag_id);
    is($alt_region, undef, "No more alt-region for dnafrag_id=$dnafrag_id");

    done_testing();
};

subtest 'Test Bio::EnsEMBL::Compara::DnaFrag get_alt_region', sub {

    my $dnafrag_adaptor = $dnafrag_altregion_adaptor->db->get_DnaFragAdaptor;

    # The default value of $dnafrag_id is a dnafrag that has no alt-region
    my $dnafrag = $dnafrag_adaptor->fetch_by_dbID($dnafrag_id);
    my $alt_region = $dnafrag->get_alt_region;
    is($alt_region, undef, "No more alt-region for dnafrag_id=$dnafrag_id");

    # This is the dbID of a dnafrag that has an alt-region defined
    my $dnafrag_id = 13708879;
    $dnafrag = $dnafrag_adaptor->fetch_by_dbID($dnafrag_id);
    $alt_region = $dnafrag->get_alt_region;
    ok($alt_region, 'Got something');
    isa_ok($alt_region, 'Bio::EnsEMBL::Compara::Locus', 'alt_region');
    is($alt_region->dnafrag_id, $dnafrag_id, 'Checking dbID');
    is($alt_region->dnafrag_start, 1000000, 'Checking dnafrag_start');
    is($alt_region->dnafrag_end, 1500000, 'Checking dnafrag_end');

};

done_testing();
