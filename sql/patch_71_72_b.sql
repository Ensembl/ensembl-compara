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

-- New table for fast web lookups on members families, trees & homologies
CREATE TABLE `member_production_counts` (
  `stable_id` varchar(128) NOT NULL,
  `families` tinyint(1) unsigned DEFAULT '0',
  `gene_trees` tinyint(1) unsigned DEFAULT '0',
  `gene_gain_loss_trees` tinyint(1) unsigned DEFAULT '0',
  `orthologues` int(10) unsigned DEFAULT '0',
  `paralogues` int(10) unsigned DEFAULT '0',
  KEY `stable_id` (`stable_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/* POPULATE ALL THE MEMBER'S STABLE IDS */
INSERT INTO member_production_counts (stable_id) SELECT stable_id FROM member WHERE source_name = "ENSEMBLGENE";

/* FAMILY COUNTS */
CREATE TEMPORARY TABLE temp_member_family_counts (
       stable_id varchar(128) NOT NULL,
       families INT(10) UNSIGNED DEFAULT 0
);

INSERT INTO temp_member_family_counts(stable_id, families) SELECT stable_id, COUNT(*) FROM family_member JOIN member USING (member_id) GROUP BY member_id;

UPDATE member_production_counts mpc JOIN temp_member_family_counts t USING(stable_id) SET mpc.families = t.families;


/* GENE TREE & GENE GAIN/LOSS TREE COUNTS */
CREATE TEMPORARY TABLE temp_member_tree_counts (
       stable_id varchar(128) NOT NULL,
       default_gene_tree_root INT(10) UNSIGNED
);

INSERT INTO temp_member_tree_counts (stable_id, default_gene_tree_root) SELECT member.stable_id, gene_tree_root.root_id FROM member JOIN gene_tree_node ON(member.canonical_member_id = gene_tree_node.member_id) JOIN gene_tree_root USING(root_id) WHERE member.source_name = 'ENSEMBLGENE' AND clusterset_id = 'default' AND tree_type = 'tree';

UPDATE member_production_counts JOIN temp_member_tree_counts USING(stable_id) SET gene_trees = default_gene_tree_root IS NOT NULL;

UPDATE member_production_counts JOIN temp_member_tree_counts t USING(stable_id) JOIN CAFE_gene_family c ON(t.default_gene_tree_root = c.gene_tree_root_id) SET gene_gain_loss_trees = 1;


/* ORTHOLOGUES COUNTS */
CREATE TEMPORARY TABLE temp_member_orthologues_counts (
       stable_id varchar(128) NOT NULL,
       orthologues INT(10) UNSIGNED DEFAULT 0
);
INSERT INTO temp_member_orthologues_counts(stable_id, orthologues) SELECT stable_id, count(*) FROM member_production_counts JOIN member USING(stable_id) JOIN homology_member USING(member_id) JOIN homology USING(homology_id) WHERE homology.description LIKE '%ortholog%' GROUP BY member_id;

UPDATE member_production_counts mpc JOIN temp_member_orthologues_counts USING(stable_id) SET mpc.orthologues = temp_member_orthologues_counts.orthologues;

/* PARALOGUES COUNTS */
CREATE TEMPORARY TABLE temp_member_paralogues_counts (
       stable_id varchar(128) NOT NULL,
       paralogues INT(10) UNSIGNED DEFAULT 0
);

INSERT INTO temp_member_paralogues_counts(stable_id, paralogues) SELECT stable_id, count(*) FROM member_production_counts JOIN member USING(stable_id) JOIN homology_member USING(member_id) JOIN homology USING(homology_id) WHERE homology.description LIKE '%paralog%' GROUP BY member_id;

UPDATE member_production_counts mpc JOIN temp_member_paralogues_counts USING(stable_id) SET mpc.paralogues = temp_member_paralogues_counts.paralogues;


-- Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_71_72_b.sql|new member_production_counts table');
