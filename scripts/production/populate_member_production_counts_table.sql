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


/* Reset all the counters */
TRUNCATE gene_member_hom_stats;
INSERT INTO gene_member_hom_stats (gene_member_id, collection) SELECT gene_member_id, "default" FROM gene_member;

/******************/
/**** FAMILIES ****/
/******************/
/* FAMILY COUNTS */
SELECT "Creating temporary temp_member_family_counts table" AS "";
CREATE TEMPORARY TABLE temp_member_family_counts (
       gene_member_id int(10) unsigned NOT NULL,
       families INT(10) UNSIGNED DEFAULT 0
);

SELECT "Populating the temporary temp_member_family_counts table" AS "";
INSERT INTO temp_member_family_counts (gene_member_id, families) SELECT gene_member_id, COUNT(DISTINCT family_id) FROM family_member JOIN seq_member USING (seq_member_id) GROUP BY gene_member_id;

SELECT "Populating the families column in gene_member_hom_stats" AS "";
UPDATE gene_member_hom_stats gm JOIN temp_member_family_counts t USING (gene_member_id) SET gm.families = t.families WHERE collection = "default";


/******************/
/**** TREES *******/
/******************/
/* GENE TREE & GENE GAIN/LOSS TREE COUNTS */
SELECT "Creating temporary temp_member_tree_counts table" AS "";
CREATE TEMPORARY TABLE temp_member_tree_counts (
       gene_member_id int(10) unsigned NOT NULL,
       default_gene_tree_root INT(10) UNSIGNED
);

SELECT "Populating the temporary temp_member_tree_counts table" AS "";
INSERT INTO temp_member_tree_counts (gene_member_id, default_gene_tree_root) SELECT gene_member_id, gene_tree_root.root_id FROM seq_member JOIN gene_tree_node USING (seq_member_id) JOIN gene_tree_root USING(root_id) WHERE clusterset_id = 'default' AND tree_type = 'tree';

SELECT "Populating the gene_trees column in gene_member_hom_stats" AS "";
UPDATE gene_member_hom_stats JOIN temp_member_tree_counts USING (gene_member_id) SET gene_trees = default_gene_tree_root IS NOT NULL WHERE collection = "default";

SELECT "Populating the gene_gain_loss_trees column in gene_member_hom_stats" AS "";
UPDATE gene_member_hom_stats JOIN temp_member_tree_counts t USING (gene_member_id) JOIN CAFE_gene_family c ON(t.default_gene_tree_root = c.gene_tree_root_id) SET gene_gain_loss_trees = 1 WHERE collection = "default";


/********************/
/**** HOMOLOGUES ****/
/********************/
/* ORTHOLOGUES COUNTS */
SELECT "Creating temporary temp_member_orthologues_counts table" AS "";
CREATE TEMPORARY TABLE temp_member_orthologues_counts (
       gene_member_id int(10) unsigned NOT NULL,
       orthologues INT(10) UNSIGNED DEFAULT 0
);


SELECT "Populating the temporary temp_member_orthologues_counts table" AS "";
INSERT INTO temp_member_orthologues_counts (gene_member_id, orthologues) SELECT gene_member_id, count(*) FROM homology_member JOIN homology USING(homology_id) WHERE homology.description LIKE '%ortholog%' GROUP BY gene_member_id;

SELECT "Populating the orthologues column in gene_member_hom_stats" AS "";
UPDATE gene_member_hom_stats gm JOIN temp_member_orthologues_counts USING (gene_member_id) SET gm.orthologues = temp_member_orthologues_counts.orthologues WHERE collection = "default";

/* PARALOGUES COUNTS */
SELECT "Creating temporary temp_member_paralogues_counts table" AS "";
CREATE TEMPORARY TABLE temp_member_paralogues_counts (
       gene_member_id int(10) unsigned NOT NULL,
       paralogues INT(10) UNSIGNED DEFAULT 0
);

SELECT "Populating the temporary temp_member_paralogues_counts table" AS "";
INSERT INTO temp_member_paralogues_counts (gene_member_id, paralogues) SELECT gene_member_id, count(*) FROM homology_member JOIN homology USING(homology_id) WHERE homology.description LIKE '%paralog%' GROUP BY gene_member_id;

SELECT "Populating the paralogues column in gene_member_hom_stats" AS "";
UPDATE gene_member_hom_stats gm JOIN temp_member_paralogues_counts USING (gene_member_id) SET gm.paralogues = temp_member_paralogues_counts.paralogues WHERE collection = "default";

/* HOMOEOLOGUES COUNTS */
SELECT "Creating temporary temp_member_homoeologues_counts table" AS "";
CREATE TEMPORARY TABLE temp_member_homoeologues_counts (
       gene_member_id int(10) unsigned NOT NULL,
       homoeologues INT(10) UNSIGNED DEFAULT 0
);


SELECT "Populating the temporary temp_member_homoeologues_counts table" AS "";
INSERT INTO temp_member_homoeologues_counts (gene_member_id, homoeologues) SELECT gene_member_id, count(*) FROM homology_member JOIN homology USING(homology_id) WHERE homology.description LIKE '%homoeolog%' GROUP BY gene_member_id;

SELECT "Populating the homoeologues column in gene_member_hom_stats" AS "";
UPDATE gene_member_hom_stats gm JOIN temp_member_homoeologues_counts USING (gene_member_id) SET gm.homoeologues = temp_member_homoeologues_counts.homoeologues WHERE collection = "default";

