
use Test;
BEGIN { plan tests => 7 }



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

my $abs = Bio::EnsEMBL::Compara::AlignBlockSet->new();
my $ab = Bio::EnsEMBL::Compara::AlignBlock->new();
$ab->align_start(1);
$ab->align_end(10);
$ab->start(101);
$ab->end(110);
$ab->strand(-1);
$ab->dnafrag($dnafrag);

$abs->add_AlignBlock($ab);

$ab = Bio::EnsEMBL::Compara::AlignBlock->new();
$ab->align_start(11);
$ab->align_end(20);
$ab->start(151);
$ab->end(160);
$ab->strand(-1);
$ab->dnafrag($dnafrag);

$abs->add_AlignBlock($ab);

my $aln = Bio::EnsEMBL::Compara::GenomicAlign->new();
$aln->add_AlignBlockSet(1,$abs);

my $gadb = $db->get_GenomicAlignAdaptor();

$id = $gadb->store($aln);

ok ($id,$aln->dbID);




