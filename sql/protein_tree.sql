
------------------------------------------------------------------------------------
--
-- Table structure for table 'protein_tree_nodes'
--
-- overview: for importing from the ncbi taxonomy taxdump.tar nodes.dmp file
--           tables stores the nodes in a tree formated DB
-- semantics:
--      nestedset_id          -- PRIMARY node id 
--      parent_id             -- parent node id
--      root_id               -- to quickly isolated nodes of the different rooted tree sets
--      left_index            -- for fast nested set searching
--      right_index           -- for fast nested set searching

CREATE TABLE protein_tree_nodes (
  nestedset_id                    int(10) unsigned NOT NULL auto_increment, # unique internal id
  parent_id                       int(10) unsigned NOT NULL,
  root_id                         int(10) unsigned NOT NULL,
  left_index                      int(10) NOT NULL,
  right_index                     int(10) NOT NULL,
  distance_to_parent              double default 1.0 NOT NULL,
  
  PRIMARY KEY (nestedset_id),
  KEY (parent_id),
  KEY (root_id)
);


------------------------------------------------------------------------------------
--
-- Table structure for table 'protein_tree_member'
--
-- overview:
--   to allow certain nodes to have aligned members attached to them   
-- semantics:
--    nestedset_id             -- the id of node associated with this name
--    member_id                -- link to member.member_id in many-1 relation (single member per node)
--    cigar_line               -- (synonym, common name, ...)

CREATE TABLE protein_tree_member (
  nestedset_id                int(10) unsigned NOT NULL,
  member_id                   int(10) unsigned NOT NULL, 
  cigar_line                  mediumtext,
  cigar_start                 int(10),
  cigar_end                   int(10),

  UNIQUE (nestedset_id),
  KEY (member_id)
);



------------------------------------------------------------------------------------
--
-- Table structure for table 'protein_tree_names'
--
-- overview: 
--    to allow for naming of nodes.  Useful for tagging multiple root nodes
--    Allows for many-many relations
-- semantics:
--    nestedset_id             -- the id of node associated with this name
--    name                     -- name itself
--    name_class               -- (synonym, common name, ...)

CREATE TABLE protein_tree_names (
  nestedset_id                int(10) unsigned NOT NULL,
  name                        varchar(255),
  name_class                  varchar(50),

  KEY (nestedset_id),
  KEY (name)
);



