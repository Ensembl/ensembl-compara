

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::AlignIO;


$host = 'ecs1b';
$dbname = 'abel_compara_human_mouse';


$db = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -host => $host , -dbname => $dbname , -user => 'ensro');

my $id = shift;

$ga = $db->get_GenomicAlignAdaptor();

$genomedb = $db->get_GenomeDBAdaptor->fetch_by_species_tag("Homo_sapiens");

@aligns = $ga->fetch_by_dbID($id);



$alignout = Bio::AlignIO->new( -format => 'fasta',-file => '>-' );

foreach my $align ( @aligns ) { 
    $alignout->write_aln($align);
}


