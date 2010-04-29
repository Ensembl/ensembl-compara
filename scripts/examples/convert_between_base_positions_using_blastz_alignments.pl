use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;

my $alignment_type = "BLASTZ_NET";
my $set_of_species = "Homo sapiens:Pan troglodytes";
my $reference_species = "human";


#Note: ensembl release 54 was the last to use human assembly NCBI36
Bio::EnsEMBL::Registry->load_registry_from_url(
	'mysql://anonymous@ensembldb.ensembl.org:5306/58');

#get the required adaptors
my $method_link_species_set_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
	'Multi', 'compara', 'MethodLinkSpeciesSet');

my $genome_db_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
	'Multi', 'compara', 'GenomeDB');

my $align_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
	'Multi', 'compara', 'AlignSlice');

my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
	$reference_species, 'core', 'Slice');

#get the genome_db objects for human and chimp
my $genome_dbs;
foreach my $this_species (split(":", $set_of_species)) {
	my $genome_db = $genome_db_adaptor->fetch_by_registry_name("$this_species");
	push(@$genome_dbs, $genome_db);
}

#get the method_link_secies_set for human-chimp blastz whole genome alignments
my $method_link_species_set =
	$method_link_species_set_adaptor->fetch_by_method_link_type_GenomeDBs(
	$alignment_type, $genome_dbs);

die "need a file with human SNP positions \"chr:pos\" eg 6:136365469\n" unless ( -f $ARGV[0] );

open(IN, $ARGV[0]) or die;

while(<IN>) {
	chomp;
	my ($seq_region, $snp_pos) = split(":", $_);
	my $query_slice = $slice_adaptor->fetch_by_region(undef, $seq_region, $snp_pos, $snp_pos);

	my $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
		$query_slice, $method_link_species_set);

	my $chimp_slice = $align_slice->get_all_Slices("Pan troglodytes")->[0];

	my ($original_slice, $position) = $chimp_slice->get_original_seq_region_position(1);

	print "human ", join(":", $seq_region, $snp_pos), "\tchimp ", join (":", $original_slice->seq_region_name, $position), "\n";
}
