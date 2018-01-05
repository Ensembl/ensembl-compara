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

# Table structure for table 'method_link_species_set_tag'
CREATE TABLE method_link_species_set_tag (
  method_link_species_set_id  int(10) unsigned NOT NULL, # FK species_set.species_set_id
  tag                         varchar(50) NOT NULL,
  value                       mediumtext,

  FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),

  UNIQUE KEY tag_mlss_id (method_link_species_set_id,tag)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;

INSERT INTO method_link_species_set_tag(method_link_species_set_id, tag, value)
       SELECT substr(meta_key, 6), 'species_tree', meta_value FROM meta WHERE meta_key like 'tree_%';

#Add level_id to genomic_align_block
ALTER TABLE genomic_align_block 
      ADD COLUMN level_id tinyint(2) unsigned DEFAULT 0 NOT NULL;

#Populate genomic_align_block level_id
UPDATE genomic_align_block gab, genomic_align ga SET gab.level_id = ga.level_id WHERE gab.genomic_align_block_id = ga.genomic_align_block_id;

#Remove level_id from genomic_align
ALTER TABLE genomic_align
      DROP COLUMN level_id;

#Add visible column used for self alignments
#Add node_id
ALTER TABLE genomic_align
      ADD COLUMN visible tinyint(2) unsigned DEFAULT 1 NOT NULL,
      ADD COLUMN node_id bigint(20) unsigned DEFAULT NULL;

ALTER TABLE genomic_align
      ADD KEY node_id(node_id);

#Populate the genomic_align node_id
UPDATE genomic_align ga, genomic_align_group gag SET ga.node_id = gag.node_id WHERE ga.genomic_align_id = gag.genomic_align_id;

#Remove genomic_align_group table
DROP TABLE genomic_align_group;

#Update taxon_id field of genome_db table
ALTER TABLE genome_db 
      MODIFY COLUMN taxon_id int(10) unsigned DEFAULT NULL; # KF taxon.taxon_id

#
#
# Updating the schema version
UPDATE meta SET meta_value = 66 where meta_key = "schema_version";

### CAFE_tables
CREATE TABLE CAFE_tree (
  root_id                      int(10) unsigned NOT NULL AUTO_INCREMENT,
  method_link_species_set_id   int(10) unsigned NOT NULL,
  species_tree                 mediumtext NOT NULL,
  lambdas                      varchar(100) DEFAULT NULL,
  p_value_lim                  double(5,4) DEFAULT NULL,

  PRIMARY KEY (root_id),
  KEY method_link_species_set_id (method_link_species_set_id)
) ENGINE=MyISAM AUTO_INCREMENT=24 DEFAULT CHARSET=latin1;

CREATE TABLE CAFE_tree_node (
  node_id                 int(10) unsigned NOT NULL AUTO_INCREMENT,
  parent_id               int(10) unsigned NOT NULL,
  root_id                 int(10) unsigned NOT NULL,
  left_index              int(10) NOT NULL,
  right_index             int(10) NOT NULL,
  distance_to_parent      double DEFAULT '1',
  PRIMARY KEY (node_id),
  KEY parent_id (parent_id),
  KEY root_id (root_id,left_index),
  KEY root_id_2 (root_id,right_index)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

CREATE TABLE CAFE_tree_attr (
  node_id               int(10) unsigned NOT NULL,
  fam_id                int(10) unsigned NOT NULL,
  taxon_id              int(10) unsigned DEFAULT NULL,
  n_members             int(4) unsigned NOT NULL,
  p_value               double(5,4) DEFAULT NULL,
  avg_pvalue            double(5,4) DEFAULT NULL,
  UNIQUE KEY node_id (node_id,fam_id),
  KEY fam_id (fam_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

## Drop analysis and analysis_description tables
DROP TABLE IF EXISTS analysis;
DROP TABLE IF EXISTS analysis_description;

# New table gene_tree_member replaces protein_tree_member and nc_tree_member
CREATE TABLE `gene_tree_member` (
  node_id         int(10) unsigned NOT NULL,
  member_id       int(10) unsigned NOT NULL,
  cigar_line      mediumtext,
  cigar_start     int(10) DEFAULT NULL,
  cigar_end       int(10) DEFAULT NULL,
  UNIQUE KEY `node_id` (`node_id`),
  KEY `member_id` (`member_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

INSERT INTO gene_tree_member(node_id, member_id, cigar_line, cigar_start, cigar_end)
       SELECT node_id, member_id, cigar_line, cigar_start, cigar_end FROM protein_tree_member;

INSERT INTO gene_tree_member(node_id, member_id, cigar_line, cigar_start, cigar_end)
       SELECT node_id+100000000, member_id, cigar_line, cigar_start, cigar_end FROM nc_tree_member;



# New table gene_tree_root
CREATE TABLE gene_tree_root (
  root_id                       int(10) unsigned NOT NULL,
  tree_type                     enum('proteinclusterset','proteinsupertree','proteintree','ncrnatree','ncrnaclusterset') NOT NULL,
  clusterset_id                 int(10) unsigned DEFAULT NULL,
  method_link_species_set_id    int(10) unsigned DEFAULT NULL,
  stable_id                     varchar(40) DEFAULT NULL,
  version                       int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`root_id`),
  UNIQUE KEY `stable_id` (`stable_id`),
  KEY `method_link_species_set_id` (`method_link_species_set_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;


## Fix the clusterset_id
CREATE TEMPORARY TABLE tmp_map_clusterset_node (node_id INT NOT NULL, clusterset_id INT NOT NULL);
INSERT INTO tmp_map_clusterset_node SELECT node_id, clusterset_id FROM protein_tree_node WHERE root_id = 0;
UPDATE protein_tree_node JOIN tmp_map_clusterset_node USING (clusterset_id) SET protein_tree_node.clusterset_id = tmp_map_clusterset_node.node_id;
UPDATE super_protein_tree_node JOIN tmp_map_clusterset_node USING (clusterset_id) SET super_protein_tree_node.clusterset_id = tmp_map_clusterset_node.node_id;

## Inserts the clusterset nodes
INSERT INTO gene_tree_root(root_id, tree_type, clusterset_id)
	SELECT node_id, 'proteinclusterset', clusterset_id FROM protein_tree_node WHERE (root_id IS NULL) OR (root_id = 0);
INSERT INTO gene_tree_root(root_id, tree_type, clusterset_id)
	SELECT node_id+100000000, 'ncrnaclusterset', clusterset_id+100000000 FROM nc_tree_node WHERE (root_id IS NULL) OR (root_id = 0);

INSERT INTO gene_tree_root(root_id, tree_type, clusterset_id)
       SELECT node_id, 'proteintree', clusterset_id FROM protein_tree_node WHERE node_id = root_id;
INSERT INTO gene_tree_root(root_id, tree_type, clusterset_id)
       SELECT node_id, 'proteinsupertree', clusterset_id FROM super_protein_tree_node WHERE root_id = clusterset_id;

INSERT INTO gene_tree_root(root_id, tree_type, clusterset_id)
       SELECT node_id+100000000, 'ncrnatree', clusterset_id+100000000 FROM nc_tree_node WHERE node_id = root_id;

# method_link_species_set column
UPDATE gene_tree_root JOIN protein_tree_member USING (root_id) SET gene_tree_root.method_link_species_set_id = protein_tree_member.method_link_species_set_id;
UPDATE gene_tree_root JOIN super_protein_tree_member USING (root_id) SET gene_tree_root.method_link_species_set_id = super_protein_tree_member.method_link_species_set_id;
UPDATE gene_tree_root JOIN nc_tree_member ON gene_tree_root.root_id=nc_tree_member.root_id+100000000 SET gene_tree_root.method_link_species_set_id = nc_tree_member.method_link_species_set_id;

# stable_id & version columns
UPDATE gene_tree_root JOIN protein_tree_stable_id ON gene_tree_root.root_id = protein_tree_stable_id.node_id SET gene_tree_root.stable_id = protein_tree_stable_id.stable_id, gene_tree_root.version = protein_tree_stable_id.version;

# New table gene_tree_node
CREATE TABLE gene_tree_node (
  node_id                int(10) unsigned NOT NULL AUTO_INCREMENT,
  parent_id              int(10) unsigned DEFAULT NULL,
  root_id                int(10) unsigned DEFAULT NULL,
  left_index             int(10) NOT NULL,
  right_index            int(10) NOT NULL,
  distance_to_parent     double NOT NULL DEFAULT '1',
  PRIMARY KEY (node_id),
  KEY parent_id (parent_id),
  KEY root_id (root_id,left_index),
  KEY root_id_2 (root_id,right_index)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

INSERT INTO gene_tree_node
       SELECT node_id, parent_id, root_id, left_index, right_index, distance_to_parent FROM protein_tree_node;
INSERT INTO gene_tree_node
       SELECT node_id, clusterset_id, node_id, 0, 0, 0 FROM super_protein_tree_node WHERE root_id = clusterset_id;
INSERT INTO gene_tree_node
       SELECT node_id+100000000, parent_id+100000000, root_id+100000000, left_index, right_index, distance_to_parent FROM nc_tree_node;

## Rebuilds the supertrees
CREATE TABLE tmp_sup AS
	SELECT DISTINCT super_protein_tree_member.root_id AS st, protein_tree_member.root_id AS pt FROM super_protein_tree_member JOIN protein_tree_member USING (member_id)
	UNION SELECT DISTINCT root_id, root_id FROM protein_tree_member;
ALTER TABLE tmp_sup ADD KEY (st, pt);
ALTER TABLE tmp_sup ADD KEY (pt, st);

CREATE TABLE tmp_sup_cnt AS
	SELECT st, COUNT(*) AS cnt FROM tmp_sup GROUP BY st;
ALTER TABLE tmp_sup_cnt ADD KEY (st);

CREATE TABLE tmp_sup_links AS
	SELECT DISTINCT ts1.st AS st1, ts2.st AS st2, tc2.cnt FROM tmp_sup ts1 JOIN tmp_sup ts2 USING (pt) JOIN tmp_sup_cnt tc1 ON ts1.st=tc1.st JOIN tmp_sup_cnt tc2 ON ts2.st=tc2.st WHERE ts1.st!=ts2.st AND tc2.cnt>tc1.cnt ORDER BY st1, tc2.cnt;
ALTER TABLE tmp_sup_links ADD KEY (st1, cnt);

CREATE TABLE tmp_sup_hier AS
	SELECT tt.st1, st2 FROM tmp_sup_links JOIN (SELECT st1, MIN(cnt) AS min_cnt FROM tmp_sup_links GROUP BY st1) tt ON tmp_sup_links.cnt=tt.min_cnt AND tmp_sup_links.st1=tt.st1;

UPDATE gene_tree_node JOIN tmp_sup_hier ON gene_tree_node.node_id=tmp_sup_hier.st1 SET parent_id=st2;

# fix clustersets' root_ids
UPDATE gene_tree_node JOIN gene_tree_root ON gene_tree_node.node_id = gene_tree_root.root_id SET gene_tree_node.root_id = gene_tree_node.node_id, gene_tree_node.parent_id=NULL WHERE tree_type LIKE "%clusterset";

## Inserts the clusterset / supertree tree leaves and updates left_index/right_index

INSERT INTO gene_tree_node
	SELECT NULL, clusterset_id, clusterset_id, root_id, root_id, 0 FROM gene_tree_root WHERE tree_type LIKE "%tree";
UPDATE gene_tree_node gtn1 JOIN gene_tree_node gtn2 ON gtn2.left_index = gtn2.right_index AND gtn2.left_index = gtn1.node_id SET gtn2.parent_id=gtn1.parent_id, gtn2.root_id=gtn1.parent_id, gtn1.parent_id = gtn2.node_id;

CREATE TEMPORARY TABLE tmp_leaves (row_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, node_id INT NOT NULL);
INSERT INTO tmp_leaves (node_id) SELECT node_id FROM gene_tree_node JOIN gene_tree_root USING (root_id) WHERE tree_type LIKE "%clusterset" OR tree_type LIKE "%supertree" ORDER BY root_id, node_id=root_id;

UPDATE gene_tree_node JOIN tmp_leaves USING (node_id) SET left_index=2*row_id, right_index=2*row_id+1;
UPDATE gene_tree_node JOIN (SELECT root_id, MIN(left_index) AS mli FROM gene_tree_node WHERE root_id != node_id GROUP BY root_id) tli ON gene_tree_node.node_id = tli.root_id SET gene_tree_node.left_index=tli.mli-1;
UPDATE gene_tree_node JOIN (SELECT root_id, left_index FROM gene_tree_node JOIN gene_tree_root USING (root_id) WHERE node_id=root_id AND left_index>1) tli USING (root_id ) SET gene_tree_node.left_index=gene_tree_node.left_index-tli.left_index+1, gene_tree_node.right_index=gene_tree_node.right_index-tli.left_index+1;
UPDATE gene_tree_node JOIN gene_tree_root USING (root_id) SET right_index=6 WHERE tree_type LIKE "%super%" AND node_id=root_id AND right_index = 7;

## %tag
CREATE TABLE gene_tree_root_tag (
  root_id      int(10) unsigned NOT NULL,
  tag          varchar(50) NOT NULL,
  value        mediumtext NOT NULL,
  KEY root_id_tag (root_id,tag),
  KEY tag_root_id (tag,root_id),
  KEY root_id (root_id),
  KEY tag (tag)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

INSERT INTO gene_tree_root_tag (root_id, tag, value)
       SELECT node_id, tag, value FROM protein_tree_tag ptg WHERE ptg.tag != 'lost_taxon_id' AND ptg.tag != 'species_intersection_score';
INSERT INTO gene_tree_root_tag (root_id, tag, value)
       SELECT node_id+100000000, tag, value FROM nc_tree_tag ntg WHERE ntg.tag != 'lost_taxon_id' AND ntg.tag != 'species_intersection_score';

CREATE TABLE gene_tree_node_tag (
  node_id    int(10) unsigned NOT NULL,
  tag        varchar(50) NOT NULL,
  value      mediumtext NOT NULL,
  KEY node_id_tag (node_id,tag),
  KEY tag_node_id (tag,node_id),
  KEY node_id (node_id),
  KEY tag (tag)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

INSERT INTO gene_tree_node_tag
       SELECT node_id, tag, value FROM protein_tree_tag ptg WHERE ptg.tag = 'lost_taxon_id' OR ptg.tag = 'species_intersection_score';
INSERT INTO gene_tree_node_tag
       SELECT node_id+100000000, tag, value FROM nc_tree_tag ntg WHERE ntg.tag = 'lost_taxon_id';


## protein_tree_attr and nc_tree_attr
RENAME TABLE protein_tree_attr TO gene_tree_node_attr;
ALTER TABLE gene_tree_node_attr MODIFY COLUMN tree_support set('phyml_nt','nj_ds','phyml_aa','nj_dn','nj_mm','quicktree') DEFAULT NULL;
INSERT INTO gene_tree_node_attr SELECT node_id+100000000, node_type, taxon_id, taxon_name, bootstrap, duplication_confidence_score, NULL FROM nc_tree_attr;

INSERT INTO gene_tree_node_tag (node_id, tag, value)
       SELECT node_id+100000000, 'species_intersection_score', species_intersection_score FROM nc_tree_attr WHERE species_intersection_score IS NOT NULL ;

## homology.ancestor_node_id and homology.tree_node_id can now be linked to gene_tree_node
UPDATE homology SET tree_node_id=tree_node_id+100000000, ancestor_node_id=ancestor_node_id+100000000 WHERE homology_id>=100000000 AND description NOT LIKE "proj%";

## homology table has a new KEY
ALTER TABLE homology ADD KEY ancestor_node_id (ancestor_node_id);

## protein_tree_member_score doesn't have root_id and method_link_species_set_id columns;
ALTER TABLE protein_tree_member_score DROP KEY protein_tree_member_score_ibfk_2;
ALTER TABLE protein_tree_member_score DROP KEY method_link_species_set_id;
ALTER TABLE protein_tree_member_score DROP COLUMN root_id, DROP COLUMN method_link_species_set_id;

# And drop the deprecated tables
DROP TABLE protein_tree_member;
DROP TABLE nc_tree_member;
DROP TABLE protein_tree_stable_id;
DROP TABLE protein_tree_node;
DROP TABLE nc_tree_node;
DROP TABLE nc_tree_attr;
DROP TABLE nc_tree_tag;
DROP TABLE protein_tree_tag;
DROP TABLE protein_tree_qc;
DROP TABLE super_protein_tree_attr;
DROP TABLE super_protein_tree_tag;
DROP TABLE super_protein_tree_member;
DROP TABLE super_protein_tree_node;

DROP TABLE tmp_sup;
DROP TABLE tmp_sup_cnt;
DROP TABLE tmp_sup_links;
DROP TABLE tmp_sup_hier;

