-- Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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


CREATE TEMPORARY TABLE tmp_ngenes
SELECT genome_db_id, COUNT(*) FROM gene_member GROUP BY genome_db_id;
CREATE TEMPORARY TABLE tmp_nseq
SELECT genome_db_id, COUNT(*) FROM seq_member GROUP BY genome_db_id;

-- Stats per genome
CREATE TEMPORARY TABLE tmp_stats_per_genome
SELECT
	stn.node_id,
	COUNT(DISTINCT mp.seq_member_id) AS nb_seq,
	SUM(gtn.node_id IS NOT NULL AND gstn.genome_db_id IS NULL) AS nb_genes_in_tree_multi_species,
	SUM(gtn.node_id IS NOT NULL AND gstn.genome_db_id IS NOT NULL) AS nb_genes_in_tree_single_species
FROM
	species_tree_node stn
	JOIN species_tree_root str USING (root_id)
	JOIN gene_member mg USING (genome_db_id)
	JOIN seq_member mp USING (gene_member_id)
	LEFT JOIN (
		gene_tree_node gtn
		JOIN gene_tree_root gtr ON gtn.root_id = gtr.root_id AND clusterset_id = "default"
		JOIN gene_tree_node_attr gtna ON (gtn.root_id = gtna.node_id)
		JOIN species_tree_node gstn ON gstn.node_id = gtna.species_tree_node_id
	) USING (seq_member_id)
WHERE
	label = "default"
GROUP BY
	stn.node_id
;



-- Stats per root node
CREATE TEMPORARY TABLE tmp_stats_per_root
SELECT
	species_tree_node_id,
	COUNT(*) AS nb_trees,
	SUM(gtrt1.value+0) AS tot_nb_genes,
	MIN(gtrt1.value+0) AS min_nb_genes,
	MAX(gtrt1.value+0) AS max_nb_genes,
	AVG(gtrt1.value+0) AS avg_nb_genes,
	AVG(gtrt2.value+0) AS avg_nb_spec,
	MIN(gtrt2.value+0) AS min_nb_spec,
	MAX(gtrt2.value+0) AS max_nb_spec,
	AVG((gtrt1.value+0)/(gtrt2.value+0)) AS avg_nb_genes_per_spec
FROM
	gene_tree_root
	JOIN gene_tree_root_tag gtrt1 USING (root_id)
	JOIN gene_tree_root_tag gtrt2 USING (root_id)
	JOIN gene_tree_node_attr ON node_id = gtrt1.root_id
WHERE
	clusterset_id = "default"
	AND gtrt1.tag = "gene_count"
	AND gtrt2.tag = "spec_count"
GROUP BY
	species_tree_node_id
;

CREATE TEMPORARY TABLE tmp_stats_per_root_with_zero
SELECT
	node_id,
	IFNULL(nb_trees, 0) AS nb_trees,
	IFNULL(tot_nb_genes, 0) AS tot_nb_genes
FROM
	species_tree_node stn
	JOIN species_tree_root str USING (root_id)
	LEFT JOIN tmp_stats_per_root ON species_tree_node_id = node_id
WHERE
	label = "default"
;

-- Stats per internal node
CREATE TEMPORARY TABLE tmp_stats_per_node
SELECT
  species_tree_node_id,
  COUNT(*) AS nb_nodes,
  SUM(node_type="duplication") AS nb_dup_nodes,
  SUM(node_type="gene_split") AS nb_gene_splits,
  SUM(node_type="speciation") AS nb_spec_nodes,
  SUM(node_type="dubious") AS nb_dubious_nodes,
  AVG(duplication_confidence_score) AS avg_dupscore,
  AVG(IF(node_type="duplication",duplication_confidence_score,NULL)) AS avg_dupscore_nondub
FROM
  gene_tree_node_attr
  JOIN gene_tree_node USING (node_id)
  JOIN gene_tree_root USING (root_id)
  JOIN species_tree_node ON species_tree_node.node_id = gene_tree_node_attr.species_tree_node_id
WHERE
  tree_type = 'tree'
  AND clusterset_id = 'default'
GROUP BY species_tree_node_id
;


DELETE FROM species_tree_node_tag WHERE tag IN ('nb_seq', 'nb_genes_in_tree_single_species', 'nb_genes_in_tree_multi_species', 'root_nb_trees', 'root_nb_genes', 'root_avg_gene', 'root_min_gene', 'root_max_gene', 'root_avg_spec', 'root_min_spec', 'root_max_spec', 'root_avg_gene_per_spec', 'nb_nodes', 'nb_dup_nodes', 'nb_gene_splits', 'nb_spec_nodes', 'nb_dubious_nodes', 'avg_dupscore', 'avg_dupscore_nondub');

INSERT INTO species_tree_node_tag SELECT node_id, "nb_seq", nb_seq FROM tmp_stats_per_genome;
INSERT INTO species_tree_node_tag SELECT node_id, "nb_genes_in_tree_single_species", nb_genes_in_tree_single_species FROM tmp_stats_per_genome;
INSERT INTO species_tree_node_tag SELECT node_id, "nb_genes_in_tree_multi_species", nb_genes_in_tree_multi_species FROM tmp_stats_per_genome;

INSERT INTO species_tree_node_tag SELECT node_id, "root_nb_trees", nb_trees FROM tmp_stats_per_root_with_zero;
INSERT INTO species_tree_node_tag SELECT node_id, "root_nb_genes", tot_nb_genes FROM tmp_stats_per_root_with_zero;
INSERT INTO species_tree_node_tag SELECT species_tree_node_id, "root_avg_gene", avg_nb_genes FROM tmp_stats_per_root;
INSERT INTO species_tree_node_tag SELECT species_tree_node_id, "root_min_gene", min_nb_genes FROM tmp_stats_per_root;
INSERT INTO species_tree_node_tag SELECT species_tree_node_id, "root_max_gene", max_nb_genes FROM tmp_stats_per_root;
INSERT INTO species_tree_node_tag SELECT species_tree_node_id, "root_avg_spec", avg_nb_spec FROM tmp_stats_per_root;
INSERT INTO species_tree_node_tag SELECT species_tree_node_id, "root_min_spec", min_nb_spec FROM tmp_stats_per_root;
INSERT INTO species_tree_node_tag SELECT species_tree_node_id, "root_max_spec", max_nb_spec FROM tmp_stats_per_root;
INSERT INTO species_tree_node_tag SELECT species_tree_node_id, "root_avg_gene_per_spec", avg_nb_genes_per_spec FROM tmp_stats_per_root;

INSERT INTO species_tree_node_tag SELECT species_tree_node_id, "nb_nodes", nb_nodes FROM tmp_stats_per_node;
INSERT INTO species_tree_node_tag SELECT species_tree_node_id, "nb_dup_nodes", nb_dup_nodes FROM tmp_stats_per_node;
INSERT INTO species_tree_node_tag SELECT species_tree_node_id, "nb_gene_splits", nb_gene_splits FROM tmp_stats_per_node;
INSERT INTO species_tree_node_tag SELECT species_tree_node_id, "nb_spec_nodes", nb_spec_nodes FROM tmp_stats_per_node;
INSERT INTO species_tree_node_tag SELECT species_tree_node_id, "nb_dubious_nodes", nb_dubious_nodes FROM tmp_stats_per_node;
INSERT INTO species_tree_node_tag SELECT species_tree_node_id, "avg_dupscore", avg_dupscore FROM tmp_stats_per_node WHERE avg_dupscore IS NOT NULL;
INSERT INTO species_tree_node_tag SELECT species_tree_node_id, "avg_dupscore_nondub", avg_dupscore_nondub FROM tmp_stats_per_node WHERE avg_dupscore_nondub IS NOT NULL;

