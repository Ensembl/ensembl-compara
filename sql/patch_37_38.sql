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
INSERT INTO meta (meta_key,meta_value) VALUES ("schema_version",38);

# Renaming the old method_link_species_set table

ALTER TABLE method_link_species_set RENAME old_method_link_species_set;


## Creating new tables

CREATE TABLE `species_set` (
  species_set_id              int(10) unsigned NOT NULL auto_increment,
  genome_db_id                int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (species_set_id,genome_db_id)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

CREATE TABLE method_link_species_set (
  method_link_species_set_id  int(10) unsigned NOT NULL AUTO_INCREMENT, # unique internal id
  method_link_id              int(10) unsigned, # FK method_link.method_link_id
  species_set_id              int(10) unsigned NOT NULL default '0',
  name                        varchar(255) NOT NULL default '',
  source                      varchar(255) NOT NULL default 'ensembl',
  url                         varchar(255) NOT NULL default '',

  PRIMARY KEY (method_link_species_set_id),
  UNIQUE KEY method_link_id (method_link_id,species_set_id)
) COLLATE=latin1_swedish_ci;


## Populating new tables

INSERT IGNORE INTO method_link_species_set SELECT method_link_species_set_id, method_link_id, method_link_species_set_id, "", "ensembl", "" FROM old_method_link_species_set;

INSERT INTO species_set select method_link_species_set_id, genome_db_id FROM old_method_link_species_set;


## Getting unique species_set_id for each set of species

CREATE TABLE tmp_species_set select species_set_id, group_concat(genome_db_id order by genome_db_id) as gdbs FROM species_set GROUP BY species_set_id;

CREATE TABLE new_species_set_ids select gdbs, species_set_id FROM tmp_species_set GROUP BY gdbs ORDER BY species_set_id;

UPDATE method_link_species_set, tmp_species_set, new_species_set_ids SET method_link_species_set.species_set_id = new_species_set_ids.species_set_id WHERE method_link_species_set.species_set_id = tmp_species_set.species_set_id and tmp_species_set.gdbs = new_species_set_ids.gdbs;

CREATE TABLE rm_species_set select species_set.species_set_id FROM species_set LEFT JOIN new_species_set_ids USING (species_set_id) WHERE new_species_set_ids.species_set_id IS NULL;

DELETE species_set from species_set, rm_species_set WHERE species_set.species_set_id = rm_species_set.species_set_id;

DROP TABLE new_species_set_ids;

DROP TABLE tmp_species_set;

DROP TABLE rm_species_set;


## Populate name column for the new table

CREATE TABLE new_name SELECT
  method_link_species_set_id,
  concat(group_concat(
    concat(
      substr(genome_db.name, 1, 1),
      ".",
      substr(substring_index(genome_db.name, " ", -1),1,3))
      SEPARATOR "-"
    ), " translated-blat") AS new_name
  FROM method_link_species_set LEFT JOIN species_set using (species_set_id) LEFT JOIN genome_db using (genome_db_id), method_link
  WHERE method_link_species_set.method_link_id = method_link.method_link_id AND method_link.type = "TRANSLATED_BLAT"
  GROUP BY method_link_species_set_id;

UPDATE method_link_species_set, new_name SET method_link_species_set.name = new_name WHERE method_link_species_set.method_link_species_set_id = new_name.method_link_species_set_id;

DROP TABLE new_name;

CREATE TABLE new_name SELECT
  method_link_species_set_id,
  concat(group_concat(
    concat(
      substr(genome_db.name, 1, 1),
      ".",
      substr(substring_index(genome_db.name, " ", -1),1,3))
      SEPARATOR "-"
    ), " blastz-net (on M.mus)") AS new_name
  FROM method_link_species_set LEFT JOIN species_set using (species_set_id) LEFT JOIN genome_db using (genome_db_id), method_link
  WHERE method_link_species_set.method_link_id = method_link.method_link_id AND method_link.type = "BLASTZ_NET"
  GROUP BY method_link_species_set_id HAVING group_concat(genome_db.name) LIKE "%Mus musculus%";

UPDATE method_link_species_set, new_name SET method_link_species_set.name = new_name WHERE method_link_species_set.method_link_species_set_id = new_name.method_link_species_set_id;

DROP TABLE new_name;

CREATE TABLE new_name SELECT
  method_link_species_set_id,
  concat(group_concat(
    concat(
      substr(genome_db.name, 1, 1),
      ".",
      substr(substring_index(genome_db.name, " ", -1),1,3))
      SEPARATOR "-"
    ), " blastz-net (on H.sap)") AS new_name
  FROM method_link_species_set LEFT JOIN species_set using (species_set_id) LEFT JOIN genome_db using (genome_db_id), method_link
  WHERE method_link_species_set.method_link_id = method_link.method_link_id AND method_link.type = "BLASTZ_NET"
  GROUP BY method_link_species_set_id HAVING group_concat(genome_db.name) LIKE "%Homo sapiens%";

UPDATE method_link_species_set, new_name SET method_link_species_set.name = new_name WHERE method_link_species_set.method_link_species_set_id = new_name.method_link_species_set_id;

DROP TABLE new_name;

CREATE TABLE new_name SELECT
  method_link_species_set_id,
  concat(count(*), " species MLAGAN") AS new_name
  FROM method_link_species_set LEFT JOIN species_set using (species_set_id) LEFT JOIN genome_db using (genome_db_id), method_link
  WHERE method_link_species_set.method_link_id = method_link.method_link_id AND method_link.type = "MLAGAN"
  GROUP BY method_link_species_set_id;

UPDATE method_link_species_set, new_name SET method_link_species_set.name = new_name WHERE method_link_species_set.method_link_species_set_id = new_name.method_link_species_set_id;

DROP TABLE new_name;

CREATE TABLE new_name SELECT
  method_link_species_set_id,
  concat(group_concat(
    concat(
      substr(genome_db.name, 1, 1),
      ".",
      substr(substring_index(genome_db.name, " ", -1),1,3))
      SEPARATOR "-"
    ), " synteny") AS new_name
  FROM method_link_species_set LEFT JOIN species_set using (species_set_id) LEFT JOIN genome_db using (genome_db_id), method_link
  WHERE method_link_species_set.method_link_id = method_link.method_link_id AND method_link.type = "SYNTENY"
  GROUP BY method_link_species_set_id;

UPDATE method_link_species_set, new_name SET method_link_species_set.name = new_name WHERE method_link_species_set.method_link_species_set_id = new_name.method_link_species_set_id;

DROP TABLE new_name;

CREATE TABLE new_name SELECT
  method_link_species_set_id,
  concat(group_concat(
    concat(
      substr(genome_db.name, 1, 1),
      ".",
      substr(substring_index(genome_db.name, " ", -1),1,3))
      SEPARATOR "-"
    ), " orthologues") AS new_name
  FROM method_link_species_set LEFT JOIN species_set using (species_set_id) LEFT JOIN genome_db using (genome_db_id), method_link
  WHERE method_link_species_set.method_link_id = method_link.method_link_id AND method_link.type = "ENSEMBL_ORTHOLOGUES"
  GROUP BY method_link_species_set_id;

UPDATE method_link_species_set, new_name SET method_link_species_set.name = new_name WHERE method_link_species_set.method_link_species_set_id = new_name.method_link_species_set_id;

DROP TABLE new_name;

CREATE TABLE new_name SELECT
  method_link_species_set_id,
  concat(group_concat(
    concat(
      substr(genome_db.name, 1, 1),
      ".",
      substr(substring_index(genome_db.name, " ", -1),1,3))
      SEPARATOR "-"
    ), " paralogues") AS new_name
  FROM method_link_species_set LEFT JOIN species_set using (species_set_id) LEFT JOIN genome_db using (genome_db_id), method_link
  WHERE method_link_species_set.method_link_id = method_link.method_link_id AND method_link.type = "ENSEMBL_PARALOGUES"
  GROUP BY method_link_species_set_id;

UPDATE method_link_species_set, new_name SET method_link_species_set.name = new_name WHERE method_link_species_set.method_link_species_set_id = new_name.method_link_species_set_id;

DROP TABLE new_name;

UPDATE method_link_species_set, method_link SET method_link_species_set.name = "families" WHERE method_link_species_set.method_link_id = method_link.method_link_id and method_link.type = "FAMILY";

## Deleting old method_link_species_set table

DROP TABLE old_method_link_species_set;

#
# Table structure for tables 'ncbi_taxa_nodes' and 'ncbi_taxa_names' that replace the 'taxon' table
#
# Contains all taxa used in this database, which mirror the data and tree structure
# from NCBI Taxonomy database (for more details see ensembl-compara/script/taxonomy/README-taxonomy
# which explain our import process)
# The patch will only load the taxonomy information for the Ensembl species present in GenomeDB table,
# not all the ones coming from member table where a siginficative number of entry come from Uniprot.
# If you want a complete taxonomy data refer to README-taxonomy document.
#

CREATE TABLE ncbi_taxa_nodes (
  taxon_id                        int(10) unsigned NOT NULL,
  parent_id                       int(10) unsigned NOT NULL,

  rank                            char(32) default '' NOT NULL,
  genbank_hidden_flag             boolean default 0 NOT NULL,

  left_index                      int(10) NOT NULL,
  right_index                     int(10) NOT NULL,
  root_id                         int(10) default 1 NOT NULL,
  
  KEY (taxon_id),
  KEY (parent_id),
  KEY (rank)
) COLLATE=latin1_swedish_ci;

CREATE TABLE ncbi_taxa_names (
  taxon_id                    int(10) unsigned NOT NULL,

  name                        varchar(255),
  name_class                  varchar(50),

  KEY (taxon_id),
  KEY (name),
  KEY (name_class)
) COLLATE=latin1_swedish_ci;

INSERT INTO ncbi_taxa_nodes VALUES (43746, 43741, 'superfamily', 0, 402501, 404030, 1);
INSERT INTO ncbi_taxa_names VALUES (43746, 'Ephydroidea', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (31028, 31022, 'suborder', 1, 297168, 297339, 1);
INSERT INTO ncbi_taxa_names VALUES (31028, 'Tetraodontoidei', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (6243, 55879, 'family', 0, 467253, 467454, 1);
INSERT INTO ncbi_taxa_names VALUES (6243, 'Rhabditidae', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (43738, 43733, 'no rank', 1, 400783, 405488, 1);
INSERT INTO ncbi_taxa_names VALUES (43738, 'Schizophora', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (32351, 32346, 'species subgroup', 1, 402922, 402941, 1);
INSERT INTO ncbi_taxa_names VALUES (32351, 'melanogaster subgroup', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (123369, 123368, 'no rank', 1, 296712, 311001, 1);
INSERT INTO ncbi_taxa_names VALUES (123369, 'Euacanthomorpha', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (8492, 32561, 'no rank', 0, 322941, 337920, 1);
INSERT INTO ncbi_taxa_names VALUES (8492, 'Archosauria', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (197562, 197563, 'no rank', 1, 354913, 435754, 1);
INSERT INTO ncbi_taxa_names VALUES (197562, 'Pancrustacea', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (186627, 186626, 'no rank', 1, 291101, 293968, 1);
INSERT INTO ncbi_taxa_names VALUES (186627, 'Cypriniphysi', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (10066, 337687, 'family', 0, 314323, 315186, 1);
INSERT INTO ncbi_taxa_names VALUES (10066, 'Muridae', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (6236, 119089, 'order', 0, 466899, 468404, 1);
INSERT INTO ncbi_taxa_names VALUES (6236, 'Rhabditida', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (38605, 9263, 'order', 0, 322124, 322265, 1);
INSERT INTO ncbi_taxa_names VALUES (38605, 'Didelphimorphia', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (55879, 6236, 'superfamily', 0, 467156, 467455, 1);
INSERT INTO ncbi_taxa_names VALUES (55879, 'Rhabditoidea', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (7227, 32351, 'species', 1, 402931, 402932, 1);
INSERT INTO ncbi_taxa_names VALUES (7227, 'Drosophila melangaster', 'misspelling');
INSERT INTO ncbi_taxa_names VALUES (7227, 'Drosophila melanogaster', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (7227, 'fruit fly', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (9607, 33554, 'suborder', 0, 318886, 319679, 1);
INSERT INTO ncbi_taxa_names VALUES (9607, 'Fissipedia', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (4932, 4930, 'species', 1, 499076, 499083, 1);
INSERT INTO ncbi_taxa_names VALUES (4932, 'Candida robusta', 'anamorph');
INSERT INTO ncbi_taxa_names VALUES (4932, 'Saccaromyces cerevisiae', 'misspelling');
INSERT INTO ncbi_taxa_names VALUES (4932, 'Saccharomyces capensis', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (4932, 'Saccharomyces cerevisiae', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (4932, 'Saccharomyces italicus', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (4932, 'Saccharomyces oviformis', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (4932, 'Saccharomyces uvarum var. melibiosus', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (4932, 'Saccharomyes cerevisiae', 'misspelling');
INSERT INTO ncbi_taxa_names VALUES (4932, 'Sccharomyces cerevisiae', 'misspelling');
INSERT INTO ncbi_taxa_names VALUES (4932, 'baker\'s yeast', 'genbank common name');
INSERT INTO ncbi_taxa_names VALUES (4932, 'brewer\'s yeast', 'common name');
INSERT INTO ncbi_taxa_names VALUES (4932, 'lager beer yeast', 'common name');
INSERT INTO ncbi_taxa_names VALUES (4932, 'yeast', 'common name');
INSERT INTO ncbi_taxa_nodes VALUES (4930, 4893, 'genus', 0, 499049, 499222, 1);
INSERT INTO ncbi_taxa_names VALUES (4930, 'Pachytichospora', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (4930, 'Saccharomyces', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (9072, 9005, 'subfamily', 0, 327892, 328149, 1);
INSERT INTO ncbi_taxa_names VALUES (9072, 'Phasianinae', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (9845, 91561, 'suborder', 0, 320924, 321839, 1);
INSERT INTO ncbi_taxa_names VALUES (9845, 'Artiodactyla', 'in-part');
INSERT INTO ncbi_taxa_names VALUES (9845, 'Ruminantia', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (85512, 50557, 'no rank', 1, 354980, 425679, 1);
INSERT INTO ncbi_taxa_names VALUES (85512, 'Dicondylia', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (183770, 7713, 'order', 0, 354337, 354520, 1);
INSERT INTO ncbi_taxa_names VALUES (183770, 'Enterogona', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (8825, 8782, 'superorder', 0, 323091, 337838, 1);
INSERT INTO ncbi_taxa_names VALUES (8825, 'Neognathae', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (43741, 43738, 'no rank', 1, 402234, 405487, 1);
INSERT INTO ncbi_taxa_names VALUES (43741, 'Acalyptratae', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (83321, 70987, 'tribe', 1, 421562, 421629, 1);
INSERT INTO ncbi_taxa_names VALUES (83321, 'Apini', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (7952, 186627, 'order', 0, 291102, 293967, 1);
INSERT INTO ncbi_taxa_names VALUES (7952, 'Cypriniformes', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (7898, 117571, 'class', 0, 289488, 311505, 1);
INSERT INTO ncbi_taxa_names VALUES (7898, 'Actinopterygii', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (7898, 'Osteichthyes', 'in-part');
INSERT INTO ncbi_taxa_names VALUES (7898, 'bony fishes', 'blast name');
INSERT INTO ncbi_taxa_names VALUES (7898, 'fishes', 'in-part');
INSERT INTO ncbi_taxa_names VALUES (7898, 'ray-finned fishes', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (46879, 46877, 'subtribe', 1, 402513, 403948, 1);
INSERT INTO ncbi_taxa_names VALUES (46879, 'Drosophilina', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (8352, 30319, 'family', 0, 347447, 347556, 1);
INSERT INTO ncbi_taxa_names VALUES (8352, 'Pipidae', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (8352, 'pipid frogs', 'common name');
INSERT INTO ncbi_taxa_names VALUES (8352, 'tongueless frogs', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (119089, 6231, 'class', 0, 464378, 468405, 1);
INSERT INTO ncbi_taxa_names VALUES (119089, 'Adenophorea', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (119089, 'Chromadorea', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (7460, 7459, 'species', 1, 421574, 421615, 1);
INSERT INTO ncbi_taxa_names VALUES (7460, 'Apis mellifera', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (7460, 'Apis mellifica', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (7460, 'honey bee', 'genbank common name');
INSERT INTO ncbi_taxa_names VALUES (7460, 'honeybee', 'common name');
INSERT INTO ncbi_taxa_nodes VALUES (4893, 4892, 'family', 0, 498672, 499513, 1);
INSERT INTO ncbi_taxa_names VALUES (4893, 'Eremotheciaceae', 'includes');
INSERT INTO ncbi_taxa_names VALUES (4893, 'Saccharomycetaceae', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (7713, 7712, 'class', 0, 354336, 354689, 1);
INSERT INTO ncbi_taxa_names VALUES (7713, 'Ascidiacea', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (7713, 'sea squirts', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (9528, 9527, 'subfamily', 0, 316112, 316329, 1);
INSERT INTO ncbi_taxa_names VALUES (9528, 'Cercopithecinae', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (43845, 7214, 'subfamily', 1, 402511, 403950, 1);
INSERT INTO ncbi_taxa_names VALUES (43845, 'Drosophilinae', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (131567, 1, 'no rank', 1, 150, 551157, 1);
INSERT INTO ncbi_taxa_names VALUES (131567, 'biota', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (131567, 'cellular organisms', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (7712, 7711, 'subphylum', 0, 354311, 354716, 1);
INSERT INTO ncbi_taxa_names VALUES (7712, 'Tunicata', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (7712, 'Urochordata', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (7712, 'tunicates', 'genbank common name');
INSERT INTO ncbi_taxa_names VALUES (7712, 'tunicates', 'blast name');
INSERT INTO ncbi_taxa_nodes VALUES (186625, 186624, 'no rank', 1, 290009, 311048, 1);
INSERT INTO ncbi_taxa_names VALUES (186625, 'Clupeocephala', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (7717, 7716, 'family', 0, 354377, 354388, 1);
INSERT INTO ncbi_taxa_names VALUES (7717, 'Cionidae', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (39562, 7953, 'subfamily', 1, 291621, 291782, 1);
INSERT INTO ncbi_taxa_names VALUES (39562, 'Danioninae', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (39562, 'Rasborinae', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (9895, 35500, 'family', 0, 321258, 321837, 1);
INSERT INTO ncbi_taxa_names VALUES (9895, 'Bovidae', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (33317, 33316, 'no rank', 1, 354719, 462756, 1);
INSERT INTO ncbi_taxa_names VALUES (33317, 'Protostomia', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (30314, 8342, 'suborder', 0, 347439, 347680, 1);
INSERT INTO ncbi_taxa_names VALUES (30314, 'Mesobatrachia', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (8287, 117571, 'no rank', 1, 311506, 353319, 1);
INSERT INTO ncbi_taxa_names VALUES (8287, 'Sarcopterygii', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (32346, 32341, 'species group', 1, 402863, 403090, 1);
INSERT INTO ncbi_taxa_names VALUES (32346, 'melanogaster group', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (99883, 47144, 'species', 1, 297200, 297201, 1);
INSERT INTO ncbi_taxa_names VALUES (99883, 'Tetraodon nigroviridis', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (7718, 7717, 'genus', 0, 354382, 354387, 1);
INSERT INTO ncbi_taxa_names VALUES (7718, 'Ciona', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (9031, 9030, 'species', 1, 327974, 327981, 1);
INSERT INTO ncbi_taxa_names VALUES (9031, 'Gallus domesticus', 'misnomer');
INSERT INTO ncbi_taxa_names VALUES (9031, 'Gallus gallus', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (9031, 'Gallus gallus domesticus', 'misnomer');
INSERT INTO ncbi_taxa_names VALUES (9031, 'chicken', 'genbank common name');
INSERT INTO ncbi_taxa_names VALUES (9031, 'chickens', 'common name');
INSERT INTO ncbi_taxa_names VALUES (9031, 'dwarf Leghorn chickens', 'includes');
INSERT INTO ncbi_taxa_names VALUES (9031, 'red junglefowl', 'includes');
INSERT INTO ncbi_taxa_nodes VALUES (9596, 207598, 'genus', 0, 316365, 316378, 1);
INSERT INTO ncbi_taxa_names VALUES (9596, 'Pan', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (9596, 'chimpanzees', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (40674, 32524, 'class', 0, 311557, 322938, 1);
INSERT INTO ncbi_taxa_names VALUES (40674, 'Mammalia', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (40674, 'mammals', 'genbank common name');
INSERT INTO ncbi_taxa_names VALUES (40674, 'mammals', 'blast name');
INSERT INTO ncbi_taxa_nodes VALUES (43786, 7148, 'infraorder', 1, 407362, 409797, 1);
INSERT INTO ncbi_taxa_names VALUES (43786, 'Culicimorpha', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (9347, 32525, 'no rank', 0, 311581, 322122, 1);
INSERT INTO ncbi_taxa_names VALUES (9347, 'Eutheria', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (9347, 'Placentalia', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (9347, 'eutherian mammals', 'common name');
INSERT INTO ncbi_taxa_names VALUES (9347, 'placental mammals', 'common name');
INSERT INTO ncbi_taxa_names VALUES (9347, 'placentals', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (6231, 33217, 'phylum', 0, 463027, 468406, 1);
INSERT INTO ncbi_taxa_names VALUES (6231, 'Nemata', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (6231, 'Nematoda', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (6231, 'nematode', 'common name');
INSERT INTO ncbi_taxa_names VALUES (6231, 'nematodes', 'common name');
INSERT INTO ncbi_taxa_names VALUES (6231, 'nematodes', 'blast name');
INSERT INTO ncbi_taxa_names VALUES (6231, 'roundworm', 'common name');
INSERT INTO ncbi_taxa_names VALUES (6231, 'roundworms', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (32443, 41665, 'no rank', 0, 289677, 311502, 1);
INSERT INTO ncbi_taxa_names VALUES (32443, 'Teleostei', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (32443, 'teleost fishes', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (10090, 10088, 'species', 1, 315104, 315123, 1);
INSERT INTO ncbi_taxa_names VALUES (10090, 'LK3 transgenic mice', 'includes');
INSERT INTO ncbi_taxa_names VALUES (10090, 'Mus muscaris', 'misnomer');
INSERT INTO ncbi_taxa_names VALUES (10090, 'Mus musculus', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (10090, 'Mus sp. 129SV', 'includes');
INSERT INTO ncbi_taxa_names VALUES (10090, 'house mouse', 'genbank common name');
INSERT INTO ncbi_taxa_names VALUES (10090, 'mice C57BL/6xCBA/CaJ hybrid', 'misspelling');
INSERT INTO ncbi_taxa_names VALUES (10090, 'mouse', 'common name');
INSERT INTO ncbi_taxa_names VALUES (10090, 'nude mice', 'includes');
INSERT INTO ncbi_taxa_names VALUES (10090, 'transgenic mice', 'includes');
INSERT INTO ncbi_taxa_nodes VALUES (32523, 8287, 'no rank', 1, 311555, 353318, 1);
INSERT INTO ncbi_taxa_names VALUES (32523, 'Tetrapoda', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (32523, 'tetrapods', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (47144, 31031, 'genus', 0, 297199, 297208, 1);
INSERT INTO ncbi_taxa_names VALUES (47144, 'Tetraodon', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (32525, 40674, 'no rank', 1, 311580, 322937, 1);
INSERT INTO ncbi_taxa_names VALUES (32525, 'Theria', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (4890, 4751, 'phylum', 0, 496588, 528737, 1);
INSERT INTO ncbi_taxa_names VALUES (4890, 'Ascomycota', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (4890, 'ascomycetes', 'genbank common name');
INSERT INTO ncbi_taxa_names VALUES (4890, 'ascomycetes', 'blast name');
INSERT INTO ncbi_taxa_names VALUES (4890, 'sac fungi', 'common name');
INSERT INTO ncbi_taxa_nodes VALUES (117571, 117570, 'no rank', 0, 289487, 353320, 1);
INSERT INTO ncbi_taxa_names VALUES (117571, 'Euteleostomi', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (117571, 'bony vertebrates', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (33316, 33213, 'no rank', 1, 287458, 462757, 1);
INSERT INTO ncbi_taxa_names VALUES (33316, 'Coelomata', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (314294, 9526, 'superfamily', 1, 315994, 316333, 1);
INSERT INTO ncbi_taxa_names VALUES (314294, 'Cercopithecoidea', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (33554, 314145, 'order', 0, 318757, 319680, 1);
INSERT INTO ncbi_taxa_names VALUES (33554, 'Carnivora', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (13616, 13615, 'species', 1, 322230, 322231, 1);
INSERT INTO ncbi_taxa_names VALUES (13616, 'Monodelphis domestica', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (13616, 'Monodelphis domesticus', 'misspelling');
INSERT INTO ncbi_taxa_names VALUES (13616, 'gray short-tailed opossum', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (33392, 33340, 'infraclass', 0, 371693, 425608, 1);
INSERT INTO ncbi_taxa_names VALUES (33392, 'Endopterygota', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (33392, 'Holometabola', 'synonym');
INSERT INTO ncbi_taxa_nodes VALUES (337687, 33553, 'no rank', 0, 312856, 315187, 1);
INSERT INTO ncbi_taxa_names VALUES (337687, 'Muroidea', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (9913, 9903, 'species', 1, 321577, 321578, 1);
INSERT INTO ncbi_taxa_names VALUES (9913, 'Bos Tauurus', 'misspelling');
INSERT INTO ncbi_taxa_names VALUES (9913, 'Bos bovis', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (9913, 'Bos primigenius taurus', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (9913, 'Bos taurus', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (9913, 'bovine', 'common name');
INSERT INTO ncbi_taxa_names VALUES (9913, 'cattle', 'genbank common name');
INSERT INTO ncbi_taxa_names VALUES (9913, 'cow', 'common name');
INSERT INTO ncbi_taxa_names VALUES (9913, 'domestic cattle', 'common name');
INSERT INTO ncbi_taxa_names VALUES (9913, 'domestic cow', 'common name');
INSERT INTO ncbi_taxa_nodes VALUES (7955, 7954, 'species', 1, 291771, 291772, 1);
INSERT INTO ncbi_taxa_names VALUES (7955, 'Brachidanio rerio', 'misspelling');
INSERT INTO ncbi_taxa_names VALUES (7955, 'Brachydanio rerio', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (7955, 'Danio rerio', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (7955, 'zebra danio', 'common name');
INSERT INTO ncbi_taxa_names VALUES (7955, 'zebra fish', 'common name');
INSERT INTO ncbi_taxa_names VALUES (7955, 'zebrafish', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (9989, 314147, 'order', 0, 311884, 315977, 1);
INSERT INTO ncbi_taxa_names VALUES (9989, 'Rodentia', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (9989, 'rodents', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (4751, 33154, 'kingdom', 0, 473957, 530468, 1);
INSERT INTO ncbi_taxa_names VALUES (4751, 'Fungi', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (4751, 'fungi', 'blast name');
INSERT INTO ncbi_taxa_names VALUES (4751, 'fungi', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (9443, 314146, 'order', 0, 315979, 317062, 1);
INSERT INTO ncbi_taxa_names VALUES (9443, 'Primata', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (9443, 'Primates', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (9443, 'primate', 'equivalent name');
INSERT INTO ncbi_taxa_nodes VALUES (41666, 8292, 'superorder', 0, 347437, 353164, 1);
INSERT INTO ncbi_taxa_names VALUES (41666, 'Batrachia', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (32485, 129947, 'no rank', 0, 296978, 310375, 1);
INSERT INTO ncbi_taxa_names VALUES (32485, 'Percomorpha', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (44534, 7164, 'subgenus', 1, 407765, 408050, 1);
INSERT INTO ncbi_taxa_names VALUES (44534, 'Cellia', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (91561, 314145, 'no rank', 0, 320471, 321840, 1);
INSERT INTO ncbi_taxa_names VALUES (91561, 'Cetartiodactyla', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (2759, 131567, 'superkingdom', 0, 140109, 551156, 1);
INSERT INTO ncbi_taxa_names VALUES (2759, 'Eucarya', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (2759, 'Eucaryotae', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (2759, 'Eukarya', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (2759, 'Eukaryota', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (2759, 'Eukaryotae', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (2759, 'eucaryotes', 'genbank common name');
INSERT INTO ncbi_taxa_names VALUES (2759, 'eukaryotes', 'common name');
INSERT INTO ncbi_taxa_names VALUES (2759, 'eukaryotes', 'blast name');
INSERT INTO ncbi_taxa_nodes VALUES (123366, 123365, 'no rank', 1, 296335, 311004, 1);
INSERT INTO ncbi_taxa_names VALUES (123366, 'Eurypterygii', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (6239, 6237, 'species', 1, 467334, 467335, 1);
INSERT INTO ncbi_taxa_names VALUES (6239, 'Caenorhabditis elegans', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (6239, 'nematode', 'common name');
INSERT INTO ncbi_taxa_nodes VALUES (6237, 55885, 'genus', 0, 467321, 467348, 1);
INSERT INTO ncbi_taxa_names VALUES (6237, 'Caenorhabditis', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (8457, 32524, 'no rank', 1, 322939, 347434, 1);
INSERT INTO ncbi_taxa_names VALUES (8457, 'Sauropsida', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (8457, 'sauropsids', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (39107, 10066, 'subfamily', 0, 314518, 315185, 1);
INSERT INTO ncbi_taxa_names VALUES (39107, 'Murinae', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (39107, 'Otomyinae', 'includes');
INSERT INTO ncbi_taxa_nodes VALUES (9608, 9607, 'family', 0, 319555, 319678, 1);
INSERT INTO ncbi_taxa_names VALUES (9608, 'Canidae', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (7458, 34735, 'family', 0, 420560, 421851, 1);
INSERT INTO ncbi_taxa_names VALUES (7458, 'Anthophoridae', 'includes');
INSERT INTO ncbi_taxa_names VALUES (7458, 'Apidae', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (7458, 'bumble bees and honey bees', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (9527, 314294, 'family', 0, 315995, 316332, 1);
INSERT INTO ncbi_taxa_names VALUES (9527, 'Cercopithecidae', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (9527, 'Old World monkeys', 'genbank common name');
INSERT INTO ncbi_taxa_names VALUES (9527, 'monkey', 'common name');
INSERT INTO ncbi_taxa_names VALUES (9527, 'monkeys', 'common name');
INSERT INTO ncbi_taxa_nodes VALUES (41827, 43786, 'superfamily', 0, 407363, 408474, 1);
INSERT INTO ncbi_taxa_names VALUES (41827, 'Culicoidea', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (314145, 9347, 'superorder', 0, 317064, 321841, 1);
INSERT INTO ncbi_taxa_names VALUES (314145, 'Laurasiatheria', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (31032, 31031, 'genus', 0, 297265, 297300, 1);
INSERT INTO ncbi_taxa_names VALUES (31032, 'Fugu', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (31032, 'Takifugu', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (9263, 32525, 'no rank', 0, 322123, 322936, 1);
INSERT INTO ncbi_taxa_names VALUES (9263, 'Marsupialia', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (9263, 'Metatheria', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (9263, 'marsupials', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (33511, 33316, 'no rank', 1, 287459, 354718, 1);
INSERT INTO ncbi_taxa_names VALUES (33511, 'Deuterostomia', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (7147, 33392, 'order', 0, 399968, 410805, 1);
INSERT INTO ncbi_taxa_names VALUES (7147, 'Diptera', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (7147, 'flies', 'genbank common name');
INSERT INTO ncbi_taxa_names VALUES (7147, 'flies', 'blast name');
INSERT INTO ncbi_taxa_nodes VALUES (8342, 41666, 'order', 0, 347438, 352035, 1);
INSERT INTO ncbi_taxa_names VALUES (8342, 'Anura', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (8342, 'Salientia', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (8342, 'anurans', 'common name');
INSERT INTO ncbi_taxa_names VALUES (8342, 'frogs', 'common name');
INSERT INTO ncbi_taxa_names VALUES (8342, 'frogs and toads', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (43816, 7157, 'subfamily', 0, 407441, 408082, 1);
INSERT INTO ncbi_taxa_names VALUES (43816, 'Anophelinae', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (314147, 314146, 'no rank', 0, 311645, 315978, 1);
INSERT INTO ncbi_taxa_names VALUES (314147, 'Glires', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (9611, 9608, 'genus', 0, 319640, 319677, 1);
INSERT INTO ncbi_taxa_names VALUES (9611, 'Canis', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (7459, 83321, 'genus', 0, 421563, 421628, 1);
INSERT INTO ncbi_taxa_names VALUES (7459, 'Apis', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (9539, 9528, 'genus', 0, 316261, 316328, 1);
INSERT INTO ncbi_taxa_names VALUES (9539, 'Macaca', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (9539, 'macaques', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (9604, 314295, 'family', 0, 316335, 316380, 1);
INSERT INTO ncbi_taxa_names VALUES (9604, 'Hominidae', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (9604, 'Pongidae', 'synonym');
INSERT INTO ncbi_taxa_nodes VALUES (44542, 44537, 'no rank', 1, 407799, 407818, 1);
INSERT INTO ncbi_taxa_names VALUES (44542, 'gambiae species complex', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (9606, 9605, 'species', 1, 316348, 316351, 1);
INSERT INTO ncbi_taxa_names VALUES (9606, 'Homo sapiens', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (9606, 'human', 'genbank common name');
INSERT INTO ncbi_taxa_names VALUES (9606, 'man', 'common name');
INSERT INTO ncbi_taxa_nodes VALUES (30319, 30314, 'superfamily', 0, 347440, 347557, 1);
INSERT INTO ncbi_taxa_names VALUES (30319, 'Pipoidea', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (7215, 186285, 'genus', 0, 402701, 403904, 1);
INSERT INTO ncbi_taxa_names VALUES (7215, 'Drosophila', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (7215, 'fruit flies', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (7148, 7147, 'suborder', 0, 407237, 410804, 1);
INSERT INTO ncbi_taxa_names VALUES (7148, 'Nematocera', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (7157, 41827, 'family', 0, 407420, 408473, 1);
INSERT INTO ncbi_taxa_names VALUES (7157, 'Culicidae', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (7157, 'mosquitos', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (7719, 7718, 'species', 1, 354385, 354386, 1);
INSERT INTO ncbi_taxa_names VALUES (7719, 'Ciona intestinalis', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (32447, 186625, 'no rank', 0, 295628, 311047, 1);
INSERT INTO ncbi_taxa_names VALUES (32447, 'Euteleostei', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (9615, 9611, 'species', 1, 319641, 319644, 1);
INSERT INTO ncbi_taxa_names VALUES (9615, 'Canis canis', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (9615, 'Canis domesticus', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (9615, 'Canis familiaris', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (9615, 'Canis lupus familiaris', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (9615, 'beagle dog', 'includes');
INSERT INTO ncbi_taxa_names VALUES (9615, 'beagle dogs', 'includes');
INSERT INTO ncbi_taxa_names VALUES (9615, 'dog', 'genbank common name');
INSERT INTO ncbi_taxa_names VALUES (9615, 'dogs', 'common name');
INSERT INTO ncbi_taxa_nodes VALUES (4892, 4891, 'order', 0, 496709, 499514, 1);
INSERT INTO ncbi_taxa_names VALUES (4892, 'Endomycetales', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (4892, 'Saccharomycetales', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (4892, 'budding yeasts', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (32455, 123370, 'superorder', 0, 296730, 310443, 1);
INSERT INTO ncbi_taxa_names VALUES (32455, 'Acanthopterygii', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (186634, 186625, 'no rank', 1, 290010, 295627, 1);
INSERT INTO ncbi_taxa_names VALUES (186634, 'Otocephala', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (33208, 33154, 'kingdom', 0, 280775, 473956, 1);
INSERT INTO ncbi_taxa_names VALUES (33208, 'Animalia', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (33208, 'Metazoa', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (33208, 'animals', 'blast name');
INSERT INTO ncbi_taxa_names VALUES (33208, 'metazoans', 'genbank common name');
INSERT INTO ncbi_taxa_names VALUES (33208, 'multicellular animals', 'common name');
INSERT INTO ncbi_taxa_nodes VALUES (207598, 9604, 'no rank', 1, 316346, 316379, 1);
INSERT INTO ncbi_taxa_names VALUES (207598, 'Homo/Pan/Gorilla group', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (10088, 39107, 'genus', 0, 315091, 315180, 1);
INSERT INTO ncbi_taxa_names VALUES (10088, 'Mus', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (10088, 'Nannomys', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (10088, 'mice', 'common name');
INSERT INTO ncbi_taxa_nodes VALUES (8364, 8363, 'species', 1, 347461, 347462, 1);
INSERT INTO ncbi_taxa_names VALUES (8364, 'Silurana tropicalis', 'genbank synonym');
INSERT INTO ncbi_taxa_names VALUES (8364, 'Xenopus (Silurana) tropicalis', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (8364, 'Xenopus tropicalis', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (8364, 'western clawed frog', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (186624, 32443, 'no rank', 1, 290008, 311501, 1);
INSERT INTO ncbi_taxa_names VALUES (186624, 'Elopocephala', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (33340, 7496, 'subclass', 0, 357034, 425609, 1);
INSERT INTO ncbi_taxa_names VALUES (33340, 'Neoptera', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (186626, 32519, 'no rank', 1, 290254, 295625, 1);
INSERT INTO ncbi_taxa_names VALUES (186626, 'Otophysi', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (6960, 197562, 'superclass', 0, 354914, 426435, 1);
INSERT INTO ncbi_taxa_names VALUES (6960, 'Atelocerata', 'in-part');
INSERT INTO ncbi_taxa_names VALUES (6960, 'Hexapoda', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (6960, 'Tracheata', 'in-part');
INSERT INTO ncbi_taxa_names VALUES (6960, 'Uniramia', 'in-part');
INSERT INTO ncbi_taxa_names VALUES (6960, 'insects', 'genbank common name');
INSERT INTO ncbi_taxa_names VALUES (6960, 'insects', 'blast name');
INSERT INTO ncbi_taxa_nodes VALUES (50557, 6960, 'class', 0, 354915, 425680, 1);
INSERT INTO ncbi_taxa_names VALUES (50557, 'Insecta', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (50557, 'true insects', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (186839, 32447, 'no rank', 1, 296177, 311046, 1);
INSERT INTO ncbi_taxa_names VALUES (186839, 'Neognathi', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (88770, 33317, 'no rank', 1, 354904, 443477, 1);
INSERT INTO ncbi_taxa_names VALUES (88770, 'Panarthropoda', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (55885, 6243, 'subfamily', 0, 467288, 467349, 1);
INSERT INTO ncbi_taxa_names VALUES (55885, 'Peloderinae', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (123367, 123366, 'no rank', 1, 296456, 311003, 1);
INSERT INTO ncbi_taxa_names VALUES (123367, 'Ctenosquamata', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (126287, 9265, 'subfamily', 1, 322146, 322263, 1);
INSERT INTO ncbi_taxa_names VALUES (126287, 'Didelphinae', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (147537, 4890, 'subphylum', 0, 496659, 499632, 1);
INSERT INTO ncbi_taxa_names VALUES (147537, 'Saccharomycotina', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (31022, 32485, 'order', 0, 296999, 297340, 1);
INSERT INTO ncbi_taxa_names VALUES (31022, 'Tetraodontiformes', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (4891, 147537, 'class', 0, 496660, 499631, 1);
INSERT INTO ncbi_taxa_names VALUES (4891, 'Hemiascomycetes', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (4891, 'Saccharomycetes', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (27592, 9895, 'subfamily', 0, 321477, 321584, 1);
INSERT INTO ncbi_taxa_names VALUES (27592, 'Bovinae', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (70987, 7458, 'subfamily', 1, 421533, 421670, 1);
INSERT INTO ncbi_taxa_names VALUES (70987, 'Apinae', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (70987, 'honey bees', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (6656, 88770, 'phylum', 0, 354905, 442982, 1);
INSERT INTO ncbi_taxa_names VALUES (6656, 'Arthropoda', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (6656, 'arthropods', 'blast name');
INSERT INTO ncbi_taxa_nodes VALUES (41665, 186623, 'no rank', 0, 289654, 311503, 1);
INSERT INTO ncbi_taxa_names VALUES (41665, 'Neopterygii', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (7953, 30727, 'family', 0, 291104, 293367, 1);
INSERT INTO ncbi_taxa_names VALUES (7953, 'Cyprinidae', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (7400, 7399, 'no rank', 0, 411819, 425606, 1);
INSERT INTO ncbi_taxa_names VALUES (7400, 'Apocrita', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (89593, 7711, 'subphylum', 0, 289351, 354310, 1);
INSERT INTO ncbi_taxa_names VALUES (89593, 'Craniata', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (7716, 183770, 'order', 0, 354338, 354415, 1);
INSERT INTO ncbi_taxa_names VALUES (7716, 'Phlebobranchia', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (9544, 9539, 'species', 1, 316296, 316297, 1);
INSERT INTO ncbi_taxa_names VALUES (9544, 'Macaca mulatta', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (9544, 'rhesus macaque', 'common name');
INSERT INTO ncbi_taxa_names VALUES (9544, 'rhesus macaques', 'common name');
INSERT INTO ncbi_taxa_names VALUES (9544, 'rhesus monkey', 'genbank common name');
INSERT INTO ncbi_taxa_names VALUES (9544, 'rhesus monkeys', 'common name');
INSERT INTO ncbi_taxa_nodes VALUES (314293, 9443, 'infraorder', 1, 315992, 316763, 1);
INSERT INTO ncbi_taxa_names VALUES (314293, 'Anthropoidea', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (314293, 'Simiiformes', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (6072, 33208, 'no rank', 1, 281402, 472419, 1);
INSERT INTO ncbi_taxa_names VALUES (6072, 'Eumetazoa', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (8976, 8825, 'order', 0, 327754, 328337, 1);
INSERT INTO ncbi_taxa_names VALUES (8976, 'Craciformes', 'includes');
INSERT INTO ncbi_taxa_names VALUES (8976, 'Galliformes', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (7776, 7742, 'superclass', 1, 289485, 354308, 1);
INSERT INTO ncbi_taxa_names VALUES (7776, 'Gnathostomata', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (7776, 'jawed vertebrates', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (129947, 32455, 'no rank', 1, 296827, 310376, 1);
INSERT INTO ncbi_taxa_names VALUES (129947, 'Euacanthopterygii', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (9030, 9072, 'genus', 0, 327973, 327990, 1);
INSERT INTO ncbi_taxa_names VALUES (9030, 'Gallus', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (8782, 8492, 'class', 0, 322942, 337839, 1);
INSERT INTO ncbi_taxa_names VALUES (8782, 'Aves', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (8782, 'birds', 'genbank common name');
INSERT INTO ncbi_taxa_names VALUES (8782, 'birds', 'blast name');
INSERT INTO ncbi_taxa_nodes VALUES (32341, 7215, 'subgenus', 1, 402734, 403091, 1);
INSERT INTO ncbi_taxa_names VALUES (32341, 'Sophophora', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (33553, 9989, 'suborder', 0, 311889, 315428, 1);
INSERT INTO ncbi_taxa_names VALUES (33553, 'Myomorpha', 'includes');
INSERT INTO ncbi_taxa_names VALUES (33553, 'Sciurognathi', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (33553, 'Sciuromorpha', 'includes');
INSERT INTO ncbi_taxa_nodes VALUES (186285, 46879, 'no rank', 1, 402514, 403947, 1);
INSERT INTO ncbi_taxa_names VALUES (186285, 'Drosophiliti', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (9903, 27592, 'genus', 0, 321552, 321581, 1);
INSERT INTO ncbi_taxa_names VALUES (9903, 'Bos', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (9903, 'oxen, cattle', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (7399, 33392, 'order', 0, 411258, 425607, 1);
INSERT INTO ncbi_taxa_names VALUES (7399, 'Hymenoptera', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (7399, 'hymenopterans', 'common name');
INSERT INTO ncbi_taxa_names VALUES (7399, 'hymenopterans', 'blast name');
INSERT INTO ncbi_taxa_nodes VALUES (123370, 123369, 'no rank', 1, 296729, 311000, 1);
INSERT INTO ncbi_taxa_names VALUES (123370, 'Holacanthopterygii', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (1, 0, 'no rank', 0, 1, 593030, 1);
INSERT INTO ncbi_taxa_names VALUES (1, 'all', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (1, 'root', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (1, '2006-02-13 15:42:57', 'import date');
INSERT INTO ncbi_taxa_nodes VALUES (7164, 43816, 'genus', 0, 407456, 408081, 1);
INSERT INTO ncbi_taxa_names VALUES (7164, 'Anopheles', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (13615, 126287, 'genus', 0, 322221, 322234, 1);
INSERT INTO ncbi_taxa_names VALUES (13615, 'Monodelphis', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (13615, 'short-tailed opossums', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (8360, 8352, 'subfamily', 0, 347448, 347535, 1);
INSERT INTO ncbi_taxa_names VALUES (8360, 'Siluraninae', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (8360, 'Xenopodinae', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (31031, 32517, 'family', 0, 297176, 297301, 1);
INSERT INTO ncbi_taxa_names VALUES (31031, 'Tetraodontidae', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (31031, 'puffer fishes', 'common name');
INSERT INTO ncbi_taxa_names VALUES (31031, 'puffers', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (32517, 31028, 'superfamily', 0, 297175, 297302, 1);
INSERT INTO ncbi_taxa_names VALUES (32517, 'Tetradontoidea', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (35500, 9845, 'infraorder', 0, 320937, 321838, 1);
INSERT INTO ncbi_taxa_names VALUES (35500, 'Pecora', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (9005, 8976, 'family', 0, 327857, 328152, 1);
INSERT INTO ncbi_taxa_names VALUES (9005, 'Meleagrididae', 'includes');
INSERT INTO ncbi_taxa_names VALUES (9005, 'Phasianidae', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (9005, 'turkeys', 'common name');
INSERT INTO ncbi_taxa_nodes VALUES (117570, 7776, 'no rank', 1, 289486, 353321, 1);
INSERT INTO ncbi_taxa_names VALUES (117570, 'Teleostomi', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (10116, 10114, 'species', 1, 314988, 314989, 1);
INSERT INTO ncbi_taxa_names VALUES (10116, 'Buffalo rat', 'includes');
INSERT INTO ncbi_taxa_names VALUES (10116, 'Gunn rats', 'misnomer');
INSERT INTO ncbi_taxa_names VALUES (10116, 'Norway rat', 'genbank common name');
INSERT INTO ncbi_taxa_names VALUES (10116, 'Rattus PC12 clone IS', 'includes');
INSERT INTO ncbi_taxa_names VALUES (10116, 'Rattus norvegicus', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (10116, 'Rattus norvegicus8', 'misspelling');
INSERT INTO ncbi_taxa_names VALUES (10116, 'Rattus norwegicus', 'misspelling');
INSERT INTO ncbi_taxa_names VALUES (10116, 'Rattus rattiscus', 'misnomer');
INSERT INTO ncbi_taxa_names VALUES (10116, 'Rattus sp. strain Wistar', 'equivalent name');
INSERT INTO ncbi_taxa_names VALUES (10116, 'Sprague-Dawley rat', 'includes');
INSERT INTO ncbi_taxa_names VALUES (10116, 'Wistar rats', 'includes');
INSERT INTO ncbi_taxa_names VALUES (10116, 'brown rat', 'common name');
INSERT INTO ncbi_taxa_names VALUES (10116, 'laboratory rat', 'includes');
INSERT INTO ncbi_taxa_names VALUES (10116, 'rat', 'common name');
INSERT INTO ncbi_taxa_names VALUES (10116, 'rats', 'common name');
INSERT INTO ncbi_taxa_names VALUES (10116, 'zitter rats', 'includes');
INSERT INTO ncbi_taxa_nodes VALUES (197563, 6656, 'no rank', 1, 354912, 436559, 1);
INSERT INTO ncbi_taxa_names VALUES (197563, 'Mandibulata', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (197563, 'mandibulates', 'common name');
INSERT INTO ncbi_taxa_nodes VALUES (8353, 8360, 'genus', 0, 347449, 347534, 1);
INSERT INTO ncbi_taxa_names VALUES (8353, 'Xenopus', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (186623, 7898, 'no rank', 1, 289515, 311504, 1);
INSERT INTO ncbi_taxa_names VALUES (186623, 'Actinopteri', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (314295, 9526, 'superfamily', 1, 316334, 316431, 1);
INSERT INTO ncbi_taxa_names VALUES (314295, 'Hominoidea', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (8292, 32523, 'class', 0, 347436, 353317, 1);
INSERT INTO ncbi_taxa_names VALUES (8292, 'Amphibia', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (8292, 'Lissamphibia', 'includes');
INSERT INTO ncbi_taxa_names VALUES (8292, 'amphibians', 'genbank common name');
INSERT INTO ncbi_taxa_names VALUES (8292, 'amphibians', 'blast name');
INSERT INTO ncbi_taxa_nodes VALUES (7496, 85512, 'no rank', 0, 354981, 425610, 1);
INSERT INTO ncbi_taxa_names VALUES (7496, 'Pterygota', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (7496, 'winged insects', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (123365, 186839, 'no rank', 0, 296178, 311005, 1);
INSERT INTO ncbi_taxa_names VALUES (123365, 'Neoteleostei', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (44537, 44534, 'no rank', 1, 407788, 407825, 1);
INSERT INTO ncbi_taxa_names VALUES (44537, 'Pyretophorus', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (7742, 89593, 'no rank', 0, 289410, 354309, 1);
INSERT INTO ncbi_taxa_names VALUES (7742, 'Vertebrata', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (7742, 'vertebrates', 'genbank common name');
INSERT INTO ncbi_taxa_names VALUES (7742, 'vertebrates', 'blast name');
INSERT INTO ncbi_taxa_nodes VALUES (33213, 6072, 'no rank', 1, 281547, 468878, 1);
INSERT INTO ncbi_taxa_names VALUES (33213, 'Bilateria', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (32519, 186634, 'no rank', 0, 290221, 295626, 1);
INSERT INTO ncbi_taxa_names VALUES (32519, 'Ostariophysi', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (7954, 39562, 'genus', 0, 291738, 291781, 1);
INSERT INTO ncbi_taxa_names VALUES (7954, 'Brachydanio', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (7954, 'Danio', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (7954, 'Devario', 'synonym');
INSERT INTO ncbi_taxa_nodes VALUES (9265, 38605, 'family', 0, 322125, 322264, 1);
INSERT INTO ncbi_taxa_names VALUES (9265, 'American opossums', 'common name');
INSERT INTO ncbi_taxa_names VALUES (9265, 'Didelphidae', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (9265, 'opossums', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (123368, 123367, 'no rank', 0, 296655, 311002, 1);
INSERT INTO ncbi_taxa_names VALUES (123368, 'Acanthomorpha', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (30727, 7952, 'superfamily', 1, 291103, 293368, 1);
INSERT INTO ncbi_taxa_names VALUES (30727, 'Cyprinoidea', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (30727, 'Cyprinoidei', 'synonym');
INSERT INTO ncbi_taxa_nodes VALUES (7203, 7147, 'suborder', 0, 399989, 407236, 1);
INSERT INTO ncbi_taxa_names VALUES (7203, 'Brachycera', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (8363, 8353, 'subgenus', 0, 347450, 347465, 1);
INSERT INTO ncbi_taxa_names VALUES (8363, 'Silurana', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (8363, 'Xenopus tropicalis group', 'synonym');
INSERT INTO ncbi_taxa_nodes VALUES (46877, 43845, 'tribe', 1, 402512, 403949, 1);
INSERT INTO ncbi_taxa_names VALUES (46877, 'Drosophilini', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (43733, 7203, 'infraorder', 0, 399998, 405489, 1);
INSERT INTO ncbi_taxa_names VALUES (43733, 'Cyclorrhapha', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (43733, 'Muscomorpha', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (32524, 32523, 'no rank', 1, 311556, 347435, 1);
INSERT INTO ncbi_taxa_names VALUES (32524, 'Amniota', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (32524, 'amniotes', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (33154, 2759, 'no rank', 1, 280562, 530469, 1);
INSERT INTO ncbi_taxa_names VALUES (33154, 'Fungi/Metazoa group', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (7165, 44542, 'species', 1, 407800, 407803, 1);
INSERT INTO ncbi_taxa_names VALUES (7165, 'African malaria mosquito', 'genbank common name');
INSERT INTO ncbi_taxa_names VALUES (7165, 'Anopheles gambiae', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (7165, 'Anopheles gambiae sensu stricto', 'equivalent name');
INSERT INTO ncbi_taxa_nodes VALUES (33217, 33213, 'no rank', 1, 462758, 468877, 1);
INSERT INTO ncbi_taxa_names VALUES (33217, 'Pseudocoelomata', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (7711, 33511, 'phylum', 0, 289318, 354717, 1);
INSERT INTO ncbi_taxa_names VALUES (7711, 'Chordata', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (7711, 'chordates', 'genbank common name');
INSERT INTO ncbi_taxa_names VALUES (7711, 'chordates', 'blast name');
INSERT INTO ncbi_taxa_nodes VALUES (9526, 314293, 'no rank', 0, 315993, 316432, 1);
INSERT INTO ncbi_taxa_names VALUES (9526, 'Catarrhini', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (31033, 31032, 'species', 1, 297266, 297269, 1);
INSERT INTO ncbi_taxa_names VALUES (31033, 'Fugu rubripes', 'genbank synonym');
INSERT INTO ncbi_taxa_names VALUES (31033, 'Takifugu rubripes', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (31033, 'torafugu', 'common name');
INSERT INTO ncbi_taxa_nodes VALUES (7214, 43746, 'family', 0, 402510, 403999, 1);
INSERT INTO ncbi_taxa_names VALUES (7214, 'Drosophilidae', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (7214, 'pomace flies', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (32561, 8457, 'no rank', 1, 322940, 346561, 1);
INSERT INTO ncbi_taxa_names VALUES (32561, 'Diapsida', 'synonym');
INSERT INTO ncbi_taxa_names VALUES (32561, 'Sauria', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (32561, 'diapsids', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (9605, 207598, 'genus', 0, 316347, 316352, 1);
INSERT INTO ncbi_taxa_names VALUES (9605, 'Homo', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (314146, 9347, 'superorder', 0, 311582, 317063, 1);
INSERT INTO ncbi_taxa_names VALUES (314146, 'Euarchontoglires', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (10114, 39107, 'genus', 0, 314951, 315016, 1);
INSERT INTO ncbi_taxa_names VALUES (10114, 'Rattus', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (10114, 'rat', 'common name');
INSERT INTO ncbi_taxa_names VALUES (10114, 'rats', 'common name');
INSERT INTO ncbi_taxa_nodes VALUES (7434, 7400, 'suborder', 0, 418988, 424689, 1);
INSERT INTO ncbi_taxa_names VALUES (7434, 'Aculeata', 'scientific name');
INSERT INTO ncbi_taxa_nodes VALUES (9598, 9596, 'species', 1, 316366, 316375, 1);
INSERT INTO ncbi_taxa_names VALUES (9598, 'Chimpansee troglodytes', 'misspelling');
INSERT INTO ncbi_taxa_names VALUES (9598, 'Pan troglodytes', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (9598, 'chimpanzee', 'genbank common name');
INSERT INTO ncbi_taxa_nodes VALUES (34735, 7434, 'superfamily', 0, 419307, 421852, 1);
INSERT INTO ncbi_taxa_names VALUES (34735, 'Apoidea', 'scientific name');
INSERT INTO ncbi_taxa_names VALUES (34735, 'bees', 'genbank common name');
INSERT INTO ncbi_taxa_names VALUES (34735, 'bees', 'blast name');


DROP TABLE taxon;

