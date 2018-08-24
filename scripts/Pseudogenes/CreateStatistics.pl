use warnings;
use strict;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url => 'mysql://ensro@mysql-ens-compara-prod-3.ebi.ac.uk:4523/ggiroussens_pseudogenes_v9');

my $mlss_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor;
my $gdb_adaptor = $compara_dba->get_GenomeDBAdaptor;
my $gdb1 = $gdb_adaptor->fetch_by_dbID(150);
die "Could not fetch genomeDB from registry name Homo sapiens" unless(defined($gdb1));

foreach my $other_species(134, 209, 210, 221, 236, 223, 135, 207, 108)
{
	my $gdb2 = $gdb_adaptor->fetch_by_dbID($other_species);

	unless (defined($gdb2))
	{
		warn("Could not fetch genomeDB from registry name $other_species");
		next;
	}

	my $mlss_id1 = $mlss_adaptor->fetch_by_method_link_type_GenomeDBs("ENSEMBL_ORTHOLOGUES", [$gdb1, $gdb2])->dbID;
	my $mlss_id2 = $mlss_adaptor->fetch_by_method_link_type_GenomeDBs("ENSEMBL_PSEUDOGENES_ORTHOLOGUES", [$gdb1, $gdb2])->dbID;

	my $cmd = "bsub -oo Stats/Homologies/".$gdb2->display_name.".txt mysql-ens-compara-prod-3 ggiroussens_pseudogenes_v9 -qe 'SELECT node_name, homology.description, gm1.stable_id, gm2.stable_id, h1.perc_cov, h1.perc_id, h2.perc_cov, h2.perc_id, 100*h1.perc_id/h1.perc_cov, 100*h2.perc_id/h2.perc_cov, goc_score, wga_coverage FROM homology_member h1 JOIN gene_member gm1 USING (gene_member_id)  JOIN homology_member h2 USING (homology_id) JOIN gene_member gm2 ON h2.gene_member_id = gm2.gene_member_id JOIN homology USING (homology_id) JOIN species_tree_node ON species_tree_node_id = node_id WHERE method_link_species_set_id in (".$mlss_id1."," .$mlss_id2.") AND gm1.genome_db_id = 150 AND gm2.genome_db_id != 150 AND NOT gm2.biotype_group like \"\%pseudogene\%\" ORDER BY species_tree_node.left_index'";
	system($cmd);

}
