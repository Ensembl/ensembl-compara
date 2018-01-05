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

# patch_90_91_c.sql
#
# Title: Add indexes to the gene_member table for the biotype_group column
#
# Description:
# The gene_member.biotype_group column was not part of any keys, but was used
# in several queries. The extra indexes will hopefully speed them up a bit.

ALTER TABLE gene_member
  ADD KEY biotype_dnafrag_id_start_end (biotype_group,dnafrag_id,dnafrag_start,dnafrag_end),
  ADD KEY genome_db_id_biotype (genome_db_id, biotype_group);

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_90_91_c.sql|gene_member.biotype_group-index');
