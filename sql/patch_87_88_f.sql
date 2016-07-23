-- Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- Copyright [2016] EMBL-European Bioinformatics Institute
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

# patch_87_88_f.sql
#
# Title: Replace "is_reference" with "assembly_part" in dnafrag
#
# Description:
#   The "is_reference" column does not indicate whether a sequence is a patch
#   or a haplotype. We need this information when we do the special patch alignments


ALTER TABLE dnafrag ADD COLUMN assembly_part enum('primary', 'alt_locus', 'fix_patch', 'novel_patch') NOT NULL DEFAULT 'primary' AFTER coord_system_name;

# Can't tell the correct assembly_part from the name, so we're just guessing here
# LRGs will be classified as "alt_locus"
UPDATE dnafrag SET assembly_part = IF(name LIKE "%patch%", "fix_patch", "alt_locus") WHERE is_reference = 0;

ALTER TABLE dnafrag DROP COLUMN is_reference;

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_87_88_f.sql|dnafrag.assembly_part');

