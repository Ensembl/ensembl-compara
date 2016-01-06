-- Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

-- This file might need to be edited before importing NCBI taxonomy into ncbi_taxonomy@ens-livemirror:

UPDATE ncbi_taxa_name SET name = 'Xenopus tropicalis'       WHERE taxon_id = 8364   AND name_class = 'scientific name'  AND name = 'Xenopus (Silurana) tropicalis';
UPDATE ncbi_taxa_name SET name = 'Xenopus (Silurana) tropicalis' WHERE taxon_id = 8364 AND name_class = 'synonym'       AND name = 'Xenopus tropicalis';

-- change this internal node name as requested by Dr. Brandon Menzies:

UPDATE ncbi_taxa_name SET name = 'Marsupialia'              WHERE taxon_id = 9263   AND name_class = 'scientific name'  AND name = 'Metatheria';
UPDATE ncbi_taxa_name SET name = 'Metatheria'               WHERE taxon_id = 9263   AND name_class = 'synonym'          AND name = 'Marsupialia';

