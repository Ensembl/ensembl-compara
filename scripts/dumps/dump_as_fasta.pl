

use Bio::EnsEMBL::Compara::DBAdaptor;


$host = 'ecs1b';
$dbname = 'abel_compara_human_mouse';


$db = Bio::EnsEMBL::Compara::DBAdaptor( -host => $host , -dbname => $dbname , -dbuser => 'ensro');

my @ids = @ARGV;

$ga = $db->get_GenomicAlignAdaptor();

$genomedb = $db->get_GenomeDBAdaptor->fetch_by_species_tag("Homo_sapiens");

@aligns = fetch_by_genomedb_dnafrag_list($genomedb,\@ids);



$alignout = Bio::AlignIO->new( -format => 'fasta',-file => '>-' );

foreach my $align ( @aligns ) { 
    $alignout->write_aln($align);
}


