
------------------------------------------------------------------------------------
--
-- Table structure for table 'protein_tree_node'
--
-- overview:
--   This table holds the protein tree data structure, such as root, relation between 
--   parent and child, leaves
--
-- semantics:
--      node_id               -- PRIMARY node id 
--      parent_id             -- parent node id
--      root_id               -- to quickly isolated nodes of the different rooted tree sets
--      left_index            -- for fast nested set searching
--      right_index           -- for fast nested set searching
--      distance_to_parent    -- distance between node_id and its parent_id

CREATE TABLE protein_tree_node (
  node_id                         int(10) unsigned NOT NULL auto_increment, # unique internal id
  parent_id                       int(10) unsigned NOT NULL,
  root_id                         int(10) unsigned NOT NULL,
  left_index                      int(10) NOT NULL,
  right_index                     int(10) NOT NULL,
  distance_to_parent              double default 1.0 NOT NULL,
  
  PRIMARY KEY (node_id),
  KEY (parent_id),
  KEY (root_id),
  KEY (left_index),
  KEY (right_index)
);


------------------------------------------------------------------------------------
--
-- Table structure for table 'protein_tree_member'
--
-- overview:
--   to allow certain nodes (leaves) to have aligned protein members attached to them   
-- semantics:
--    node_id                  -- the id of node associated with this name
--    member_id                -- link to member.member_id in many-1 relation (single member per node)
--    method_link_species_set_id -- foreign key from method_link_species_set table
--    cigar_line               -- compressed alignment information 
--    cigar_start              -- protein start (0 if the whole protein is in the alignment)
--    cigar_end                -- protein end (0 if the whole protein is in the alignment)

CREATE TABLE protein_tree_member (
  node_id                     int(10) unsigned NOT NULL,
  member_id                   int(10) unsigned NOT NULL, 
  method_link_species_set_id  int(10) unsigned NOT NULL,
  cigar_line                  mediumtext,
  cigar_start                 int(10),
  cigar_end                   int(10),

  UNIQUE (node_id),
  KEY (member_id)
);



------------------------------------------------------------------------------------
--
-- Table structure for table 'protein_tree_tag'
--
-- overview: 
--    to allow for tagging nodes.
--    
-- semantics:
--    node_id             -- node_id foreign key from protein_tree_node table
--    tag                 -- tag used to fecth/store a value associated to it
--    value               -- value associated with a particular tag

CREATE TABLE protein_tree_tag (
  node_id                int(10) unsigned NOT NULL,
  tag                    varchar(50),
  value                  mediumtext,

  UNIQUE tag_node_id (node_id, tag),
  KEY (node_id),
  KEY (tag)
);



