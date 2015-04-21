-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

# patch_73_74_b.sql
#
# Title: Compress the HMM profiles
#
# Description:
#   Change the type of the HMM profile from TEXT to BLOB
#   They are now compressed with zlib to save sapce (~6x smaller)

ALTER TABLE hmm_profile ADD COLUMN compressed_profile MEDIUMBLOB AFTER hc_profile;
UPDATE hmm_profile SET compressed_profile = COMPRESS(hc_profile);
ALTER TABLE hmm_profile DROP COLUMN hc_profile;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_73_74_b.sql|hmm_profile');
