
/*

	Det of statistics for the protein tree pipeline
	Requires a write access to the database to create
	  temporary tables / keys

*/

/*
	Number of genes, peptides per species, proportion covered by the gene trees
*/

/* 5 min */
CREATE TEMPORARY TABLE tmp_coverage
	SELECT
		member.taxon_id,
		SUM(source_name='ENSEMBLGENE') AS nb_genes,
		SUM(source_name='ENSEMBLPEP') AS nb_pep,
		SUM(protein_tree_attr.taxon_id = member.taxon_id) AS nb_pep_spectree,
		SUM(protein_tree_attr.taxon_id IS NOT NULL AND protein_tree_attr.taxon_id != member.taxon_id) AS nb_pep_anctree
	FROM
		member
		LEFT JOIN protein_tree_member USING (member_id)
		LEFT JOIN protein_tree_node ON (protein_tree_member.root_id = protein_tree_node.node_id) 
		LEFT JOIN protein_tree_attr ON (protein_tree_node.node_id = protein_tree_attr.node_id)
	GROUP BY
		member.taxon_id;
ALTER TABLE tmp_coverage ADD PRIMARY KEY (taxon_id);
OPTIMIZE TABLE tmp_coverage;

SELECT
	genome_db.name,
	nb_pep,
	nb_genes AS nb_can_pep,
	nb_pep_spectree,
	nb_pep_anctree,
	nb_genes-nb_pep_spectree-nb_pep_anctree AS nb_pep_orphan,
	ROUND(100*nb_pep_spectree/nb_genes, 2) AS perc_pep_spectree,
	ROUND(100*nb_pep_anctree/nb_genes, 2) AS perc_pep_anctree,
	ROUND(100*(nb_genes-nb_pep_spectree-nb_pep_anctree)/nb_genes, 2) AS perc_pep_orphan
FROM
	genome_db
	JOIN ncbi_taxa_node USING (taxon_id)
	JOIN tmp_coverage USING (taxon_id)
ORDER BY
	left_index;



/* 15 min */

CREATE TEMPORARY TABLE tmp_root_properties
	SELECT
		protein_tree_attr.node_id,
		protein_tree_attr.taxon_id,
		protein_tree_attr.taxon_name,
		COUNT(member_id) AS nb_prot,
		COUNT(DISTINCT member.taxon_id) AS nb_spec
	FROM
		protein_tree_member
		JOIN member USING (member_id)
		JOIN protein_tree_attr ON protein_tree_attr.node_id=protein_tree_member.root_id
	GROUP BY
		protein_tree_attr.node_id;
ALTER TABLE tmp_root_properties ADD KEY (taxon_id);
OPTIMIZE TABLE tmp_root_properties;

SELECT
	taxon_id,
	taxon_name,
	COUNT(*) AS nb_trees,
	SUM(nb_prot) AS tot_nb_prot,
	ROUND(AVG(nb_prot),2) AS avg_nb_prot,
	MAX(nb_prot) AS max_nb_prot,
	ROUND(AVG(nb_spec),2) AS avg_nb_spec,
	MAX(nb_spec) AS max_nb_spec,
	ROUND(AVG(nb_prot/nb_spec),2) AS avg_nb_prot_per_spec
FROM
	ncbi_taxa_node
	JOIN tmp_root_properties USING (taxon_id)
GROUP BY
	taxon_id
ORDER BY
	left_index;



/*
	Tree properties, grouped by taxon_id
	rel64: 25s
*/

SELECT
	taxon_id,
	taxon_name,
	COUNT(*) AS nb_nodes,
	SUM(node_type="speciation") AS nb_spec_nodes,
	SUM(node_type="duplication") AS nb_dup_nodes,
	SUM(node_type="dubious") AS nb_dubious_nodes,
	SUM(node_type="gene_split") AS nb_gene_splits,
	ROUND(AVG(duplication_confidence_score),2) AS avg_dupscore,
	ROUND(AVG(IF(node_type="duplication",duplication_confidence_score,NULL)),2) AS avg_dupscore_nondub
FROM
	protein_tree_attr
	JOIN ncbi_taxa_node USING (taxon_id)
GROUP BY taxon_id
ORDER BY left_index ;

