
/*

	Set of statistics for the gene tree pipelines
	Requires a write access to the database to create
	  temporary tables / keys

*/

/*
	Number of genes, peptides per species, proportion covered by the gene trees
	rel65/pt: 7 min
	rel65/nc: 15 sec
*/

CREATE TEMPORARY TABLE tmp_ngenes
	SELECT
		taxon_id,
		SUM(source_name='ENSEMBLGENE') AS nb_genes,
		SUM(source_name='ENSEMBLPEP') AS nb_pep
	FROM
		member
	GROUP BY
		taxon_id
	WITH ROLLUP;
ALTER TABLE tmp_ngenes ADD KEY(taxon_id);
OPTIMIZE TABLE tmp_ngenes;

CREATE TEMPORARY TABLE tmp_ntrees
	SELECT
		member.taxon_id,
		SUM(gene_tree_node_attr.taxon_id = member.taxon_id) AS nb_pep_spectree,
		SUM(gene_tree_node_attr.taxon_id IS NOT NULL AND gene_tree_node_attr.taxon_id != member.taxon_id) AS nb_pep_anctree
	FROM
		member
		JOIN gene_tree_member USING (member_id)
		JOIN gene_tree_node USING (node_id)
		JOIN gene_tree_root USING (root_id)
		JOIN gene_tree_node_attr ON (gene_tree_node.root_id = gene_tree_node_attr.node_id)
	WHERE
		clusterset_id = 'default'
	GROUP BY
		member.taxon_id
	WITH ROLLUP;
ALTER TABLE tmp_ntrees ADD KEY(taxon_id);
OPTIMIZE TABLE tmp_ntrees;

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
	tmp_ngenes
	JOIN tmp_ntrees USING (taxon_id)
	LEFT JOIN ncbi_taxa_name USING (taxon_id)
	LEFT JOIN ncbi_taxa_node USING (taxon_id)
WHERE
	name_class IS NULL
	OR name_class = "scientific name"
ORDER BY
	IF(left_index, left_index, 1e7);



/*
	Tree properties, grouped by root species
	rel65/pt: 20 sec
	rel65/nc: <5 sec
*/

CREATE TEMPORARY TABLE tmp_root_properties
	SELECT
		gene_tree_node_attr.node_id,
		gene_tree_node_attr.taxon_id,
		gene_tree_node_attr.taxon_name,
		COUNT(member_id) AS nb_pep,
		COUNT(DISTINCT member.taxon_id) AS nb_spec
	FROM
		gene_tree_member
		JOIN member USING (member_id)
		JOIN gene_tree_node USING (node_id)
		JOIN gene_tree_root USING (root_id)
		JOIN gene_tree_node_attr ON gene_tree_node_attr.node_id=gene_tree_node.root_id
	WHERE
		clusterset_id = 'default'
	GROUP BY
		gene_tree_node_attr.node_id;
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

CREATE TEMPORARY TABLE tmp_taxa
	(taxon_id INT NOT NULL PRIMARY KEY, taxon_name VARCHAR(255))
	SELECT
		DISTINCT taxon_id, taxon_name
	FROM
		gene_tree_node_attr
	UNION ALL
		SELECT 1e7+1, "Total (ancestral species)"
	UNION ALL
		SELECT 1e7+2, "Total (extant species)"
	UNION ALL
		SELECT 1e7+3, "Total";
OPTIMIZE TABLE tmp_taxa;


CREATE TEMPORARY TABLE tmp_stats
	SELECT
		taxon_id, taxon_name AS ref_taxon_name, node_type, duplication_confidence_score, bootstrap
	FROM
		gene_tree_node_attr
		JOIN gene_tree_node USING (node_id)
		JOIN gene_tree_root USING (root_id)
	WHERE
		tree_type = 'tree'
		AND clusterset_id = 'default';
ALTER TABLE tmp_stats ADD KEY (taxon_id);
OPTIMIZE TABLE tmp_stats;


SELECT
	IF(sort_taxon_id<1e7, sort_taxon_id, '') AS sort_taxon_id,
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
		SELECT
			tmp_taxa.taxon_id AS sort_taxon_id,
			tmp_taxa.taxon_name,
			tmp_stats.*
		FROM
			tmp_taxa
			JOIN tmp_stats ON (
				tmp_taxa.taxon_id = tmp_stats.taxon_id
				OR (tmp_taxa.taxon_id = 1e7+1 AND ref_taxon_name NOT LIKE "% %")
				OR (tmp_taxa.taxon_id = 1e7+2 AND ref_taxon_name LIKE "% %")
				OR (tmp_taxa.taxon_id = 1e7+3)
			)

	) tt
	LEFT JOIN ncbi_taxa_node ON tt.sort_taxon_id = ncbi_taxa_node.taxon_id
GROUP BY
	tt.sort_taxon_id
ORDER BY
	IF(left_index, left_index, tt.sort_taxon_id)
;


