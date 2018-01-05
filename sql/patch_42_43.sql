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


# Updating the schema version

DELETE FROM meta WHERE meta_key="schema_version";
INSERT INTO meta (meta_key,meta_value) VALUES ("schema_version",43);

# Add class column to the method_link table:

ALTER TABLE method_link add `class` varchar(50) NOT NULL default '';

UPDATE method_link SET class = "GenomicAlignBlock.pairwise_alignment"
  WHERE type in ("BLASTZ_NET", "BLASTZ_NET_TIGHT", "BLASTZ_RECIP_NET",
  "PHUSION_BLASTN", "PHUSION_BLASTN_TIGHT", "TRANSLATED_BLAT",
  "BLASTZ_GROUP", "BLASTZ_GROUP_TIGHT", "BLASTZ_RAW", "BLASTZ_CHAIN");

UPDATE method_link SET class = "GenomicAlignBlock.multiple_alignment"
  WHERE type in ("MLAGAN", "PECAN");

UPDATE method_link SET class = "GenomicAlignBlock.constrained_element"
  WHERE type in ("GERP_CONSTRAINED_ELEMENT");

UPDATE method_link SET class = "SyntenyRegion.synteny"
  WHERE type in ("SYNTENY");

UPDATE method_link SET class = "Homology.homology"
  WHERE type in ("ENSEMBL_ORTHOLOGUES", "ENSEMBL_PARALOGUES",
  "ENSEMBL_HOMOLOGUES");

UPDATE method_link SET class = "Family.family"
  WHERE type in ("FAMILY");

UPDATE method_link SET class = "ProteinTree.protein_tree_node"
  WHERE type in ("PROTEIN_TREES");

UPDATE method_link SET class = "ConservationScore.conservation_score"
  WHERE type in ("GERP_CONSERVATION_SCORE");

# Increase max rows for homology_member
ALTER TABLE homology_member MAX_ROWS = 300000000;
