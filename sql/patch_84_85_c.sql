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

# patch_84_85_c.sql
#
# Title: Mark some columns as NOT NULL
#
# Description:
#   Some columns must in fact not accept NULL values, but this
#   was not enforced in the schema definition

-- MySQL should 'die' on warnings, ensuring data is not truncated
SET session sql_mode='TRADITIONAL';


ALTER TABLE ncbi_taxa_name
	MODIFY  name                        varchar(255) NOT NULL,
	MODIFY  name_class                  varchar(50) NOT NULL;
 
ALTER TABLE species_set_tag
	MODIFY  value                       mediumtext NOT NULL;
 
ALTER TABLE method_link_species_set_tag
	MODIFY  value                       mediumtext NOT NULL;
 
ALTER TABLE dnafrag
	MODIFY  coord_system_name           varchar(40) DEFAULT '' NOT NULL,
	MODIFY  is_reference                tinyint(1) DEFAULT 1 NOT NULL;
 
ALTER TABLE genomic_align_block
	MODIFY  length                      int(10) NOT NULL;
 
ALTER TABLE genomic_align
	MODIFY  cigar_line                  mediumtext NOT NULL;
 
ALTER TABLE constrained_element
	MODIFY  dnafrag_strand int(2) not null;

ALTER TABLE peptide_align_feature
	MODIFY  evalue                      double not null,
	MODIFY  align_length                int(10) not null,
	MODIFY  identical_matches           int(10) not null,
	MODIFY  perc_ident                  int(10) not null,
	MODIFY  positive_matches            int(10) not null,
	MODIFY  perc_pos                    int(10) not null,
	MODIFY  hit_rank                    int(10) not null;
 

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_84_85_c.sql|not_null');
