#
# Table structure for table 'method_link_species_set_tag'
#

CREATE TABLE method_link_species_set_tag (
  method_link_species_set_id  int(10) unsigned NOT NULL, # FK species_set.species_set_id
  tag                         varchar(50) NOT NULL,
  value                       mediumtext,

  FOREIGN KEY (method_link_species_set_id) REFERENCES method_link_species_set(method_link_species_set_id),

  UNIQUE KEY tag_mlss_id (method_link_species_set_id,tag)

) COLLATE=latin1_swedish_ci ENGINE=MyISAM;
