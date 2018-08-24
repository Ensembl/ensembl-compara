use strict;
use warnings;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
my $core_dba_human = new Bio::EnsEMBL::DBSQL::DBAdaptor(-host=>'mysql-ensembl-mirror.ebi.ac.uk', -user=>'ensro', -dbname=>'homo_sapiens_core_92_38', -port=>4240);
my $core_dba_mouse = new Bio::EnsEMBL::DBSQL::DBAdaptor(-host=>'mysql-ensembl-mirror.ebi.ac.uk', -user=>'ensro', -dbname=>'homo_sapiens_core_92_38', -port=>4240);

my $human_gene_adaptor = $core_dba_human->get_GeneAdaptor;
my $mouse_gene_adaptor = $core_dba_mouse->get_GeneAdaptor;

# Gathers the biotype of Uox Gene in Human i.e the unitary psuedogene biotype; ENSG00000240520
# Do the same thing with GuloP gene ENSG00000234770 unitary pseudogene biotype;


my @biotypes = ("IG_J_pseudogene", "IG_V_pseudogene ", "IG_pseudogene", "Mt_tRNA_pseudogene",
"miRNA_pseudogene", "misc_RNA_pseudogene", "processed_pseudogene", "pseudogene", "rRNA_pseudogene",
"scRNA_pseudogene", "snRNA_pseudogene", "snoRNA_pseudogene", "tRNA_pseudogene", "transcribed_processed_pseudogene",
"transcribed_unitary_pseudogene", "transcribed_unprocessed_pseudogene", "unitary_pseudogene", "unprocessed_pseudogene",
"TR_V_pseudogene", "IG_C_pseudogene", "TR_J_pseudogene", "translated_processed_pseudogene", "translated_unprocessed_pseudogene",
"IG_D_pseudogene");

my $human_unitary_pseudogenes;
my $mouse_associated_genes;
my $expected_name;
my $gene_name;
my $bool;
foreach my $this_biotype(@biotypes)
{
	print($this_biotype);
	$human_unitary_pseudogenes = $human_gene_adaptor->fetch_all_by_biotype($this_biotype);

	## print("Database contains ", scalar @$human_unitary_pseudogenes, " $this_biotype for human \n");
	foreach my $this_pseudogene(@$human_unitary_pseudogenes)
	{
		$gene_name = $this_pseudogene->external_name;
		## Is the considered gene a pseudogene ? (Name like *****Pxyz with xyz any sequence of number)
		my $bool = ($gene_name =~ /P([1-9]+|)$/);
		## If the external gene of the name ends with 'P', we remove the P
		if($bool)
		{
			$expected_name = substr($gene_name, 0, rindex($gene_name, 'P'));
		}
		else
		{
			$expected_name = $gene_name;
		}
		$mouse_associated_genes = $mouse_gene_adaptor->fetch_all_by_external_name($expected_name);
		if(!(scalar @$mouse_associated_genes))
		{
			print substr($gene_name, 0, rindex($gene_name, m/[0-9]/));
		}
		if(scalar @$mouse_associated_genes >= 1)
		{
			foreach my $mouse_gene(@$mouse_associated_genes)
			{
				print("($expected_name) ", $mouse_gene->external_name, " ", $mouse_gene -> stable_id, " ", $mouse_gene->biotype, " ");
			}
		}
		print "\n";
	}
}
