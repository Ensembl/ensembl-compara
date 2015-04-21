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

-- Updating the schema version:

UPDATE meta SET meta_value = 53 where meta_key = "schema_version";


--------------------------------------------------------------------------------------
--
-- Table structure for table 'mapping_session'
--
-- overview:
--      A single mapping_session is the event when mapping between two given releases
--      for a particular class type ('family' or 'tree') is loaded.
--      The whole event is thought to happen momentarily at 'when_mapped' (used for sorting in historical order).

CREATE TABLE mapping_session (
    mapping_session_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    type               ENUM('family', 'tree'),
    when_mapped        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    rel_from           INT UNSIGNED,
    rel_to             INT UNSIGNED,
    PRIMARY KEY ( mapping_session_id ),
    UNIQUE KEY  ( type, rel_from, rel_to )
);



--------------------------------------------------------------------------------------
--
-- Table structure for table 'stable_id_history'
--
-- overview:
--      'stable_id_history' table keeps the history of stable_id changes from one release to another.
-- 
--      The primary key 'object' describes a set of members migrating from stable_id_from to stable_id_to.
--      Their volume (related to the 'shared_size' of the new class) is reflected by the fractional 'contribution' field.
-- 
--      Since both stable_ids are listed in the primary key,
--      they are not allowed to be NULLs. We shall treat empty strings as NULLs.
--
--      If stable_id_from is empty, it means these members are newcomers into the new release.
--      If stable_id_to is empty, it means these previously known members are disappearing in the new release.
--      If both neither stable_id_from nor stable_id_to is empty, these members are truly migrating.

CREATE TABLE stable_id_history (
    mapping_session_id INT UNSIGNED NOT NULL,
    stable_id_from     VARCHAR(40) NOT NULL DEFAULT '',
    version_from       INT UNSIGNED NULL DEFAULT NULL,
    stable_id_to       VARCHAR(40) NOT NULL DEFAULT '',
    version_to         INT UNSIGNED NULL DEFAULT NULL,
    contribution       FLOAT,
    PRIMARY KEY ( mapping_session_id, stable_id_from, stable_id_to )
);


--------------------------------------------------------------------------------------
--
-- Table structure for table 'protein_tree_stable_id'
--
-- overview:
--     to allow protein trees have trackable stable_ids.
--
-- semantics:
--    node_id           - node_id of the root of the tree
--    stable_id         - the main part of the stable_id ( follows the pattern: label(5).release_introduced(4).unique_id(10) )
--    version           - numeric version of the stable_id (changes only when members move to/from existing trees)

CREATE TABLE protein_tree_stable_id (
    node_id   INT(10) UNSIGNED NOT NULL,
    stable_id VARCHAR(40)  NOT NULL, # unique stable id, e.g. 'ENSGT'.'0053'.'1234567890'
    version   INT UNSIGNED NOT NULL, # version of the stable_id (changes only when members move to/from existing trees)
    PRIMARY KEY ( node_id ),
    UNIQUE KEY ( stable_id )
);


-- Family stable_ids will now have versions:

ALTER TABLE family ADD COLUMN version INT UNSIGNED;


-- Table structure for table 'constrained_element'

CREATE TABLE constrained_element (
  constrained_element_id bigint(20) unsigned NOT NULL,
  dnafrag_id int(12) unsigned NOT NULL,
  dnafrag_start int(12) unsigned NOT NULL,
  dnafrag_end int(12) unsigned NOT NULL,
  method_link_species_set_id int(10) unsigned NOT NULL,
  p_value mediumtext,
  taxonomic_level mediumtext,
  score double NOT NULL default '0',

  FOREIGN KEY (dnafrag_id) REFERENCES dnafrag(dnafrag_id),
  FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),

  KEY constrained_element_id_idx (constrained_element_id),
  KEY mlssid_idx (method_link_species_set_id),
  KEY mlssid_dfId_dfStart_dfEnd_idx (method_link_species_set_id,dnafrag_id,dnafrag_start,dnafrag_end),
  KEY mlssid_dfId_idx (method_link_species_set_id,dnafrag_id)
) COLLATE=latin1_swedish_ci;

