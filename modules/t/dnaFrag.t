use strict;
use warnings;
 
use Test::Harness;
use Test;
BEGIN { plan tests => 13 }

use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Utils::Exception qw(verbose);
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Compara::GenomeDB;

my $df = new Bio::EnsEMBL::Compara::DnaFrag;

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $homo_sapiens = Bio::EnsEMBL::Test::MultiTestDB->new("homo_sapiens");
my $mus_musculus = Bio::EnsEMBL::Test::MultiTestDB->new("mus_musculus");
my $rattus_norvegicus = Bio::EnsEMBL::Test::MultiTestDB->new("rattus_norvegicus");

my $compara_db = $multi->get_DBAdaptor( "compara" );
my $gdba = $compara_db->get_GenomeDBAdaptor();

my $hs_gdb = $gdba->fetch_by_name_assembly( "Homo sapiens", 'NCBI34' );
my $mm_gdb = $gdba->fetch_by_name_assembly( "Mus musculus", 'NCBIM32' );
my $rn_gdb = $gdba->fetch_by_name_assembly( "Rattus norvegicus", 'RGSC3.1' );

$hs_gdb->db_adaptor($homo_sapiens->get_DBAdaptor('core'));
$mm_gdb->db_adaptor($mus_musculus->get_DBAdaptor('core'));
$rn_gdb->db_adaptor($rattus_norvegicus->get_DBAdaptor('core'));

##
#####################################################################

my $dnafrag_adaptor = $compara_db->get_DnaFragAdaptor;
my $dummy_db = new Bio::EnsEMBL::Compara::GenomeDB;

ok(!$dnafrag_adaptor, "", "Checking Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor object");
ok(!$dummy_db, "", "Checking Bio::EnsEMBL::Compara::GenomeDB object");
ok( $df );
ok( test_getter_setter( $df, "genome_db", $dummy_db ));
ok( test_getter_setter( $df, "coord_system_name", "dummy" ));
ok( test_getter_setter( $df, "adaptor", $dnafrag_adaptor ));
ok( test_getter_setter( $df, "dbID", 42 ));
ok( test_getter_setter( $df, "name", "dummy_name" ));
ok( test_getter_setter( $df, "length", 156 ));

# Test deprecated methods...
verbose(0);
ok( test_getter_setter( $df, "start", 1 ), 1,
    "Testing DEPRECATED Bio::EnsEMBL::Compara::DnaFrag::start method ");
ok( test_getter_setter( $df, "end", 256 ), 1,
    "Testing DEPRECATED Bio::EnsEMBL::Compara::DnaFrag::end method ");
ok( test_getter_setter( $df, "genomedb", $dummy_db ), 1,
    "Testing DEPRECATED Bio::EnsEMBL::Compara::DnaFrag::genomedb method ");
ok( test_getter_setter( $df, "type", "dummy" ), 1,
    "Testing DEPRECATED Bio::EnsEMBL::Compara::DnaFrag::type method ");

