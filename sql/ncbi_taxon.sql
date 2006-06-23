
------------------------------------------------------------------------------------
--
-- Table structure for table 'ncbi_taxa_node'
--
-- overview: for importing from the ncbi taxonomy taxdump.tar nodes.dmp file
--           tables stores the nodes in a tree formated DB
-- semantics:
--      taxon_id                                -- node id in GenBank taxonomy database
--      parent_id                               -- parent node id in GenBank taxonomy database
--      rank                                    -- rank of this node (superkingdom, kingdom, ...)
--      embl_code                               -- locus-name prefix; not unique
--      division_id                             -- see division.dmp file
--      inherited_div_flag  (1 or 0)            -- 1 if node inherits division from parent
--      genetic_code_id                         -- see gencode.dmp file
--      inherited_GC_flag   (1 or 0)            -- 1 if node inherits genetic code from parent
--      mitochondrial_genetic_code_id           -- see gencode.dmp file
--      inherited_MGC_flag  (1 or 0)            -- 1 if node inherits mitochondrial gencode from parent
--      GenBank_hidden_flag (1 or 0)            -- 1 if name is suppressed in GenBank entry lineage
--      hidden_subtree_root_flag (1 or 0)       -- 1 if this subtree has no sequence data yet
--      comments                                -- free-text comments and citations

CREATE TABLE ncbi_taxa_node (
  taxon_id                        int(10) unsigned NOT NULL,
  parent_id                       int(10) unsigned NOT NULL,
  rank                            char(32) default '' NOT NULL,
  embl_code                       int NOT NULL,
  division_id                     int NOT NULL,
  inherited_div_flag              int NOT NULL,
  genetic_code_id                 int NOT NULL,
  inherited_GC_flag               int NOT NULL,
  mitochondrial_genetic_code_id   int NOT NULL,
  inherited_MGC_flag              int NOT NULL,
  GenBank_hidden_flag             int NOT NULL,
  hidden_subtree_root_flag        int NOT NULL,
  comments                        char(40) default '' NOT NULL,
  left_index                      int(10) NOT NULL,
  right_index                     int(10) NOT NULL,
  root_id                         int(10) default 1 NOT NULL,
  
  KEY (taxon_id),
  KEY (parent_id),
  KEY (rank),
  KEY (division_id)
);

------------------------------------------------------------------------------------
--
-- Table structure for table 'ncbi_taxa_name'
--
-- overview: for importing from the ncbi taxonomy taxdump.tar names.dmp file
--           tables stores the multiple types of names used for each taxa level
-- semantics:
--    taxon_id                 -- the id of node associated with this name
--    name                     -- name itself
--    unique_name              -- the unique variant of this name if name not unique
--    name_class               -- (synonym, common name, ...)

CREATE TABLE ncbi_taxa_name (
  taxon_id                    int(10) unsigned NOT NULL,
  name                        varchar(255),
  unique_name                 varchar(255),
  name_class                  varchar(50),

  KEY (taxon_id),
  KEY (name),
  KEY (unique_name)
);


------------------------------------------------------------------------------------
--
-- Table structure for table 'ncbi_taxa_division'
--
-- overview: for importing from the ncbi taxonomy taxdump.tar divison.dmp file
--           tables stores the multiple types of names used for each taxa level
-- semantics:
--    division_id                             -- taxonomy database division id
--    division_cde                            -- GenBank division code (three characters)
--    division_name                           -- e.g. BCT, PLN, VRT, MAM, PRI...
--    comments

CREATE TABLE ncbi_taxa_division (
  division_id               int(10) unsigned NOT NULL,
  division_cde              char(8),
  division_name             char(50),
  comments                  char(100),

  FOREIGN KEY (division_id) REFERENCES ncbi_taxa_node(division_id),
  
  KEY (division_id)
  
);

