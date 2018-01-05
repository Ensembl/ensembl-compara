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

# patch_84_85_e.sql
#
# Title: Add a "md5sum" column in the sequence table
#
# Description:
#   The MD5 checksum allows a much more efficient index search
#   through the table

-- MySQL should 'die' on warnings, ensuring data is not truncated
SET session sql_mode='TRADITIONAL';

ALTER TABLE sequence
    ADD COLUMN md5sum CHAR(32) NOT NULL AFTER length,
    DROP INDEX sequence,
    ADD INDEX md5sum (md5sum);

UPDATE sequence SET md5sum = MD5(sequence);

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_84_85_e.sql|md5sum_sequence');
