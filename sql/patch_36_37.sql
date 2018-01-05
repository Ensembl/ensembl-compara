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
INSERT INTO meta (meta_key,meta_value) VALUES ("schema_version",37);

# Renaming the old schema tables

RENAME TABLE synteny_region TO synteny_region_old, dnafrag_region TO dnafrag_region_old;

# Creating the new schema tables

CREATE TABLE synteny_region (
  synteny_region_id           int(10) unsigned NOT NULL auto_increment,
  method_link_species_set_id  int(10) unsigned NOT NULL,

  PRIMARY KEY (synteny_region_id),
  KEY (method_link_species_set_id)
) COLLATE=latin1_swedish_ci;


CREATE TABLE dnafrag_region (
  synteny_region_id           int(10) unsigned DEFAULT '0' NOT NULL,
  dnafrag_id                  int(10) unsigned DEFAULT '0' NOT NULL,
  dnafrag_start               int(10) unsigned DEFAULT '0' NOT NULL,
  dnafrag_end                 int(10) unsigned DEFAULT '0' NOT NULL,
  dnafrag_strand              tinyint(4) DEFAULT '0' NOT NULL,
  
  FOREIGN KEY (dnafrag_id) REFERENCES dnafrag(dnafrag_id),

  UNIQUE unique_synteny (synteny_region_id,dnafrag_id),
  UNIQUE unique_synteny_reversed (dnafrag_id,synteny_region_id)
) COLLATE=latin1_swedish_ci;

# Transferring the data from the old schema tables to the new schema tables

INSERT INTO dnafrag_region SELECT dfr1.*,"1" FROM synteny_region_old sr, dnafrag_region_old dfr1, dnafrag_region_old dfr2 WHERE sr.synteny_region_id=dfr1.synteny_region_id AND sr.synteny_region_id=dfr2.synteny_region_id AND dfr1.dnafrag_id<dfr2.dnafrag_id;

INSERT INTO dnafrag_region SELECT dfr2.*,sr.rel_orientation FROM synteny_region_old sr, dnafrag_region_old dfr1, dnafrag_region_old dfr2 WHERE sr.synteny_region_id=dfr1.synteny_region_id AND sr.synteny_region_id=dfr2.synteny_region_id AND dfr1.dnafrag_id<dfr2.dnafrag_id;

INSERT INTO synteny_region SELECT synteny_region_id,method_link_species_set_id from synteny_region_old;

# Dropping the old schema tables

DROP TABLE synteny_region_old;
DROP TABLE dnafrag_region_old;

