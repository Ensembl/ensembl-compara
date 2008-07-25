use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::AlignIO;

#
# Simple example to retrieve the constrained elements from the PECAN 10 way or
# ORTHEUS 23 way alignment
#

my $spp = "Homo sapiens";
my $chr = "6";
my $start = 88408968;
my $end = 88508968;

#example for ensembl 49
#my $version = 49;
#my $alignment_type = "PECAN";

#Species in Pecan 10 way alignment
#my $spp_list = ["human", "mouse", "rat", "dog", "cow", "rhesus", "chimp", "platypus", "opossum", "chicken"];

#example for ensembl 50
my $version = 50;
my $alignment_type = "ORTHEUS";

#Species in EPO 23 way alignment
my $spp_list = ["human","rhesus","chimp","mouse","rat","dog","cow","horse","orangutan","Tupaia belangeri","squirrel","Sorex araneus","bushbaby","rabbit","pika","microbat","Cavia porcellus","tenrec","Erinaceus europaeus","elephant","cat","armadillo","Microcebus murinus"];

Bio::EnsEMBL::Registry->load_registry_from_db(-host =>'ensembldb.ensembl.org', 
					      -user => 'anonymous',
					     -db_version => $version);

# set up an AlignIO to format SimpleAlign output
my $alignIO = Bio::AlignIO->newFh(-interleaved => 0,
                                  -fh => \*STDOUT,
				  -format => 'psi',
                                  -idlength => 20);

#Create slice from $spp, $chr, $start and $end
my $query_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($spp, "core", "Slice");
my $query_slice = $query_slice_adaptor->fetch_by_region("chromosome",$chr, $start, $end);

# Getting the MethodLinkSpeciesSet adaptor: 
my $method_link_species_set_adaptor = Bio::EnsEMBL::Registry->get_adaptor('Multi', 'compara', 'MethodLinkSpeciesSet');

#Get constrained element method_list_species_set
my $ce_mlss = $method_link_species_set_adaptor->fetch_by_method_link_type_registry_aliases("GERP_CONSTRAINED_ELEMENT", $spp_list);

#Get genomic_align_block adaptor
my $gab_adaptor = Bio::EnsEMBL::Registry->get_adaptor('Multi', 'compara', 'GenomicAlignBlock');

#Fetch all genomic_align_blocks (constrained elements)
my $gabs = $gab_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($ce_mlss,$query_slice);

print "Number of constrained elements: " . @$gabs . "\n";

#Print out information
foreach my $gab (@$gabs) {
    print "Constrained element score " . $gab->score . " length " . $gab->length . "\n";
    foreach my $ga (@{$gab->get_all_GenomicAligns}) {
 	print "   " . $ga->dnafrag->genome_db->name . " " . $ga->dnafrag->name . " " . $ga->dnafrag_start . " " . $ga->dnafrag_end . "\n";
    }
    # print out the alignment (Bio::SimpleAlign object) in the requested
    # output format through the Bio::AlignIO handler
    print $alignIO $gab->get_SimpleAlign;
}

