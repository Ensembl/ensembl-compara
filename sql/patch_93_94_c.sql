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

# patch_93_94_c.sql
#
# Title: Added a display_name columnn in method_link
#
# Description:
#   The columns holds the display name of each method

ALTER TABLE method_link ADD COLUMN display_name varchar(255) DEFAULT '' NOT NULL;

UPDATE method_link SET display_name = "BlastZ" WHERE type = "BLASTZ_NET";
UPDATE method_link SET display_name = "LastZ" WHERE type = "LASTZ_NET";
UPDATE method_link SET display_name = "Translated Blat (no nets)" WHERE type = "TRANSLATED_BLAT";
UPDATE method_link SET display_name = "Translated Blat" WHERE type = "TRANSLATED_BLAT_NET";
UPDATE method_link SET display_name = "EPO" WHERE type = "EPO";
UPDATE method_link SET display_name = "EPO-Low-Coverage" WHERE type = "EPO_LOW_COVERAGE";
UPDATE method_link SET display_name = "Mercator-Pecan" WHERE type = "PECAN";
UPDATE method_link SET display_name = "Ortheus alignment" WHERE type = "ORTHEUS";
UPDATE method_link SET display_name = "Cactus" WHERE type = "CACTUS_HAL";
UPDATE method_link SET display_name = "Cactus (restricted)" WHERE type = "CACTUS_HAL_PW";
UPDATE method_link SET display_name = "Synteny" WHERE type = "SYNTENY";
UPDATE method_link SET display_name = "Families" WHERE type = "FAMILY";
UPDATE method_link SET display_name = "Protein-trees" WHERE type = "PROTEIN_TREES";
UPDATE method_link SET display_name = "ncRNA-trees" WHERE type = "NC_TREES";
UPDATE method_link SET display_name = "Species-tree" WHERE type = "SPECIES_TREE";
UPDATE method_link SET display_name = "Homologues" WHERE type = "ENSEMBL_HOMOLOGUES";
UPDATE method_link SET display_name = "Orthologues" WHERE type = "ENSEMBL_ORTHOLOGUES";
UPDATE method_link SET display_name = "Paralogues" WHERE type = "ENSEMBL_PARALOGUES";
UPDATE method_link SET display_name = "Patch projections" WHERE type = "ENSEMBL_PROJECTIONS";
UPDATE method_link SET display_name = "Gerp Constrained Elements" WHERE type = "GERP_CONSTRAINED_ELEMENT";
UPDATE method_link SET display_name = "Gerp Conservation Scores" WHERE type = "GERP_CONSERVATION_SCORE";
UPDATE method_link SET display_name = "LastZ-path" WHERE type = "LASTZ_PATCH";
UPDATE method_link SET display_name = "Homoeologues" WHERE type = "ENSEMBL_HOMOEOLOGUES";
UPDATE method_link SET display_name = "ATAC Assembly mapping" WHERE type = "ATAC";
UPDATE method_link SET display_name = "Polyploidy-aware self-alignment" WHERE type = "POLYPLOID";

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_93_94_c.sql|method_link_display_name');

