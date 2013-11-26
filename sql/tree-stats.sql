-- Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.


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
		genome_db_id,
		SUM(source_name='ENSEMBLGENE') AS nb_genes,
		SUM(source_name='ENSEMBLPEP') AS nb_pep
	FROM
		member
	GROUP BY
		genome_db_id
	WITH ROLLUP;
ALTER TABLE tmp_ngenes ADD KEY(genome_db_id);
OPTIMIZE TABLE tmp_ngenes;

CREATE TEMPORARY TABLE tmp_ntrees
	SELECT
		member.genome_db_id,
		COUNT(species_tree_node.genome_db_id) AS nb_pep_spectree,
		SUM(species_tree_node.genome_db_id IS NULL) AS nb_pep_anctree
	FROM
		member
		JOIN gene_tree_node USING (member_id)
		JOIN gene_tree_root USING (root_id)
		JOIN gene_tree_node_attr ON (gene_tree_node.root_id = gene_tree_node_attr.node_id)
		JOIN species_tree_node ON (species_tree_node.node_id = gene_tree_node_attr.species_tree_node_id)
	WHERE
		clusterset_id = 'default'
	GROUP BY
		member.genome_db_id
	WITH ROLLUP;
ALTER TABLE tmp_ntrees ADD KEY(genome_db_id);
OPTIMIZE TABLE tmp_ntrees;

SELECT
	IFNULL(genome_db_id, "") AS genome_db_id,
	IFNULL(node_name, "Total") AS node_name,
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
	JOIN tmp_ntrees USING (genome_db_id)
	LEFT JOIN species_tree_node USING (genome_db_id)
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
		gene_tree_node_attr.species_tree_node_id,
		COUNT(member_id) AS nb_pep,
		COUNT(DISTINCT member.genome_db_id) AS nb_spec
	FROM
		member
		JOIN gene_tree_node USING (member_id)
		JOIN gene_tree_root USING (root_id)
		JOIN gene_tree_node_attr ON gene_tree_node_attr.node_id=gene_tree_node.root_id
	WHERE
		clusterset_id = 'default'
	GROUP BY
		gene_tree_node_attr.node_id;
ALTER TABLE tmp_root_properties ADD KEY (species_tree_node_id);
OPTIMIZE TABLE tmp_root_properties;

CREATE TEMPORARY TABLE tmp_root_properties_sum
	SELECT
		node_id,
		NULL AS species_tree_node_id,
		nb_pep,
		nb_spec
	FROM
		tmp_root_properties;


SELECT
	IF(species_tree_node_id IS NULL, "", taxon_id) AS taxon_id,
	IFNULL(node_name, "Total") AS node_name,
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
	LEFT JOIN species_tree_node ON species_tree_node.node_id = species_tree_node_id
GROUP BY
	species_tree_node_id
ORDER BY
	IF(left_index, left_index, 1e7)
;



/*
	Tree properties, grouped by taxon_id
	rel65/pt: 10 sec
	rel65/nc: <5 sec
*/

CREATE TEMPORARY TABLE tmp_taxa
	SELECT
		node_id AS species_tree_node_id, node_name
	FROM
		species_tree_node
	UNION ALL
		SELECT 1e9+1, "Total (ancestral species)"
	UNION ALL
		SELECT 1e9+2, "Total (extant species)"
	UNION ALL
		SELECT 1e9+3, "Total";
OPTIMIZE TABLE tmp_taxa;


CREATE TEMPORARY TABLE tmp_stats
	SELECT
		species_tree_node_id, taxon_id, species_tree_node.left_index, genome_db_id, node_type, duplication_confidence_score, bootstrap
	FROM
		gene_tree_node_attr
		JOIN gene_tree_node USING (node_id)
		JOIN gene_tree_root USING (root_id)
		JOIN species_tree_node ON species_tree_node.node_id = gene_tree_node_attr.species_tree_node_id
	WHERE
		tree_type = 'tree'
		AND clusterset_id = 'default';
ALTER TABLE tmp_stats ADD KEY (species_tree_node_id);
OPTIMIZE TABLE tmp_stats;


SELECT
	taxon_id,
	node_name,
	COUNT(*) AS nb_nodes,
	SUM(node_type="speciation") AS nb_spec_nodes,
	SUM(node_type="duplication") AS nb_dup_nodes,
	SUM(node_type="dubious") AS nb_dubious_nodes,
	SUM(node_type="gene_split") AS nb_gene_splits,
	ROUND(AVG(duplication_confidence_score),2) AS avg_dupscore,
	ROUND(AVG(IF(node_type="duplication",duplication_confidence_score,NULL)),2) AS avg_dupscore_nondub
FROM
	tmp_taxa
	JOIN tmp_stats ON (
		tmp_taxa.species_tree_node_id = tmp_stats.species_tree_node_id
		OR (tmp_taxa.species_tree_node_id = 1e9+1 AND genome_db_id IS NULL)
		OR (tmp_taxa.species_tree_node_id = 1e9+2 AND genome_db_id IS NOT NULL)
		OR (tmp_taxa.species_tree_node_id = 1e9+3)
	)
GROUP BY
	tmp_taxa.species_tree_node_id
ORDER BY
	IF(tmp_taxa.species_tree_node_id > 1e9, tmp_taxa.species_tree_node_id, left_index)
;


