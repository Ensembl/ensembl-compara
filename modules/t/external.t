
use Test;
BEGIN { plan tests => 5 }



use lib './t';
use EnsTestDB;
use Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::ExternalFeatureView;

use Bio::AlignIO;

ok 1;

if( ! -e '../../ensembl' ) {
   die "genomic align test requires an ensembl peer directory to locate ensembl schema"
}
    
my $ens_test = EnsTestDB->new();

$ens_test->do_sql_file("t/genomicalign.dump");

my $db = $ens_test->get_DBSQL_Obj;

ok $ens_test;

$genome_db = $db->get_GenomeDBAdaptor->fetch_by_dbID(1);

# sneaky in-memory substitution of the ensembl locator

$loc = $ens_test->ensembl_locator;
$loc =~ s/Compara:://;

$genome_db->locator($loc);


$gadp = Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor->new($db);
        
ok $gadp;



my $ensv = Bio::EnsEMBL::Compara::DBSQL::ExternalFeatureView->new( -species => 'human',
								   -compara => $db);

ok $ensv;


my @feats = $ensv->get_Ensembl_SeqFeatures_contig_list('AC021078.00006','AC021078.00007');

ok (scalar(@feats) == 3)
