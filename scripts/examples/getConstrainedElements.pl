use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::AlignIO;
use Data::Dumper;

#
# Simple example to retrieve the constrained elements from the eutherian 
# mammals 33way EPO_LOW_COVERAGE alignment
#

my $spp = "Homo sapiens";
my $chr = "15";
my $start = 76628758; 
my $end = 76635191;

my $version = 58;

Bio::EnsEMBL::Registry->load_registry_from_db(-host =>'ensembldb.ensembl.org',
					      -user => 'anonymous',
					      -db_version => $version);

# set up an AlignIO to format SimpleAlign output
my $alignIO = Bio::AlignIO->newFh(-interleaved => 0,
                                  -fh => \*STDOUT,
				  -format => 'clustalw',
                                  );

#Create slice from $spp, $chr, $start and $end
my $query_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($spp, "core", "Slice");
my $query_slice = $query_slice_adaptor->fetch_by_region("chromosome",$chr, $start, $end);

# Getting the MethodLinkSpeciesSet adaptor: 
my $method_link_species_set_adaptor = Bio::EnsEMBL::Registry->get_adaptor('Multi', 'compara', 'MethodLinkSpeciesSet');

#Get constrained element method_list_species_set
my $ce_mlss =  $method_link_species_set_adaptor->fetch_by_method_link_type_species_set_name("GERP_CONSTRAINED_ELEMENT", "mammals");

my $orig_mlss = $method_link_species_set_adaptor->fetch_by_method_link_type_species_set_name("EPO_LOW_COVERAGE", "mammals");
throw("Unable to find method_link_species_set") if (!defined($orig_mlss));

#Get constrained_element adaptor
my $ce_adaptor = Bio::EnsEMBL::Registry->get_adaptor('Multi', 'compara', 'ConstrainedElement');

#Fetch all constrained elements
my $cons = $ce_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($ce_mlss,$query_slice);

#print Dumper $cons;
print "Number of constrained elements: " . @$cons . "\n";

#Print out information
#Note: where constrained elements occur in overlapping genomic_align_blocks there will be ambiguities
#in aassociating an alignment with the correct constrined_element_id. 
foreach my $ce (@$cons) {
    print "dbID:" . $ce->dbID . " from:" . ($ce->slice->start + $ce->start - 1 ) . " to:" . 
	($ce->slice->start + $ce->end - 1) . " Constrained element score:" . $ce->score . 
	" length:" . ($ce->end - $ce->start)  . " p_value:" . $ce->p_value . " taxonomic_level:" 
	. "\"" .  $ce->taxonomic_level . "\"" . " dnafrag_id:". $ce->reference_dnafrag_id . "\n";
	print $alignIO $ce->get_SimpleAlign($orig_mlss, "uc")->[0];
}

