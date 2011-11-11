
/*

	Set of statistics for the protein tree pipeline
	Requires a write access to the database to create
	  temporary tables / keys

*/

/*
	Number of genes, peptides per species, proportion covered by the gene trees
	rel65/pt: 7 min
	rel65/nc: 15 sec
*/

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
		LEFT JOIN protein_tree_attr ON (protein_tree_member.root_id = protein_tree_attr.node_id)
	GROUP BY
		member.taxon_id;
ALTER TABLE tmp_coverage ADD PRIMARY KEY (taxon_id);
OPTIMIZE TABLE tmp_coverage;

CREATE TEMPORARY TABLE tmp_coverage_sum
	SELECT
		NULL AS taxon_id,
		SUM(nb_genes) AS nb_genes,
		SUM(nb_pep) AS nb_pep,
		SUM(nb_pep_spectree) AS nb_pep_spectree,
		SUM(nb_pep_anctree) AS nb_pep_anctree
	FROM
		tmp_coverage;

SELECT
	IF(taxon_id, taxon_id, "") AS taxon_id,
	IF(taxon_id, ncbi_taxa_name.name, "Total") AS taxon_name,
	nb_pep,
	nb_genes AS nb_canon_pep,
	nb_pep_spectree,
	nb_pep_anctree,
	nb_genes-nb_pep_spectree-nb_pep_anctree AS nb_pep_orphan,
	ROUND(100*nb_pep_spectree/nb_genes, 2) AS perc_pep_spectree,
	ROUND(100*nb_pep_anctree/nb_genes, 2) AS perc_pep_anctree,
	ROUND(100*(nb_genes-nb_pep_spectree-nb_pep_anctree)/nb_genes, 2) AS perc_pep_orphan
FROM
	(
		SELECT * FROM tmp_coverage
		UNION ALL
		SELECT * FROM tmp_coverage_sum
	) tt 
	LEFT JOIN ncbi_taxa_name USING (taxon_id)
	LEFT JOIN ncbi_taxa_node USING (taxon_id)
WHERE
	name_class IS NULL
	OR name_class = "scientific name"
ORDER BY
	IF(left_index, left_index, 1e7)
;

/*
	Tree properties, grouped by root species
	rel65/pt: 20 sec
	rel65/nc: <5 sec
*/

CREATE TEMPORARY TABLE tmp_root_properties
	SELECT
		protein_tree_attr.node_id,
		protein_tree_attr.taxon_id,
		protein_tree_attr.taxon_name,
		COUNT(member_id) AS nb_pep,
		COUNT(DISTINCT member.taxon_id) AS nb_spec
	FROM
		protein_tree_member
		JOIN member USING (member_id)
		JOIN protein_tree_attr ON protein_tree_attr.node_id=protein_tree_member.root_id
	GROUP BY
		protein_tree_attr.node_id;
ALTER TABLE tmp_root_properties ADD KEY (taxon_id);
OPTIMIZE TABLE tmp_root_properties;

CREATE TEMPORARY TABLE tmp_root_properties_sum
	SELECT
		node_id,
		NULL AS taxon_id,
		NULL AS taxon_name,
		nb_pep,
		nb_spec
	FROM
		tmp_root_properties;


SELECT
	IF(taxon_id, taxon_id, "") AS taxon_id,
	IF(taxon_id, taxon_name, "Total") AS taxon_name,
	COUNT(*) AS nb_trees,
	SUM(nb_pep) AS tot_nb_pep,
	ROUND(AVG(nb_pep),2) AS avg_nb_pep,
	MAX(nb_pep) AS max_nb_pep,
	ROUND(AVG(nb_spec),2) AS avg_nb_spec,
	MAX(nb_spec) AS max_nb_spec,
	ROUND(AVG(nb_pep/nb_spec),2) AS avg_nb_pep_per_spec
FROM
	(
		SELECT * FROM tmp_root_properties
		UNION ALL
		SELECT * FROM tmp_root_properties_sum
	) tt
	LEFT JOIN ncbi_taxa_node USING (taxon_id)
GROUP BY
	taxon_id
ORDER BY
	IF(left_index, left_index, 1e7)
;



/*
	Tree properties, grouped by taxon_id
	rel65/pt: 10 sec
	rel65/nc: <5 sec
*/

SELECT
	IF(taxon_id<1e7, taxon_id, '') AS taxon_id,
	taxon_name,
	COUNT(*) AS nb_nodes,
	SUM(node_type="speciation") AS nb_spec_nodes,
	SUM(node_type="duplication") AS nb_dup_nodes,
	SUM(node_type="dubious") AS nb_dubious_nodes,
	SUM(node_type="gene_split") AS nb_gene_splits,
	ROUND(AVG(duplication_confidence_score),2) AS avg_dupscore,
	ROUND(AVG(IF(node_type="duplication",duplication_confidence_score,NULL)),2) AS avg_dupscore_nondub
FROM
	( 
	(SELECT taxon_id, taxon_name, node_type, duplication_confidence_score FROM protein_tree_attr)
	UNION ALL
	(SELECT 1e7+1, "Total (ancestral species)", node_type, duplication_confidence_score FROM protein_tree_attr WHERE taxon_name NOT LIKE "% %")
	UNION ALL
	(SELECT 1e7+2, "Total (extant species)", node_type, duplication_confidence_score FROM protein_tree_attr WHERE taxon_name LIKE "% %")
	UNION ALL
	(SELECT 1e7+3, "Total", node_type, duplication_confidence_score FROM protein_tree_attr)
	) tt
	LEFT JOIN ncbi_taxa_node USING (taxon_id)
GROUP BY
	tt.taxon_id
ORDER BY
	IF(left_index, left_index, tt.taxon_id)
;


