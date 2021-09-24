CREATE TABLE `meta` (
    `meta_id` int(11) NOT NULL AUTO_INCREMENT,
    `species_id` int(10) unsigned DEFAULT '1',
    `meta_key` varchar(40) NOT NULL,
    `meta_value` text NOT NULL,
    PRIMARY KEY (`meta_id`),
    UNIQUE KEY `species_key_value_idx` (`species_id`, `meta_key`, `meta_value`(255)),
    KEY `species_value_idx` (`species_id`, `meta_value`(255))
);

CREATE TABLE `ncbi_taxa_node` (
    `taxon_id` int(10) unsigned NOT NULL,
    `parent_id` int(10) unsigned NOT NULL,
    `rank` char(32) default '' NOT NULL,
    `genbank_hidden_flag` tinyint(1) default 0 NOT NULL,
    `left_index` int(10) DEFAULT 0 NOT NULL,
    `right_index` int(10) DEFAULT 0 NOT NULL,
    `root_id` int(10) default 1 NOT NULL,
    PRIMARY KEY (`taxon_id`),
    KEY (`parent_id`),
    KEY (`rank`),
    KEY (`left_index`),
    KEY (`right_index`)
);

CREATE TABLE `ncbi_taxa_name` (
    `taxon_id` int(10) unsigned NOT NULL,
    `name` varchar(255) NOT NULL,
    `name_class` varchar(50) NOT NULL,
    FOREIGN KEY (`taxon_id`) REFERENCES `ncbi_taxa_node`(`taxon_id`),
    KEY (`taxon_id`),
    KEY (`name`),
    KEY (`name_class`)
);

CREATE TABLE `genome_db` (
    `genome_db_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `taxon_id` int(10) unsigned DEFAULT NULL,
    `name` varchar(128) DEFAULT '' NOT NULL,
    `assembly` varchar(100) DEFAULT '' NOT NULL,
    `genebuild` varchar(100) DEFAULT '' NOT NULL,
    `has_karyotype`			tinyint(1) NOT NULL DEFAULT 0,
    `is_good_for_alignment` TINYINT(1) NOT NULL DEFAULT 0,
    `genome_component` varchar(5) DEFAULT NULL,
    `strain_name` varchar(100) DEFAULT NULL,
    `display_name` varchar(255) DEFAULT NULL,
    `locator` varchar(400),
    `first_release` smallint,
    `last_release` smallint,
    FOREIGN KEY (`taxon_id`) REFERENCES `ncbi_taxa_node`(`taxon_id`),
    PRIMARY KEY (`genome_db_id`),
    UNIQUE `name` (`name`, `assembly`, `genome_component`)
);

CREATE TABLE `species_set_header` (
    `species_set_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `name` varchar(255) NOT NULL default '',
    `size` int(10) unsigned NOT NULL,
    `first_release` smallint,
    `last_release` smallint,
    PRIMARY KEY (`species_set_id`)
);

CREATE TABLE `species_set` (
    `species_set_id` int(10) unsigned NOT NULL,
    `genome_db_id` int(10) unsigned NOT NULL,
    FOREIGN KEY (`species_set_id`) REFERENCES `species_set_header`(`species_set_id`),
    FOREIGN KEY (`genome_db_id`) REFERENCES `genome_db`(`genome_db_id`),
    PRIMARY KEY (`species_set_id`, `genome_db_id`)
);

CREATE TABLE `species_set_tag` (
    `species_set_id` int(10) unsigned NOT NULL,
    `tag` varchar(50) NOT NULL,
    `value` mediumtext NOT NULL,
    FOREIGN KEY (`species_set_id`) REFERENCES `species_set_header`(`species_set_id`),
    PRIMARY KEY (`species_set_id`, `tag`),
    KEY `tag` (`tag`)
);

CREATE TABLE `method_link` (
    `method_link_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `type` varchar(50) DEFAULT '' NOT NULL,
    `class` varchar(50) DEFAULT '' NOT NULL,
    `display_name` varchar(255) DEFAULT '' NOT NULL,
    PRIMARY KEY (`method_link_id`),
    UNIQUE KEY `type` (`type`)
);

CREATE TABLE `method_link_species_set` (
    `method_link_species_set_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `method_link_id` int(10) unsigned NOT NULL,
    `species_set_id` int(10) unsigned NOT NULL,
    `name` varchar(255) NOT NULL default '',
    `source` varchar(255) NOT NULL default 'ensembl',
    `url` varchar(255) NOT NULL default '',
    `first_release` smallint,
    `last_release` smallint,
    FOREIGN KEY (`method_link_id`) REFERENCES `method_link`(`method_link_id`),
    FOREIGN KEY (`species_set_id`) REFERENCES `species_set_header`(`species_set_id`),
    PRIMARY KEY (`method_link_species_set_id`),
    UNIQUE KEY `method_link_id` (`method_link_id`, `species_set_id`)

);

CREATE TABLE `method_link_species_set_tag` (
    `method_link_species_set_id` int(10) unsigned NOT NULL,
    `tag` varchar(50) NOT NULL,
    `value` mediumtext NOT NULL,
    FOREIGN KEY (`method_link_species_set_id`) REFERENCES `method_link_species_set`(`method_link_species_set_id`),
    PRIMARY KEY (`method_link_species_set_id`, `tag`),
    KEY `tag` (`tag`)
);

CREATE TABLE `method_link_species_set_attr` (
    `method_link_species_set_id` int(10) unsigned NOT NULL,
    `n_goc_0` int,
    `n_goc_25` int,
    `n_goc_50` int,
    `n_goc_75` int,
    `n_goc_100` int,
    `perc_orth_above_goc_thresh` float,
    `goc_quality_threshold` int,
    `wga_quality_threshold` int,
    `perc_orth_above_wga_thresh` float,
    `threshold_on_ds` int,
    FOREIGN KEY (`method_link_species_set_id`) REFERENCES `method_link_species_set`(`method_link_species_set_id`),
    PRIMARY KEY (`method_link_species_set_id`)
);

CREATE TABLE `species_tree_node` (
    `node_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `parent_id` int(10) unsigned,
    `root_id` int(10) unsigned,
    `left_index` int(10) NOT NULL DEFAULT 0,
    `right_index` int(10) NOT NULL DEFAULT 0,
    `distance_to_parent` double DEFAULT '1',
    `taxon_id` int(10) UNSIGNED,
    `genome_db_id` int(10) UNSIGNED,
    `node_name` VARCHAR(255),
    FOREIGN KEY (`taxon_id`) REFERENCES `ncbi_taxa_node`(`taxon_id`),
    FOREIGN KEY (`genome_db_id`) REFERENCES `genome_db`(`genome_db_id`),
    FOREIGN KEY (`parent_id`) REFERENCES `species_tree_node`(`node_id`),
    FOREIGN KEY (`root_id`) REFERENCES `species_tree_node`(`node_id`),
    PRIMARY KEY (`node_id`),
    KEY `parent_id` (`parent_id`),
    KEY `root_id` (`root_id`, `left_index`)
);

CREATE TABLE `species_tree_root` (
    `root_id` int(10) unsigned NOT NULL,
    `method_link_species_set_id` int(10) unsigned NOT NULL,
    `label` VARCHAR(256) NOT NULL DEFAULT 'default',
    FOREIGN KEY (`root_id`) REFERENCES `species_tree_node`(`node_id`),
    FOREIGN KEY (`method_link_species_set_id`) REFERENCES `method_link_species_set`(`method_link_species_set_id`),
    UNIQUE KEY (`method_link_species_set_id`, `label`),
    PRIMARY KEY (`root_id`)
);

CREATE TABLE `species_tree_node_tag` (
    `node_id` int(10) unsigned NOT NULL,
    `tag` varchar(50) NOT NULL,
    `value` mediumtext NOT NULL,
    FOREIGN KEY (`node_id`) REFERENCES `species_tree_node`(`node_id`),
    KEY `node_id_tag` (`node_id`, `tag`),
    KEY `tag` (`tag`)
);

CREATE TABLE `species_tree_node_attr` (
    `node_id` int(10) unsigned NOT NULL,
    `nb_long_genes` int,
    `nb_short_genes` int,
    `avg_dupscore` float,
    `avg_dupscore_nondub` float,
    `nb_dubious_nodes` int,
    `nb_dup_nodes` int,
    `nb_genes` int,
    `nb_genes_in_tree` int,
    `nb_genes_in_tree_multi_species` int,
    `nb_genes_in_tree_single_species` int,
    `nb_nodes` int,
    `nb_orphan_genes` int,
    `nb_seq` int,
    `nb_spec_nodes` int,
    `nb_gene_splits` int,
    `nb_split_genes` int,
    `root_avg_gene` float,
    `root_avg_gene_per_spec` float,
    `root_avg_spec` float,
    `root_max_gene` int,
    `root_max_spec` int,
    `root_min_gene` int,
    `root_min_spec` int,
    `root_nb_genes` int,
    `root_nb_trees` int,
    FOREIGN KEY (`node_id`) REFERENCES `species_tree_node`(`node_id`),
    PRIMARY KEY (`node_id`)
);

CREATE TABLE synteny_region (
    `synteny_region_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `method_link_species_set_id` int(10) unsigned NOT NULL,
    FOREIGN KEY (`method_link_species_set_id`) REFERENCES `method_link_species_set`(`method_link_species_set_id`),
    PRIMARY KEY (`synteny_region_id`),
    KEY (`method_link_species_set_id`)
);

CREATE TABLE `dnafrag` (
    `dnafrag_id` bigint unsigned NOT NULL AUTO_INCREMENT,
    `length` int unsigned DEFAULT 0 NOT NULL,
    `name` varchar(255) DEFAULT '' NOT NULL,
    `genome_db_id` int(10) unsigned NOT NULL,
    `coord_system_name` varchar(40) DEFAULT '' NOT NULL,
    `cellular_component` ENUM('NUC', 'MT', 'PT') DEFAULT 'NUC' NOT NULL,
    `is_reference` tinyint(1) DEFAULT 1 NOT NULL,
    `codon_table_id` tinyint(2) unsigned DEFAULT 1 NOT NULL,
    FOREIGN KEY (`genome_db_id`) REFERENCES `genome_db`(`genome_db_id`),
    PRIMARY KEY (`dnafrag_id`),
    UNIQUE `name` (`genome_db_id`, `name`)
);

CREATE TABLE `dnafrag_region` (
    `synteny_region_id` int(10) unsigned DEFAULT 0 NOT NULL,
    `dnafrag_id` bigint unsigned DEFAULT 0 NOT NULL,
    `dnafrag_start` int(10) unsigned DEFAULT 0 NOT NULL,
    `dnafrag_end` int(10) unsigned DEFAULT 0 NOT NULL,
    `dnafrag_strand` tinyint(4) DEFAULT 0 NOT NULL,
    FOREIGN KEY (`synteny_region_id`) REFERENCES `synteny_region`(`synteny_region_id`),
    FOREIGN KEY (`dnafrag_id`) REFERENCES `dnafrag`(`dnafrag_id`),
    KEY `synteny` (`synteny_region_id`, `dnafrag_id`),
    KEY `synteny_reversed` (`dnafrag_id`, `synteny_region_id`)
);

CREATE TABLE `genomic_align_block` (
    `genomic_align_block_id` bigint unsigned NOT NULL AUTO_INCREMENT,
    `method_link_species_set_id` int(10) unsigned DEFAULT 0 NOT NULL,
    `score` double,
    `perc_id` tinyint(3) unsigned DEFAULT NULL,
    `length` int(10) NOT NULL,
    `group_id` bigint unsigned DEFAULT NULL,
    `level_id` tinyint(2) unsigned DEFAULT 0 NOT NULL,
    `direction` tinyint(1) unsigned DEFAULT NULL,
    FOREIGN KEY (`method_link_species_set_id`) REFERENCES `method_link_species_set`(`method_link_species_set_id`),
    PRIMARY KEY `genomic_align_block_id` (`genomic_align_block_id`),
    KEY `method_link_species_set_id` (`method_link_species_set_id`)
);

CREATE TABLE `genomic_align_tree` (
    `node_id` bigint unsigned NOT NULL AUTO_INCREMENT,
    `parent_id` bigint unsigned DEFAULT NULL,
    `root_id` bigint unsigned NOT NULL default 0,
    `left_index` int(10) NOT NULL default 0,
    `right_index` int(10) NOT NULL default 0,
    `left_node_id` bigint unsigned,
    `right_node_id` bigint unsigned,
    `distance_to_parent` double NOT NULL default 1,
    FOREIGN KEY (`parent_id`) REFERENCES `genomic_align_tree`(`node_id`),
    FOREIGN KEY (`left_node_id`) REFERENCES `genomic_align_tree`(`node_id`),
    FOREIGN KEY (`right_node_id`) REFERENCES `genomic_align_tree`(`node_id`),
    PRIMARY KEY `node_id` (`node_id`),
    KEY `parent_id` (`parent_id`),
    KEY `left_index` (`root_id`, `left_index`)
);

CREATE TABLE `genomic_align` (
    `genomic_align_id` bigint unsigned NOT NULL AUTO_INCREMENT,
    `genomic_align_block_id` bigint unsigned NOT NULL,
    `method_link_species_set_id` int(10) unsigned DEFAULT 0 NOT NULL,
    `dnafrag_id` bigint unsigned DEFAULT 0 NOT NULL,
    `dnafrag_start` int(10) DEFAULT 0 NOT NULL,
    `dnafrag_end` int(10) DEFAULT 0 NOT NULL,
    `dnafrag_strand` tinyint(4) DEFAULT 0 NOT NULL,
    `cigar_line` mediumtext NOT NULL,
    `visible` tinyint(2) unsigned DEFAULT 1 NOT NULL,
    `node_id` bigint unsigned DEFAULT NULL,
    FOREIGN KEY (`genomic_align_block_id`) REFERENCES `genomic_align_block`(`genomic_align_block_id`),
    FOREIGN KEY (`method_link_species_set_id`) REFERENCES `method_link_species_set`(`method_link_species_set_id`),
    FOREIGN KEY (`dnafrag_id`) REFERENCES `dnafrag`(`dnafrag_id`),
    FOREIGN KEY (`node_id`) REFERENCES `genomic_align_tree`(`node_id`),
    PRIMARY KEY `genomic_align_id` (`genomic_align_id`),
    KEY `genomic_align_block_id` (`genomic_align_block_id`),
    KEY `method_link_species_set_id` (`method_link_species_set_id`),
    KEY `dnafrag` (`dnafrag_id`, `method_link_species_set_id`, `dnafrag_start`, `dnafrag_end`),
    KEY `node_id` (`node_id`)
);

CREATE TABLE `conservation_score` (
    `genomic_align_block_id` bigint unsigned not null,
    `window_size` smallint unsigned not null,
    `position` int unsigned not null,
    `expected_score` blob,
    `diff_score` blob,
    FOREIGN KEY (`genomic_align_block_id`) REFERENCES `genomic_align_block`(`genomic_align_block_id`),
    KEY (`genomic_align_block_id`, `window_size`)
);

CREATE TABLE `constrained_element` (
    `constrained_element_id` bigint unsigned NOT NULL,
    `dnafrag_id` bigint unsigned NOT NULL,
    `dnafrag_start` int(12) unsigned NOT NULL,
    `dnafrag_end` int(12) unsigned NOT NULL,
    `dnafrag_strand` int(2) not null,
    `method_link_species_set_id` int(10) unsigned NOT NULL,
    `p_value` double NOT NULL DEFAULT 0,
    `score` double NOT NULL default 0,
    FOREIGN KEY (`dnafrag_id`) REFERENCES `dnafrag`(`dnafrag_id`),
    FOREIGN KEY (`method_link_species_set_id`) REFERENCES `method_link_species_set`(`method_link_species_set_id`),
    KEY `constrained_element_id_idx` (`constrained_element_id`),
    KEY `mlssid_dfId_dfStart_dfEnd_idx` (`method_link_species_set_id`, `dnafrag_id`, `dnafrag_start`, `dnafrag_end`)
);

CREATE TABLE `sequence` (
    `sequence_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `length` int(10) NOT NULL,
    `md5sum` CHAR(32) NOT NULL,
    `sequence` longtext NOT NULL,
    PRIMARY KEY (`sequence_id`),
    KEY `md5sum` (`md5sum`)
);

CREATE TABLE `gene_member` (
    `gene_member_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `stable_id` varchar(128) NOT NULL,
    `version` int(10) DEFAULT 0,
    `source_name` ENUM('ENSEMBLGENE', 'EXTERNALGENE') NOT NULL,
    `taxon_id` int(10) unsigned NOT NULL,
    `genome_db_id` int(10) unsigned,
    `biotype_group` ENUM('coding','pseudogene','snoncoding','lnoncoding','mnoncoding','LRG','undefined','no_group','current_notdumped','notcurrent') NOT NULL DEFAULT 'coding',
    `canonical_member_id` int(10) unsigned,
    `description` text DEFAULT NULL,
    `dnafrag_id` bigint unsigned,
    `dnafrag_start` int(10),
    `dnafrag_end` int(10),
    `dnafrag_strand` tinyint(4),
    `display_label` varchar(128) default NULL,
    FOREIGN KEY (`taxon_id`) REFERENCES `ncbi_taxa_node`(`taxon_id`),
    FOREIGN KEY (`genome_db_id`) REFERENCES `genome_db`(`genome_db_id`),
    FOREIGN KEY (`dnafrag_id`) REFERENCES `dnafrag`(`dnafrag_id`),
    PRIMARY KEY (`gene_member_id`),
    UNIQUE (`stable_id`),
    KEY (`source_name`),
    KEY (`canonical_member_id`),
    KEY `dnafrag_id_start` (`dnafrag_id`, `dnafrag_start`),
    KEY `dnafrag_id_end` (`dnafrag_id`, `dnafrag_end`),
    KEY `biotype_dnafrag_id_start_end` (`biotype_group`, `dnafrag_id`, `dnafrag_start`, `dnafrag_end`),
    KEY `genome_db_id_biotype` (`genome_db_id`, `biotype_group`)
);

CREATE TABLE `gene_member_hom_stats` (
    `gene_member_id` int(10) unsigned NOT NULL,
    `collection` varchar(40) NOT NULL,
    `families` int(10) unsigned NOT NULL default 0,
    `gene_trees` tinyint(1) unsigned NOT NULL default 0,
    `gene_gain_loss_trees` tinyint(1) unsigned NOT NULL default 0,
    `orthologues` int(10) unsigned NOT NULL default 0,
    `paralogues` int(10) unsigned NOT NULL default 0,
    `homoeologues` int(10) unsigned NOT NULL default 0,
    FOREIGN KEY (`gene_member_id`) REFERENCES `gene_member`(`gene_member_id`),
    PRIMARY KEY (`gene_member_id`, `collection`)
);

CREATE TABLE `seq_member` (
    `seq_member_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `stable_id` varchar(128) NOT NULL,
    `version` int(10) DEFAULT 0,
    `source_name` ENUM('ENSEMBLPEP','ENSEMBLTRANS','Uniprot/SPTREMBL','Uniprot/SWISSPROT','EXTERNALPEP','EXTERNALTRANS','EXTERNALCDS') NOT NULL,
    `taxon_id` int(10) unsigned NOT NULL,
    `genome_db_id` int(10) unsigned,
    `sequence_id` int(10) unsigned,
    `gene_member_id` int(10) unsigned,
    `has_transcript_edits` tinyint(1) DEFAULT 0 NOT NULL,
    `has_translation_edits` tinyint(1) DEFAULT 0 NOT NULL,
    `description` text DEFAULT NULL,
    `dnafrag_id` bigint unsigned,
    `dnafrag_start` int(10),
    `dnafrag_end` int(10),
    `dnafrag_strand` tinyint(4),
    `display_label` varchar(128) default NULL,
    FOREIGN KEY (`taxon_id`) REFERENCES `ncbi_taxa_node`(`taxon_id`),
    FOREIGN KEY (`genome_db_id`) REFERENCES `genome_db`(`genome_db_id`),
    FOREIGN KEY (`sequence_id`) REFERENCES `sequence`(`sequence_id`),
    FOREIGN KEY (`gene_member_id`) REFERENCES `gene_member`(`gene_member_id`),
    FOREIGN KEY (`dnafrag_id`) REFERENCES `dnafrag`(`dnafrag_id`),
    PRIMARY KEY (`seq_member_id`),
    UNIQUE (`stable_id`),
    KEY (`source_name`),
    KEY (`sequence_id`),
    KEY (`gene_member_id`),
    KEY `dnafrag_id_start` (`dnafrag_id`, `dnafrag_start`),
    KEY `dnafrag_id_end` (`dnafrag_id`, `dnafrag_end`),
    KEY `seq_member_gene_member_id_end` (`seq_member_id`, `gene_member_id`)
);

CREATE TABLE `exon_boundaries` (
	`gene_member_id` INT(10) UNSIGNED NOT NULL,
	`seq_member_id` INT(10) UNSIGNED NOT NULL,
	`dnafrag_start` INT NOT NULL,
	`dnafrag_end` INT NOT NULL,
	`sequence_length` INT(10) UNSIGNED NOT NULL,
	`left_over` TINYINT(1) DEFAULT 0 NOT NULL,
	FOREIGN KEY (`gene_member_id`) REFERENCES `gene_member`(`gene_member_id`),
	FOREIGN KEY (`seq_member_id`) REFERENCES `seq_member`(`seq_member_id`),
	INDEX (`seq_member_id`),
	INDEX (`gene_member_id`)
);

CREATE TABLE `seq_member_projection_stable_id` (
    `target_seq_member_id` int(10) unsigned NOT NULL,
    `source_stable_id` VARCHAR(128) NOT NULL,
    FOREIGN KEY (`target_seq_member_id`) REFERENCES `seq_member`(`seq_member_id`),
    PRIMARY KEY (`target_seq_member_id`),
    INDEX (`source_stable_id`)
);

CREATE TABLE `seq_member_projection` (
    `source_seq_member_id` int(10) unsigned NOT NULL,
    `target_seq_member_id` int(10) unsigned NOT NULL,
    `identity` float(5,2) DEFAULT NULL,
    FOREIGN KEY (`source_seq_member_id`) REFERENCES `seq_member`(`seq_member_id`),
    FOREIGN KEY (`target_seq_member_id`) REFERENCES `seq_member`(`seq_member_id`),
    PRIMARY KEY (`target_seq_member_id`),
    KEY (`source_seq_member_id`)
);

CREATE TABLE `external_db` (
    `external_db_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `db_name` varchar(100) NOT NULL,
    `db_release` varchar(255) DEFAULT NULL,
    `status` enum('KNOWNXREF','KNOWN','XREF','PRED','ORTH','PSEUDO') NOT NULL,
    `priority` int(11) NOT NULL,
    `db_display_name` varchar(255) DEFAULT NULL,
    `type` enum('ARRAY','ALT_TRANS','ALT_GENE','MISC','LIT','PRIMARY_DB_SYNONYM','ENSEMBL') DEFAULT NULL,
    `secondary_db_name` varchar(255) DEFAULT NULL,
    `secondary_db_table` varchar(255) DEFAULT NULL,
    `description` text,
    PRIMARY KEY (`external_db_id`),
    UNIQUE KEY `db_name_db_release_idx` (`db_name`, `db_release`)
);

CREATE TABLE `member_xref` (
    `gene_member_id` int(10) unsigned NOT NULL,
    `dbprimary_acc` varchar(10) NOT NULL,
    `external_db_id` int(10) unsigned NOT NULL,
    PRIMARY KEY (`gene_member_id`, `dbprimary_acc`, `external_db_id`),
    FOREIGN KEY (`gene_member_id`) REFERENCES `gene_member`(`gene_member_id`),
    FOREIGN KEY (`external_db_id`) REFERENCES `external_db`(`external_db_id`)
);

CREATE TABLE `other_member_sequence` (
    `seq_member_id` int(10) unsigned NOT NULL,
    `seq_type` VARCHAR(40) NOT NULL,
    `length` int(10) NOT NULL,
    `sequence` mediumtext NOT NULL,
    FOREIGN KEY (`seq_member_id`) REFERENCES `seq_member`(`seq_member_id`),
    PRIMARY KEY (`seq_member_id`, `seq_type`)
);

CREATE TABLE `peptide_align_feature` (
    `peptide_align_feature_id` bigint unsigned NOT NULL AUTO_INCREMENT,
    `qmember_id` int(10) unsigned NOT NULL,
    `hmember_id` int(10) unsigned NOT NULL,
    `qgenome_db_id` int(10) unsigned,
    `hgenome_db_id` int(10) unsigned,
    `qstart` int(10) DEFAULT 0 NOT NULL,
    `qend` int(10) DEFAULT 0 NOT NULL,
    `hstart` int unsigned DEFAULT 0 NOT NULL,
    `hend` int unsigned DEFAULT 0 NOT NULL,
    `score` double(16,4) DEFAULT 0.0000 NOT NULL,
    `evalue` double NOT NULL,
    `align_length` int(10) NOT NULL,
    `identical_matches` int(10) NOT NULL,
    `perc_ident` int(10) NOT NULL,
    `positive_matches` int(10) NOT NULL,
    `perc_pos` int(10) NOT NULL,
    `hit_rank` int(10) NOT NULL,
    `cigar_line` mediumtext,
    PRIMARY KEY (`peptide_align_feature_id`)
);

CREATE TABLE `family` (
    `family_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `stable_id` varchar(40) NOT NULL,
    `version` INT UNSIGNED NOT NULL,
    `method_link_species_set_id` int(10) unsigned NOT NULL,
    `description` TEXT,
    `description_score` double,
    FOREIGN KEY (`method_link_species_set_id`) REFERENCES `method_link_species_set`(`method_link_species_set_id`),
    PRIMARY KEY (`family_id`),
    UNIQUE (`stable_id`),
    KEY (`method_link_species_set_id`),
    KEY (`description`(255))
);

CREATE TABLE `family_member` (
    `family_id` int(10) unsigned NOT NULL,
    `seq_member_id` int(10) unsigned NOT NULL,
    `cigar_line` mediumtext,
    FOREIGN KEY (`family_id`) REFERENCES `family`(`family_id`),
    FOREIGN KEY (`seq_member_id`) REFERENCES `seq_member`(`seq_member_id`),
    PRIMARY KEY `family_seq_member_id` (`family_id`, `seq_member_id`),
    KEY (`seq_member_id`)
);

CREATE TABLE `gene_align` (
    `gene_align_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `seq_type` varchar(40),
    `aln_method` varchar(40) NOT NULL DEFAULT '',
    `aln_length` int(10) NOT NULL DEFAULT 0,
    PRIMARY KEY (`gene_align_id`)
);

CREATE TABLE `gene_align_member` (
    `gene_align_id` int(10) unsigned NOT NULL,
    `seq_member_id` int(10) unsigned NOT NULL,
    `cigar_line` mediumtext,
    FOREIGN KEY (`gene_align_id`) REFERENCES `gene_align`(`gene_align_id`),
    FOREIGN KEY (`seq_member_id`) REFERENCES `seq_member`(`seq_member_id`),
    PRIMARY KEY (`gene_align_id`, `seq_member_id`),
    KEY `seq_member_id` (`seq_member_id`)
);

CREATE TABLE `gene_tree_node` (
    `node_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `parent_id` int(10) unsigned,
    `root_id` int(10) unsigned,
    `left_index` int(10) NOT NULL DEFAULT 0,
    `right_index` int(10) NOT NULL DEFAULT 0,
    `distance_to_parent` double default 1.0 NOT NULL,
    `seq_member_id` int(10) unsigned,
    FOREIGN KEY (`root_id`) REFERENCES `gene_tree_node`(`node_id`),
    FOREIGN KEY (`parent_id`) REFERENCES `gene_tree_node`(`node_id`),
    FOREIGN KEY (`seq_member_id`) REFERENCES `seq_member`(`seq_member_id`),
    PRIMARY KEY (`node_id`),
    KEY `parent_id` (`parent_id`),
    KEY `seq_member_id` (`seq_member_id`),
    KEY `root_id_left_index` (`root_id`, `left_index`)
);

CREATE TABLE `gene_tree_root` (
    `root_id` INT(10) UNSIGNED NOT NULL,
    `member_type` ENUM('protein', 'ncrna') NOT NULL,
    `tree_type` ENUM('clusterset', 'supertree', 'tree') NOT NULL,
    `clusterset_id` VARCHAR(20) NOT NULL DEFAULT 'default',
    `method_link_species_set_id` INT(10) UNSIGNED NOT NULL,
    `species_tree_root_id` INT(10) UNSIGNED,
    `gene_align_id` INT(10) UNSIGNED,
    `ref_root_id` INT(10) UNSIGNED,
    `stable_id` VARCHAR(40),
    `version` INT UNSIGNED,
    FOREIGN KEY (`root_id`) REFERENCES `gene_tree_node`(`node_id`),
    FOREIGN KEY (`method_link_species_set_id`) REFERENCES `method_link_species_set`(`method_link_species_set_id`),
    FOREIGN KEY (`gene_align_id`) REFERENCES `gene_align`(`gene_align_id`),
    FOREIGN KEY (`ref_root_id`) REFERENCES `gene_tree_root`(`root_id`),
    FOREIGN KEY (`species_tree_root_id`) REFERENCES `species_tree_root`(`root_id`),
    PRIMARY KEY (`root_id`),
    UNIQUE KEY (`stable_id`),
    KEY `ref_root_id` (`ref_root_id`),
    KEY (`tree_type`)
);

CREATE TABLE `gene_tree_node_tag` (
    `node_id` int(10) unsigned NOT NULL,
    `tag` varchar(50) NOT NULL,
    `value` mediumtext NOT NULL,
    FOREIGN KEY (`node_id`) REFERENCES `gene_tree_node`(`node_id`),
    KEY `node_id_tag` (`node_id`, `tag`),
    KEY `tag` (`tag`)
);

CREATE TABLE `gene_tree_root_tag` (
    `root_id` int(10) unsigned NOT NULL,
    `tag` VARCHAR(255) NOT NULL,
    `value` mediumtext NOT NULL,
    FOREIGN KEY (`root_id`) REFERENCES `gene_tree_root`(`root_id`),
    KEY `root_id_tag` (`root_id`, `tag`),
    KEY `tag` (`tag`)
);

CREATE TABLE `gene_tree_root_attr` (
    `root_id` INT(10) UNSIGNED NOT NULL,
    `aln_after_filter_length` INT(10) UNSIGNED,
    `aln_length` INT(10) UNSIGNED,
    `aln_num_residues` INT(10) UNSIGNED,
    `aln_percent_identity` FLOAT(5),
    `best_fit_model_family` VARCHAR(10),
    `best_fit_model_parameter` VARCHAR(5),
    `gene_count` INT(10) UNSIGNED,
    `k_score` FLOAT(5),
    `k_score_rank` INT(10) UNSIGNED,
    `mcoffee_scores_gene_align_id` INT(10) UNSIGNED,
    `aln_n_removed_columns` INT(10) UNSIGNED,
    `aln_num_of_patterns` INT(10) UNSIGNED,
    `aln_shrinking_factor` FLOAT(2),
    `spec_count` INT(10) UNSIGNED,
    `tree_max_branch` FLOAT,
    `tree_max_length` FLOAT(5),
    `tree_num_dup_nodes` INT(10) UNSIGNED,
    `tree_num_leaves` INT(10) UNSIGNED,
    `tree_num_spec_nodes` INT(10) UNSIGNED,
    `lca_node_id` INT(10) UNSIGNED,
    `taxonomic_coverage` FLOAT(5),
    `ratio_species_genes` FLOAT(5),
    `model_name` VARCHAR(40),
    FOREIGN KEY (`root_id`) REFERENCES `gene_tree_root`(`root_id`),
    FOREIGN KEY (`lca_node_id`) REFERENCES `species_tree_node`(`node_id`),
    FOREIGN KEY (`mcoffee_scores_gene_align_id`) REFERENCES `gene_align`(`gene_align_id`),
    PRIMARY KEY (`root_id`),
    KEY (`lca_node_id`)
);

CREATE TABLE `gene_tree_node_attr` (
    `node_id` INT(10) UNSIGNED NOT NULL,
    `node_type` ENUM('duplication', 'dubious', 'speciation', 'sub-speciation', 'gene_split'),
    `species_tree_node_id` INT(10) UNSIGNED,
    `bootstrap` TINYINT UNSIGNED,
    `duplication_confidence_score` DOUBLE(5,4),
    FOREIGN KEY (`species_tree_node_id`) REFERENCES `species_tree_node`(`node_id`),
    FOREIGN KEY (`node_id`) REFERENCES `gene_tree_node`(`node_id`),
    PRIMARY KEY (`node_id`)
);

CREATE TABLE `gene_member_qc` (
    `gene_member_stable_id` varchar(128) NOT NULL,
    `genome_db_id` int(10) unsigned NOT NULL,
    `seq_member_id` int(10) unsigned,
    `n_species` INT,
    `n_orth` INT,
    `avg_cov` FLOAT,
    `status` varchar(50) NOT NULL,
    FOREIGN KEY (`gene_member_stable_id`) REFERENCES `gene_member`(`stable_id`),
    FOREIGN KEY (`seq_member_id`) REFERENCES `seq_member`(`seq_member_id`),
    FOREIGN KEY (`genome_db_id`) REFERENCES `genome_db`(`genome_db_id`),
    KEY (`gene_member_stable_id`)
);

CREATE TABLE `gene_tree_object_store` (
    `root_id` INT(10) UNSIGNED NOT NULL,
    `data_label` VARCHAR(255) NOT NULL,
    `compressed_data` MEDIUMBLOB NOT NULL,
    FOREIGN KEY (`root_id`) REFERENCES `gene_tree_root`(`root_id`),
    PRIMARY KEY (`root_id`, `data_label`)
);

CREATE TABLE `hmm_profile` (
    `model_id` varchar(40) NOT NULL,
    `name` varchar(40),
    `type` varchar(40) NOT NULL,
    `compressed_profile` mediumblob,
    `consensus` mediumtext,
    PRIMARY KEY (`model_id`, `type`)
);

CREATE TABLE `hmm_annot` (
    `seq_member_id` int(10) unsigned NOT NULL,
    `model_id` varchar(40) DEFAULT NULL,
    `evalue` float,
    FOREIGN KEY (`seq_member_id`) REFERENCES `seq_member` (`seq_member_id`),
    PRIMARY KEY (`seq_member_id`),
    KEY (`model_id`)
);

CREATE TABLE `hmm_curated_annot` (
    `seq_member_stable_id` varchar(40) NOT NULL,
    `model_id` varchar(40) DEFAULT NULL,
    `library_version` varchar(40) NOT NULL,
    `annot_date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `reason` MEDIUMTEXT,
    PRIMARY KEY (`seq_member_stable_id`),
    KEY (`model_id`)
);

CREATE TABLE `homology` (
    `homology_id` bigint unsigned NOT NULL AUTO_INCREMENT,
    `method_link_species_set_id` int(10) unsigned NOT NULL,
    `description` ENUM('ortholog_one2one','ortholog_one2many','ortholog_many2many','within_species_paralog','other_paralog','gene_split','between_species_paralog','alt_allele','homoeolog_one2one','homoeolog_one2many','homoeolog_many2many') NOT NULL,
    `is_tree_compliant` tinyint(1) NOT NULL DEFAULT 0,
    `dn` float(10,5),
    `ds` float(10,5),
    `n` float(10,1),
    `s` float(10,1),
    `lnl` float(10,3),
    `species_tree_node_id` int(10) unsigned,
    `gene_tree_node_id` int(10) unsigned,
    `gene_tree_root_id` int(10) unsigned,
    `goc_score` tinyint unsigned,
    `wga_coverage` DEC(5,2),
    `is_high_confidence` tinyint(1),
    FOREIGN KEY (`method_link_species_set_id`) REFERENCES `method_link_species_set`(`method_link_species_set_id`),
    FOREIGN KEY (`species_tree_node_id`) REFERENCES `species_tree_node`(`node_id`),
    FOREIGN KEY (`gene_tree_node_id`) REFERENCES `gene_tree_node`(`node_id`),
    FOREIGN KEY (`gene_tree_root_id`) REFERENCES `gene_tree_root`(`root_id`),
    PRIMARY KEY (`homology_id`),
    KEY (`method_link_species_set_id`),
    KEY (`species_tree_node_id`),
    KEY (`gene_tree_node_id`),
    KEY (`gene_tree_root_id`)
);

CREATE TABLE `homology_member` (
    `homology_id` bigint unsigned NOT NULL,
    `gene_member_id` int(10) unsigned NOT NULL,
    `seq_member_id` int(10) unsigned,
    `cigar_line` mediumtext,
    `perc_cov` float unsigned default 0,
    `perc_id` float unsigned default 0,
    `perc_pos` float unsigned default 0,
    FOREIGN KEY (`homology_id`) REFERENCES `homology`(`homology_id`),
    FOREIGN KEY (`gene_member_id`) REFERENCES `gene_member`(`gene_member_id`),
    FOREIGN KEY (`seq_member_id`) REFERENCES `seq_member`(`seq_member_id`),

    PRIMARY KEY `homology_member_id` (`homology_id`, `gene_member_id`),
    KEY (`gene_member_id`),
    KEY (`seq_member_id`)
);

CREATE TABLE `mapping_session` (
    `mapping_session_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `type` ENUM('family', 'tree', 'hmm'),
    `when_mapped` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `rel_from` INT UNSIGNED,
    `rel_to` INT UNSIGNED,
    `prefix` CHAR(4) NOT NULL,
    PRIMARY KEY (`mapping_session_id`),
    UNIQUE KEY (`type`, `rel_from`, `rel_to`, `prefix`)
);

CREATE TABLE `stable_id_history` (
    `mapping_session_id` INT UNSIGNED NOT NULL,
    `stable_id_from` VARCHAR(40) NOT NULL DEFAULT '',
    `version_from` INT UNSIGNED NULL DEFAULT NULL,
    `stable_id_to` VARCHAR(40) NOT NULL DEFAULT '',
    `version_to` INT UNSIGNED NULL DEFAULT NULL,
    `contribution` FLOAT,
    FOREIGN KEY (`mapping_session_id`) REFERENCES `mapping_session`(`mapping_session_id`),
    PRIMARY KEY (`mapping_session_id`, `stable_id_from`, `stable_id_to`)
);

CREATE TABLE `CAFE_gene_family` (
    `cafe_gene_family_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `root_id` int(10) unsigned NOT NULL,
    `lca_id` int(10) unsigned NOT NULL,
    `gene_tree_root_id` int(10) unsigned NOT NULL,
    `pvalue_avg` double(5,4) DEFAULT NULL,
    `lambdas` varchar(100) DEFAULT NULL,
    FOREIGN KEY (`root_id`) REFERENCES `species_tree_root`(`root_id`),
    FOREIGN KEY (`lca_id`) REFERENCES `species_tree_node`(`node_id`),
    FOREIGN KEY (`gene_tree_root_id`) REFERENCES `gene_tree_root`(`root_id`),
    PRIMARY KEY (`cafe_gene_family_id`),
    KEY `root_id` (`root_id`),
    KEY `gene_tree_root_id` (`gene_tree_root_id`)
);

CREATE TABLE `CAFE_species_gene` (
    `cafe_gene_family_id` int(10) unsigned NOT NULL,
    `node_id` int(10) unsigned NOT NULL,
    `n_members` int(4) unsigned NOT NULL,
    `pvalue` double(5,4) DEFAULT NULL,
    FOREIGN KEY (`cafe_gene_family_id`) REFERENCES `CAFE_gene_family`(`cafe_gene_family_id`),
    FOREIGN KEY (`node_id`) REFERENCES `species_tree_node`(`node_id`),
    PRIMARY KEY (`cafe_gene_family_id`, `node_id`)
);
