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

# patch_89_90_b.sql
#
# Title: Allow genomic_align_tree parent_id to store NULL
#
# Description:
# parent_id in genomic_align_tree table will be changed to store NULL values

ALTER TABLE genomic_align_tree MODIFY COLUMN parent_id bigint(20) unsigned DEFAULT NULL;
# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_89_90_b.sql|genomic_align_tree_parent_id_null');
