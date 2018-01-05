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

# Updating the schema version:
UPDATE meta SET meta_value = 58 where meta_key = "schema_version";

# homology.description set of possible values has changed:
ALTER TABLE homology MODIFY description ENUM('ortholog_one2one','apparent_ortholog_one2one','ortholog_one2many','ortholog_many2many','within_species_paralog','other_paralog',
                                             'putative_gene_split','contiguous_gene_split','between_species_paralog','possible_ortholog','UBRH','BRH','MBRH','RHS');

# member table now has a better key:
ALTER TABLE member DROP KEY genome_db_id;
ALTER TABLE member ADD KEY gdb_name_start_end (genome_db_id,chr_name,chr_start,chr_end);

# four tables have been added to support non-coding RNA trees:

CREATE TABLE nc_tree_member LIKE protein_tree_member;

CREATE TABLE nc_tree_node   LIKE protein_tree_node;

CREATE TABLE nc_tree_tag    LIKE protein_tree_tag;

CREATE TABLE nc_profile (
    model_id                    varchar(10) NOT NULL,
    name                        varchar(40),
    type                        varchar(40) DEFAULT 'ncrna' NOT NULL,
    hc_profile                  mediumtext,

    PRIMARY KEY (model_id)
);

# a new key added to peptide_align_feature table:
ALTER TABLE peptide_align_feature ADD KEY hmember_hit (hmember_id, hit_rank)

