use Test;
BEGIN { plan tests => 1 }



use lib './t';
use EnsTestDB;
use Bio::EnsEMBL::Compara::Protein;

ok 1;
    
my $ens_test = EnsTestDB->new();
my $db = $ens_test->get_DBSQL_Obj;

my $prot=Bio::EnsEMBL::Compara::Protein->new(-EXTERNAL_ID => 'TEST1',
					     -EXTERNAL_DBNAME => 'testdb',
					     -SEQ_START => 1,
					     -SEQ_END => 100,
					     -STRAND => 1,
					     -SEQ => 'MVKKKVMVVMTTTXXXRSVRRS'
					     );


my $prot2=Bio::EnsEMBL::Compara::Protein->new(-EXTERNAL_ID => 'TEST2',
					     -EXTERNAL_DBNAME => 'testdb',
					     -SEQ_START => 1,
					     -SEQ_END => 100,
					     -STRAND => 1,
					     -SEQ => 'MVKKVMVVMRSVRRS'
					     );

my $prot3=Bio::EnsEMBL::Compara::Protein->new(-EXTERNAL_ID => 'TEST3',
					     -EXTERNAL_DBNAME => 'testdb',
					     -SEQ_START => 1,
					     -SEQ_END => 100,
					     -STRAND => 1,
					     -SEQ => 'SSMVKKVMVVMTTTTRSVRRS'
					     );

my $pad = $db->get_ProteinAdaptor;

foreach my $p ($prot,$prot2,$prot3) {
    $pad->store($p);
}





