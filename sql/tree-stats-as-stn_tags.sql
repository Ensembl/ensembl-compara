-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016-2018] EMBL-European Bioinformatics Institute
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
	SUM(gene_count) AS tot_nb_genes,
	MIN(gene_count) AS min_nb_genes,
	MAX(gene_count) AS max_nb_genes,
	AVG(gene_count) AS avg_nb_genes,
	AVG(spec_count) AS avg_nb_spec,
	MIN(spec_count) AS min_nb_spec,
	MAX(spec_count) AS max_nb_spec,
	AVG((gene_count)/(spec_count)) AS avg_nb_genes_per_spec
FROM
	gene_tree_root
	JOIN gene_tree_root_attr gtra USING (root_id)
	JOIN gene_tree_node_attr ON node_id = root_id
WHERE
	clusterset_id = "default"
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


#set all columns to NULL
UPDATE species_tree_node_attr SET nb_seq = NULL, nb_genes_in_tree_single_species = NULL, nb_genes_in_tree_multi_species = NULL, 
	root_nb_trees = NULL, root_nb_genes = NULL, root_avg_gene = NULL, root_min_gene = NULL, root_max_gene = NULL, root_avg_spec = NULL, 
	root_min_spec = NULL, root_max_spec = NULL, root_avg_gene_per_spec = NULL, nb_nodes = NULL, nb_dup_nodes = NULL, nb_gene_splits = NULL, 
	nb_spec_nodes = NULL, nb_dubious_nodes = NULL, avg_dupscore = NULL, avg_dupscore_nondub = NULL;

#populate the attr table with the node_id from species_tree_root table because the update syntax we are going to use to update the attr table requires that there be data already present in the table
INSERT IGNORE INTO species_tree_node_attr (node_id) SELECT node_id FROM species_tree_node stn JOIN species_tree_root str USING (root_id)
	WHERE label = "default";

#update species_tree_node_attr with tmp_stats_per_genome
UPDATE species_tree_node_attr sta JOIN tmp_stats_per_genome t
SET sta.nb_seq= t.nb_seq, 
	sta.nb_genes_in_tree_single_species=t.nb_genes_in_tree_single_species,
	sta.nb_genes_in_tree_multi_species= t.nb_genes_in_tree_multi_species 
	WHERE sta.node_id = t.node_id;

#update species_tree_node_attr with tmp_stats_per_root_with_zero
UPDATE species_tree_node_attr sta JOIN tmp_stats_per_root_with_zero t
	SET sta.root_nb_trees= t.nb_trees,
	sta.root_nb_genes= t.tot_nb_genes 
	WHERE sta.node_id = t.node_id;

#update species_tree_node_attr with tmp_stats_per_root
UPDATE species_tree_node_attr sta JOIN tmp_stats_per_root t 
	SET sta.root_avg_gene= t.avg_nb_genes, 
    sta.root_min_gene=t.min_nb_genes,
    sta.root_max_gene=t.max_nb_genes,
    sta.root_avg_spec=t.avg_nb_spec,
    sta.root_min_spec=t.min_nb_spec,
    sta.root_max_spec=t.max_nb_spec,
    sta.root_avg_gene_per_spec=t.avg_nb_genes_per_spec
	WHERE sta.node_id = t.species_tree_node_id;

#update species_tree_node_attr with tmp_stats_per_node
UPDATE species_tree_node_attr sta JOIN tmp_stats_per_node t 
	SET sta.nb_nodes= t.nb_nodes,
	sta.nb_dup_nodes= t.nb_dup_nodes,
	sta.nb_gene_splits= t.nb_gene_splits,
	sta.nb_spec_nodes= t.nb_spec_nodes,
	sta.nb_dubious_nodes= t.nb_dubious_nodes,
	sta.avg_dupscore= t.avg_dupscore,
	sta.avg_dupscore_nondub= t.avg_dupscore_nondub
	WHERE sta.node_id = t.species_tree_node_id;

