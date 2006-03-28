
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

