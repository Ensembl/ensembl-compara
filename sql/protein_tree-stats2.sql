
/*

	New set of statistics for the protein tree pipeline
	Requires a write access to the database to create
	  temporary tables / keys

*/

CREATE TEMPORARY TABLE tmp_genome_content
  SELECT taxon_id, member_id, node_id, root_id
  FROM
      (SELECT SUBSTRING_INDEX(TRIM(LEADING 'gdb:' FROM description), ' ', 1)+0 AS genome_db_id, subset_id FROM subset WHERE description LIKE "gdb:%translations") ua
    NATURAL JOIN
      subset_member
    NATURAL JOIN
      genome_db
    LEFT JOIN
      protein_tree_member USING (member_id)
;
ALTER TABLE tmp_genome_content ADD PRIMARY KEY (taxon_id, root_id, member_id);
ALTER TABLE tmp_genome_content ADD INDEX (root_id);
OPTIMIZE TABLE tmp_genome_content;


# nb genes / species

SELECT taxon_id, name, nb_genes, nb_pep, nb_canon_pep FROM
    (SELECT taxon_id, name FROM genome_db) ta
  NATURAL JOIN
    (SELECT taxon_id, COUNT(*) AS nb_genes FROM member WHERE source_name="ENSEMBLGENE" GROUP BY taxon_id) tb
  NATURAL JOIN
    (SELECT taxon_id, COUNT(*) AS nb_pep FROM member WHERE source_name="ENSEMBLPEP" GROUP BY taxon_id) tc
  NATURAL JOIN
    (SELECT taxon_id, COUNT(*) AS nb_canon_pep FROM tmp_genome_content GROUP BY taxon_id) td
  NATURAL JOIN ncbi_taxa_node ORDER BY left_index;

CREATE TEMPORARY TABLE tmp_roots
  SELECT protein_tree_node.root_id, IF(rank = "species", 0, 1) AS is_ancestral FROM
    protein_tree_node
  NATURAL JOIN
    (SELECT node_id, value+0 AS taxon_id FROM  protein_tree_tag WHERE tag="taxon_id") ta
  JOIN
    ncbi_taxa_node
  USING (taxon_id)
WHERE protein_tree_node.root_id=node_id;
ALTER TABLE tmp_roots ADD PRIMARY KEY (root_id);
OPTIMIZE TABLE tmp_roots;

# nb genes in trees
SELECT
  taxon_id, name,
  nb_m AS nb_pep, nb_ts AS nb_pep_spectree, nb_ta AS nb_pep_anctree, nb_m-nb_ts-nb_ta AS nb_pep_orphan,
  ROUND(100*nb_ts/nb_m, 2) AS perc_pep_spectree, ROUND(100*nb_ta/nb_m, 2) AS perc_pep_anctree, ROUND(100*(nb_m-nb_ts-nb_ta)/nb_m, 2) AS perc_pep_orphan
FROM
  (SELECT
    taxon_id, COUNT(member_id) AS nb_m, COUNT(node_id) AS nb_n, COUNT(root_id) AS nb_r, COUNT(IF(is_ancestral,node_id,NULL)) AS nb_ta, COUNT(IF(is_ancestral,NULL,node_id)) AS nb_ts
    FROM tmp_genome_content LEFT JOIN tmp_roots USING (root_id)
    GROUP BY taxon_id
  ) ta JOIN genome_db USING (taxon_id) NATURAL JOIN ncbi_taxa_node ORDER BY left_index;




# per tree stats: root_id, taxon_name, nb_genes, nb_species
CREATE TEMPORARY TABLE tmp_stats_trees SELECT root_id, value AS taxon_name, COUNT(member_id) AS nb_genes, COUNT(DISTINCT taxon_id) AS nb_species FROM protein_tree_node JOIN protein_tree_tag USING (node_id) JOIN protein_tree_member USING (root_id) JOIN member USING (member_id) WHERE protein_tree_node.node_id=root_id AND tag LIKE "taxon_name" GROUP BY root_id;

SELECT
  tmp_stats_trees.taxon_name, ptt3.value+0 AS taxon_id, count(*) AS nb_trees,
  SUM(tmp_stats_trees.nb_genes) AS tot_nb_prot, ROUND(AVG(tmp_stats_trees.nb_genes), 2) AS avg_nb_prot, MIN(tmp_stats_trees.nb_genes) AS min_nb_prot, MAX(tmp_stats_trees.nb_genes) AS max_nb_prot,
  SUM(tmp_stats_trees.nb_species) AS tot_nb_spec, ROUND(AVG(tmp_stats_trees.nb_species), 2) AS avg_nb_spec, MIN(tmp_stats_trees.nb_species) AS min_nb_spec, MAX(tmp_stats_trees.nb_species) AS max_nb_spec,
  ROUND(AVG(tmp_stats_trees.nb_genes) / AVG(tmp_stats_trees.nb_species), 2) AS avg_nb_prot_per_spec
FROM
  protein_tree_tag ptt3, ncbi_taxa_node, tmp_stats_trees
WHERE
  ptt3.tag='taxon_id' AND ptt3.value = taxon_id AND tmp_stats_trees.root_id=ptt3.node_id
GROUP BY tmp_stats_trees.taxon_name
ORDER BY left_index
;




# average dupscore

CREATE TEMPORARY TABLE tmp_1a
    SELECT node_id, value+0 AS taxon_id FROM  protein_tree_tag WHERE tag="taxon_id";
ALTER TABLE tmp_1a ADD PRIMARY KEY (node_id);
OPTIMIZE TABLE tmp_1a;

CREATE TEMPORARY TABLE tmp_1c
    SELECT node_id, value AS taxon_name FROM  protein_tree_tag WHERE tag="taxon_name";
ALTER TABLE tmp_1c ADD PRIMARY KEY (node_id);
OPTIMIZE TABLE tmp_1c;

CREATE TEMPORARY TABLE tmp_1b
    SELECT node_id, value+0 AS duplication_confidence_score FROM protein_tree_tag WHERE tag="duplication_confidence_score";
ALTER TABLE tmp_1b ADD PRIMARY KEY (node_id);
OPTIMIZE TABLE tmp_1b;

SELECT taxon_id, taxon_name, COUNT(*) AS nb_nodes, COUNT(*)-COUNT(duplication_confidence_score) AS nb_spec_nodes, COUNT(duplication_confidence_score) AS nb_dup_nodes, COUNT(IF(duplication_confidence_score=0, 1, NULL)) AS nb_dubious_nodes, ROUND(AVG(duplication_confidence_score), 2) AS avg_dupscore, ROUND(AVG(IF(duplication_confidence_score=0, NULL, duplication_confidence_score)), 2) AS avg_dupscore_nondub
FROM tmp_1a LEFT JOIN tmp_1b USING (node_id) NATURAL JOIN tmp_1c NATURAL JOIN ncbi_taxa_node GROUP BY taxon_id ORDER BY left_index;




