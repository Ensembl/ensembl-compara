#!/usr/bin/env perl

use strict;
use warnings;
 
use Test::Harness;
use Test::More;

use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Utils::Exception qw(verbose);
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Compara::GenomeDB;

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_dba = $multi->get_DBAdaptor( "compara" );
my $dnafrag_adaptor = $compara_dba->get_DnaFragAdaptor();
my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();

##
#####################################################################

my $sth = $compara_dba->dbc->prepare("SELECT dnafrag_id, length, name, genome_db_id, coord_system_name, is_reference FROM dnafrag LIMIT 1");
$sth->execute();
my ($dbID, $length, $name, $genome_db_id, $coord_system_name, $is_reference) = $sth->fetchrow_array();
$sth->finish();

my $genome_db = $genome_db_adaptor->fetch_by_dbID($genome_db_id);

subtest "Test Bio::EnsEMBL::Compara::DnaFrag::new(void)", sub {

    my $dnafrag = new Bio::EnsEMBL::Compara::DnaFrag();
    isa_ok($dnafrag, "Bio::EnsEMBL::Compara::DnaFrag");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DnaFrag::new(all)", sub {

    my $dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(
                                                  -adaptor => $dnafrag_adaptor,
                                                  -genome_db_id => $genome_db_id,
                                                  -coord_system_name => $coord_system_name,
                                                  -name => $name
                                                 );
    isa_ok($dnafrag, "Bio::EnsEMBL::Compara::DnaFrag");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DnaFrag::getter/setters", sub {
    my $dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(
                                                     -adaptor => $dnafrag_adaptor,
                                                     -genome_db_id => $genome_db_id,
                                                     -coord_system_name => $coord_system_name,
                                                     -name => $name
                                                    );

    ok(test_getter_setter($dnafrag, "dbID", $dbID));
    ok(test_getter_setter($dnafrag, "adaptor", $dnafrag_adaptor));
    ok(test_getter_setter($dnafrag, "length", $length));
    ok(test_getter_setter($dnafrag, "name", $name));
    ok(test_getter_setter($dnafrag, "genome_db", $genome_db));
    ok(test_getter_setter($dnafrag, "genome_db_id", $genome_db_id));
    ok(test_getter_setter($dnafrag, "coord_system_name", $coord_system_name));
    ok(test_getter_setter($dnafrag, "is_reference", $is_reference));

    isa_ok($dnafrag->slice, "Bio::EnsEMBL::Slice");

    my $display_id = $genome_db->taxon_id . "." . $genome_db->dbID. ":". $coord_system_name.":".$name;
    ok(test_getter_setter($dnafrag, "display_id", $display_id));

    done_testing();
};


# Test deprecated methods...
subtest "Test Bio::EnsEMBL::Compara::DnaFrag deprecated methods", sub {
    my $dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(
                                                     -adaptor => $dnafrag_adaptor,
                                                     -genome_db_id => $genome_db_id,
                                                     -coord_system_name => $coord_system_name,
                                                     -name => $name
                                                    );

    my $prev_verbose_level = verbose();
    verbose(0);     #Prevents WARNING messages
    is( test_getter_setter( $dnafrag, "start", 1 ), 1,
        "Testing DEPRECATED Bio::EnsEMBL::Compara::DnaFrag::start method ");
    is( test_getter_setter( $dnafrag, "end", 256 ), 1,
        "Testing DEPRECATED Bio::EnsEMBL::Compara::DnaFrag::end method ");
    verbose($prev_verbose_level);

    done_testing();
};

done_testing();
