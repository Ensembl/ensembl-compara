
use Test;
BEGIN { plan tests => 6 }



use lib './t';
use EnsTestDB;
use Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor;

#use Bio::AlignIO;

ok 1;

    
my $ens_test = EnsTestDB->new();

my $db = $ens_test->get_DBSQL_Obj;

ok $ens_test;

$gadb = $db->get_GenomeDBAdaptor();

ok 2;

$fragadb = $db->get_DnaFragAdaptor();

ok 3;

$gdb = Bio::EnsEMBL::Compara::GenomeDB->new();
$gdb->name('mouse');
$gdb->locator('Bio::EnsEMBL::DBSQL::DBAdaptor/host=localhost;dbname=bollocks');

$id = $gadb->store($gdb);

ok($id,$gdb->dbID);

$dnafrag = Bio::EnsEMBL::Compara::DnaFrag->new();
$dnafrag->name('AC000013.1.13343.1213232');
$dnafrag->genomedb($gdb);

$id = $fragadb->store($dnafrag);

ok($id,$dnafrag->dbID);

