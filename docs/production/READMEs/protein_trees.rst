Protein-tree pipeline
=====================

This document describes how to run ensembl-compara ProteinTrees pipeline.

Dependencies
------------

Necessary software components
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

* MySQL 5.1          (or higher)
* Perl 5.10          (or higher)
* Perl DBI API 1.6   (or higher)

EnsEMBL and BioPerl software:

* bioperl-live (version 1.6.9)               - Base of the BioPerl distribution. Mainly needed to provide I/O for alignments
* bioperl-run (version 1.6.9)                - Needed for the CodeML runnable/parser
* ensembl ("release/79" branch)              - Core API on which the rest of ensembl APIs are based
* ensembl-compara ("release/79" branch)      - Compara API (data objects, db adaptors, pipeline runnables, pipeline configuration)
* ensembl-hive ("version/2.2" branch)        - The system to run pipelines.

Refer to the following pages for tips about installation and setting up the environment:

- http://www.ensembl.org/info/docs/api/api_installation.html
- http://www.ensembl.org/info/docs/eHive.html

.. warning:: Please ensure that your PERL5LIB includes all of these modules and $ENSEMBL_CVS_ROOT_DIR points to the location of the checkouts

Perl libraries:

* *Mandatory*

  * Statistics::Descriptive    - Used during the dN/dS computation
  * Parse::RecDescent          - To export trees in newick

* *Optional*

  * JSON                       - Used to configure the non-Ensembl species on which the pipeline has to run
  * FamLibBuilder              - Only needed for the HMM-based clustering. Part of the Panther distribution
  * XML::Writer                - Used to output trees in OrthoXML and PhyloXML

Any compiled binaries mentioned in ``ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/Example/EnsemblProteinTrees_conf.pm``
Here is the list of the versions that we used for the e78 production:

* NCBI-blast 2.2.28+   - ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.2.28/
* mcoffee 9.03.r1318   - http://www.tcoffee.org/Projects/mcoffee/
* MAFFT 7.113          - http://mafft.cbrc.jp/alignment/software/
* hcluster_sg          - http://treesoft.svn.sourceforge.net/viewvc/treesoft/branches/lh3/hcluster/
* treebest (tag e78)   - https://github.com/Ensembl/treebest
* quicktree 1.1        - http://www.sanger.ac.uk/resources/software/quicktree/
* hmmbuild 3.0         - (part of the HMMER package) http://hmmer.janelia.org/
* codeml 4.3           - (part of the PAML package) http://abacus.gene.ucl.ac.uk/software/paml.html
* Ktreedist 1.0        - http://molevol.cmima.csic.es/castresana/Ktreedist.html

Except for CodeML, more recent versions probably still work (as long as the command line parameters haven't changed) but we only guarantee that the pipeline behaves with the advertised versions.


Data prerequisites
~~~~~~~~~~~~~~~~~~

You obviously need to know which species to include in the trees. Genomes can be in either Ensembl "core" databases or in Fasta files.

All the Ensembl "core" databases must have canonical transcripts defined (if not, refer to ``ensembl/misc-scripts/canonical_transcripts/set_canonical_transcripts.pl``).
If you define some genomes with Fasta files of protein and transcript entries, make sure they are using one-column headers, the same identifier in each, and no splice variants.

The pipeline needs a species tree to guide the reconstructions. By default, the NCBI taxonomy will be used, but you can also define your own (rooted) tree.

All NCBI taxon_ids must be public and in the NCBI tables (ncbi_taxa_node) in the master database. Although Ensembl updates the tables several times a year, the taxon_id of your favorite species may still be missing.
If it is the case, you can probably use the taxon_id of a species that has the same position in the taxonomy *relatively to the other species*.
If the NCBI taxonomy cannot be used (too many unresolved nodes), you can skip the taxon_id definition of that species. You'll also have to use a custom species-tree to guide the reconstruction.


General structure of the pipeline
---------------------------------

You can refer to docs/pipeline_diagrams/ProteinTrees.png for a visual description of the pipeline.

The main structure is given by some backbone analysis. Each one of them will dump the current state of the database (for a backup) and 
fire the next step of the pipeline. The backups can be used to restore the database if things go very wrong (let's hope they don't :) ).

The pipeline also contains numerous health-check analysis (named hc_*) that should detect as early as possible any error.
The pipeline will follow one of the two paths (A or B). 'A' is a clustering based on all-vs-all blastp. 'B' is a HMM-based clustering.
The option is selected by the hmm_clustering flag.

db_prepare
~~~~~~~~~~

At this step, the pipeline will initialize:

- the ncbi_taxa_node and ncbi_taxa_name tables: copied over from a reference database (either a "master" database, or a pre-existing Compara database)
- entries in the method_link, species_set_header, species_set, and method_link_species_set tables

Then, it will:

- check that the connections to each core database / FASTA file are available
- check whether some species-specific data can be reused from a reference Compara database (to save some time at the later stages of the pipeline). This is only available if you are running the pipeline with a master database.
- build the default species tree (using the NCBI taxonomy)

genome_load
~~~~~~~~~~~

At this step, the pipeline will actually load all the data related to the species:

- the list of members (genes and peptides)
- the peptide sequences
- the list of canonical transcripts (in case of alternative splicing: the isoform / sequence that should be used in the pipeline)

(path A) allvsallblast
~~~~~~~~~~~~~~~~~~~~~~

At this step, the pipeline will run the all-vs-all blastp comparisons. Some hits can be "reused" from the reference compara database, which
can save quite some time of computation.

(path A) hcluster
~~~~~~~~~~~~~~~~~

At this step, the pipeline will build a graph from the blast hits, and run hcluster_sg on it. The resulting clusters contain similar genes and will
map to individual gene-trees.

(path B) hmmClassify
~~~~~~~~~~~~~~~~~~~~

At this step, the pipeline will load all the HMM profiles defined in the library, and classify all the genes from all the species into them.
Each profile will naturally define a cluster.

tree_building
~~~~~~~~~~~~~

At this step, the pipeline will actually compute the trees with the

- multiple alignment (Mcoffee if the cluster has less than 250 genes, Mafft otherwise)
- tree reconstruction with TreeBest
- homology inference

To prevent computation issues, the largest clusters (more than 400 genes) are recursively split in halves until they fall until the limit size
with the QuickTree program (using a Mafft alignment)

dnds
~~~~

At this step, the pipeline will compute dN/dS values on all the homologies (this can be parameterized)


Pipeline configuration
----------------------

The pipeline structure (analysis work-flow) is defined in ``ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/ProteinTrees_conf.pm`` but the actual
parameters used by the various groups at the Genome Campus are defined in ``ensembl-compara/modules/Bio/EnsEMBL/Compara/PipeConfig/Example/*ProteinTrees_conf.pm``
They mainly include custom:

- paths to executables
- database connection parameters
- more general parameters (pipeline-related)
- beekeeper parameters

To configure the pipeline:

- make a copy of PipeConfig/Example/EnsemblProteinTrees_conf.pm into PipeConfig/Example/
- update the package name
- update the parameters in the default_options() section
- check that your grid engine is parameterized in resource_classes(): by default, only LSF is.

Here follows a description of each category of parameters

Path to executables
~~~~~~~~~~~~~~~~~~~

As stated in the first section of this document, the pipeline relies on some external programs to do the computation.
Make sure that all the necessary software are installed and properly configured.
All the \*_exe parameters must point to their correct locations

Database connections
~~~~~~~~~~~~~~~~~~~~

"Master" database
`````````````````

The pipeline can connect to a "master" database to initialize. This is needed if you intend to:

- run the pipeline multiple times (and reuse the list of blastp hits to speed up the consecutive runs)
- run the pipeline on a selection of species

Refer to :doc`master_database` to correctly set it up should you need one.
You will have to import all the species on which you want to run the pipeline with:

- ``ensembl-compara/scripts/pipeline/update_genome.pl`` for species with an Ensembl core database
- or a manual SQL INSERT, otherwise

Species with an Ensembl core database
'''''''''''''''''''''''''''''''''''''

Be aware that the Ensembl Registry relies on a specific nomenclature to automatically discover the databases on a server.
For instance, core databases must be named ``${SPECIES_NAME}_core_${ENSEMBL_VERSION}_${ASSEMBLY_VERSION}``.
If you have built databases your own core databases using a different nomenclature, you'll have to (for each of them):

- add a Registry entry in ``$ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/production_reg_conf.pl`` with

  ::

       Bio::EnsEMBL::Registry->load_registry_from_url("mysql://${USER}@${HOST}:${PORT}/${DATABASE_NAME}?group=core&species=${SPECIES_PRODUCTION_NAME}");

- run update_genome.pl
- define a "locator" for their corresponding genome_db. The locator is a string like:

  ::

       Bio::EnsEMBL::DBSQL::DBAdaptor/host=${HOST};port=${PORT};user=${USER};pass=${PASSWORD};dbname=${DATABASE_NAME};species=${SPECIES_PRODUCTION_NAME};species_id=${INTERNAL_SPECIES_ID};disconnect_when_inactive=1"

   that can be updated with:

  .. code-block:: sql

      UPDATE genome_db SET locator = (...) WHERE genome_db_id = (...);

Species without an Ensembl core datbase
'''''''''''''''''''''''''''''''''''''''

To configure them, you first have to gather all of their information in a JSON file, which contains
meta data for each species and should have the following format:

::

    [
      {
        "production_name"        : "nomascus_leucogenys",
        "taxonomy_id"            : "61853",
        "assembly"               : "Nleu2.0",
        "genebuild"              : "2011-05",
        "prot_fasta"             : "proteins.fasta",
        "cds_fasta"              : "transcripts.fasta",
        "gene_coord_gff"         : "annotation.gff",
      },
      {
        ...
      }
    ]

All the parameters are mandatory, except "gene_coord_gff".
The SQL INSERT will then look like:

.. code-block:: sql

   INSERT INTO genome_db (taxon_id, name, assembly, genebuild) VALUES (61853, "nomascus_leucogenys", "Nleu2.0", "2011-05");

Make sure that you are using the same values as in the JSON file

SpeciesSet and MethodLinkSpeciesSet
'''''''''''''''''''''''''''''''''''

Finally, once all the genome_dbs are loaded in the master database, we can move on to populating all the SpeciesSet and MethodLinkSpeciesSet entries needed for the pipeline (they are used to index the homologies).

First, generate the list of all the genome_db_ids you want to run the pipeline on. For instance:

.. code-block:: sql

  SELECT GROUP_CONCAT(genome_db_id ORDER BY genome_db_id) FROM genome_db;

Export this in a new environment variable $ALL_GENOMEDB_IDS

.. code-block:: bash

   export ALL_GENOMEDB_IDS="..."
   echo $ALL_GENOMEDB_IDS

Edit the "compara_master" section in ``$ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/production_reg_conf.pl`` and run the following commands:

.. code-block:: bash

    # orthologues
    $ echo -e "201\n" | perl $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/create_mlss.pl --f \
    --reg_conf $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/production_reg_conf.pl \
    --pw --genome_db_id "$ALL_GENOMEDB_IDS" 1> create_mlss.ENSEMBL_ORTHOLOGUES.201.out 2> create_mlss.ENSEMBL_ORTHOLOGUES.201.err

    # paralogues
    $ echo -e "202\n" | perl $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/create_mlss.pl --f \
    --reg_conf $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/production_reg_conf.pl \
    --sg --genome_db_id "$ALL_GENOMEDB_IDS" 1> create_mlss.ENSEMBL_PARALOGUES.wth.202.out 2> create_mlss.ENSEMBL_PARALOGUES.wth.202.err

    # protein trees
    $ echo -e "401\n" | perl $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/create_mlss.pl --f \
    --reg_conf $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/production_reg_conf.pl \
    --name "protein trees" --genome_db_id "$ALL_GENOMEDB_IDS" 1> create_mlss.PROTEIN_TREES.401.out 2> create_mlss.PROTEIN_TREES.401.err

Quickly inspect the .err files. They may contain warnings, but they shouldn't have any errors :)

Check on the database: :math:`n*(n-1)/2` MLSS entries for orthologies (pairwise only), :math:`n` for paralogies (within-species only) and 1 for the protein trees

.. code-block:: sql

  SELECT COUNT(*) FROM method_link_species_set WHERE method_link_id = 201;
  SELECT COUNT(*) FROM method_link_species_set WHERE method_link_id = 202;
  SELECT COUNT(*) FROM method_link_species_set WHERE method_link_id = 401;


Other databases
```````````````

The configuration file must define ``pipeline_db``: the database to hold the data.

If you are running the pipeline with a master database, define its connection parameters in ``master_db``, and set the ``use_master_db`` flag to 1
Otherwise, define the ``ncbi_db`` database and set the ``use_master_db`` flag to 0

The pipeline relies on some Ensembl core (species) databases to provide the species-specific data. This can be configured with the ``curr_core_sources_locs``
parameter, which is a list of database connections. It should contain the same server list as you have used when running ``scripts/pipeline/update_genome.pl``

If you are going to use Ensembl data, you may want to add the following database description:

::

    'ensembl_srv' => {
        -host   => 'ensembldb.ensembl.org',
        -port   => 5306,
        -user   => 'anonymous',
        -pass   => '',
    },
    'curr_core_sources_locs' => [ $self->o('ensembl_srv') ],

If you are going to run the pipeline on species that are not in Ensembl, you have to define the ``curr_file_sources_locs`` parameter with a JSON formatted file.


If you want to use a Compara database as a reference (for example, to reuse the results of the all-vs-all blastp), you have to set the ``reuse_from_prev_rel_db`` flag on, and configure the ``reuse_db`` parameter:

::

   'prev_rel_db' => {
        -host   => 'ensembldb.ensembl.org',
        -port   => 5306,
        -user   => 'anonymous',
        -pass   => '',
        -dbname => 'ensembl_compara_XXXX',
   },

Then, you will have to update the ``prev_core_sources_locs`` parameter. It is equivalent to ``curr_core_sources_locs``, but refers to the core databases
linked to ``reuse_db``. Again, on Ensembl data, you can define: ``'prev_core_sources_locs' => [ $self->o('ensembl_srv') ]``

More general parameters (pipeline-related)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:mlss_id: The method_link_species_set_id created by ``scripts/pipeline/create_mlss.pl``
   This defines the instance of the pipeline (which species to work on). It is only needed if you run the pipeline with a master database. Otherwise, the pipeline will create its own one.

   To get it from the master database, run the following query:

   .. code-block:: sql

      SELECT * FROM method_link_species_set WHERE method_link_id = 401;

   You can check the content of a species_set_id XXX this way:

   .. code-block:: sql

       SELECT name FROM species_set JOIN genome_db USING (genome_db_id)
       WHERE species_set_id = XXX ORDER BY name;

:release: The API version of your Ensembl checkouts

:rel_suffix: Any string (defaults to "") to distinguish between several runs on the same API version

:work_dir: where to store temporary files
   The pipeline will create there 3 folders:

    - blast_db: the blast databases for the all-vs-all blastp
    - cluster: files used by hcluster_sg
    - dumps: backups (checkpoints) of the database (make sure you have enough space available !)

:outgroups: The list of outgroup species (genome_db names)
   This is used by hcluster_sg to produce more relevant clusters. It allows two levels of outgroups (named as "2" and "4", "4" being the most out)
   In the Ensembl run, we only define S.cerevisae as outgroup (level 2). Hence the configuration: ``{'saccharomyces_cerevisiae' => 2}``

:taxlevels: On which clades should the pipeline try to compute dN/dS values.
   Those values are only available for close enough species and it is generally not a good idea to use very large clades (like the animal kingdom.
   The parameter is a list of taxa (given by their names in the NCBI taxonomy). The list can be empty to skip this step of the pipeline.
   In Ensembl, we only use mammals, some birds and some fish, in the config file this is shown as ``['Theria', 'Sauria', 'Tetraodontiformes']``

:filter_high_coverage: Only compute dN/dS values on "high coverage" species, i.e. the species that have the "is_high_coverage" flag set to 1 in
   the genome_db table. The parameter is used by the "group_genomes_under_taxa" analysis, so as long as it hasn't yet run, you can sill modify
   the parameter in the analysis.

beekeeper parameters
~~~~~~~~~~~~~~~~~~~~

All the z*_capacity parameters are tuned to fit the capacity of our MySQL servers. You might want to initially reduce them, and gradually increase
them "as long as the database holds" :) The relative proportion of each analysis should probably stay the same

The "resource_classes" of the configuration file defined how beekeeper should run each category of job. These are LSF parameters that you may only
want to change if you don't have a LSF installation

Run the pipeline
----------------

The pipeline is now ready to be run.
You can switch to :doc:`beekeeper`, which explains how to run beekeeper :)


Interpreting the errors
-----------------------

Many errors (increase memlimit on a job, reset failed jobs, etc) can be corrected by editing the parameters via the analysis pop-up box in the guiHive, or directly in the database.
Please note that below are examples of errors: the names, paths, etc may be different in your output.

Often, you can re-run the offending job to look at its log:

::

    runWorker.pl -url ${EHIVE_URL} -job_id xxxx -debug 9 -force 1


Cannot execute '/bin/mafft' in '/software/ensembl/compara/mafft-7.017/'
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Executable won't run: wrong location, no permission ? Find the executable that will run and edit the configuration file for your compara run.
You can also fix the current run by editing the parameters of the failed analysis with guiHive.


Missing parameter
~~~~~~~~~~~~~~~~~

The parameter should be added to the relevant analysis. However, some parameters are supposed to be global and shared across all the analysis (like ``mlss_id``).
You can define them on a live database by adding an entry to the ``pipeline_wide_parameters`` table:

.. code-block:: sql

   INSERT INTO pipeline_wide_parameters VALUES ("sreformat_exe", "/software/ensembl/compara/sreformat");


The required assembly_name ('ASM23792v1') is different from the one found in the database ('5.2')
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This is a quite common error at the start of the run. Fortunately, the computation hasn't really started yet, and we're not wasting too much time :)
The error often comes from a misleading entry in the the core database: the ``assembly.default`` meta key *is not* used to define the assembly.
The assembly is "the version of the highest coordinate system":

.. code-block:: sql

   SELECT version FROM coord_system WHERE rank = 1;

Make sure you are using the same version in your master database:

.. code-block:: sql

  UPDATE genome_db SET assembly = "5.2" WHERE genome_db_id = 40


Analysis "hc_members_per_genome": No genes / proteins have been loaded for this species
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A few things may have gone wrong:

* Check that canonical transcripts have been defined for the genome_db shown in the error. If not, give a go to ``$ENSEMBL_CVS_ROOT_DIR/ensembl/misc-scripts/canonical_transcripts/set_canonical_transcripts.pl``
* Identify the load_fresh_members job for the problematic genome_id and rerun the job

  .. code-block:: sql

     SELECT * FROM job WHERE analysis_id = XXX AND input_id LIKE "%${GDB_ID}%";

  .. code-block:: bash

     runWorker.pl -url ${EHIVE_URL} -job_id ${JOB_ID} -debug 9 -force 1

* Check whether the members are loaded, and the SQL query has output

  .. code-block:: sql

     SELECT source_name, COUNT(*) FROM gene_member WHERE genome_db_id = 40 GROUP BY source_name;
     SELECT source_name, COUNT(*) FROM seq_member WHERE genome_db_id = 40 GROUP BY source_name;


Analysis "hc_members_per_genome"
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The error usually comes on species loaded from Fasta files. Make sure that the IDs used in in the ``cds_fasta`` and in the ``prot_fasta`` files are the same.

.. code-block:: sql

   -- Identify the problematic members
   SELECT mp.seq_member_id FROM seq_member mp LEFT JOIN other_member_sequence oms ON mp.seq_member_id = oms.seq_member_id AND oms.seq_type = "cds" WHERE genome_db_id = 68 AND (sequence IS NULL OR LENGTH(sequence) = 0);

   -- Query the seq_member table for the offending member_ids
   SELECT * FROM seq_member WHERE seq_member_id IN (123456,456789)

   -- If only a few members are in error, you can edit the database
   INSERT INTO other_member_sequence VALUES (534756, "cds", 32, "ATGTAGCTGTGACTCGAGAGAATATTTTAATG");

   -- If more than a few entries, you need to rerun the load_fresh_members_fromfile job, identify the relevant job
   DELETE other_member_sequence FROM seq_member JOIN other_member_sequence USING (seq_member_id) WHERE genome_db_id = 6789;
   DELETE FROM seq_member WHERE genome_db_id = 6789;
   DELETE FROM gene_member WHERE genome_db_id = 6789;
   SELECT * FROM job WHERE analysis_id = 1234 AND input_id LIKE "%6789%";

.. code-block:: bash

   runWorker.pl -url ${EHIVE_URL} -job_id ${JOB_ID} -debug 9 -force 1
   # Check that the problem has been fixed


*Members should have chromosome coordinates*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- If they correspond to species that come from an Ensembl (Genomes) database, this should not happen. Contact us
- If they come from your core databases, there may be an issue there. Check whether the coordinates are set there
- If they are configured in the JSON file, something is wrong with the gene_coord_gff GFF file. There might be missing entries there, different IDs, or no GFF file at all (you can gorgive the failed job, then).

The coordinates are used when the pipeline tries to detect partial gene models that should be "merged" to produce a full gene model ("split genes").
It is not mandatory, but split genes won't be detected for these species, and that their partial genes may be in weird positions in the final protein trees.

If you don't mind the risks, just forgive the job. Otherwise, have a look at the gene_coord_gff file.


*GarbageCollector: The worker died because of MEMLIMIT*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This is the error message in the msg table when the farm job memory limit is exceeded.

This can be corrected in guiHive by changing the resource class of the corresponding analysis


*Could not find species_name='ascaris_suum', assembly_name='v3' on the servers provided, please investigate*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Check that the list of registry parameters passed to the job are correct.
You can also check that the locator field in genome_db is set to a MySQL NULL and not the string "NULL"


*The protein sequences should not be only ACGTN*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This HC fails if, for instance, there is a stop codon ("*") in the sequence.
By repeating the SQL query, you'll get the offending member_ids. Then:

.. code-block:: sql

   SELECT sequence_id FROM seq_member WHERE seq_member_id = XXXX;
   SELECT sequence FROM sequence WHERE sequence_id = YYYY;
   UPDATE sequence SET sequence = "...", length = ... WHERE sequence_id = YYYY;


*Peptides should have CDS sequences (which are made of only ACGTN)*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Some CDS sequences are either missing, or not canonical. If they contain some ambiguity bases (like R, Y, etc), you can turn the option ``allow_ambiguity_codes`` on and restart the HC.
The pipeline should run fine with such characters, but they'll probably be interpreted as gaps by most of the programs.


*This algorithm is less useful if only 0 species are matched*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This error message from treebest means that the species tree do not match your set of genome_dbs.
Make sure that your species tree contains all the species.


SQL tricks
----------

The data is exclusively stored in the database, and a good understanding of its schema is necessary to fix some common errors (previous section) and to get basic information / statistics about the pipeline.
This section lists some common queries that may help in this aspect.

Compara (Gene-tree) data
~~~~~~~~~~~~~~~~~~~~~~~~

* Count members for a given species:

  .. code-block:: sql

     SELECT COUNT(*) FROM seq_member WHERE genome_db_id=309;
     SELECT COUNT(*) FROMde gene_member WHERE genome_db_id=309;
     SELECT COUNT(*) FROM seq_member JOIN other_member_sequence USING (seq_member_id) WHERE genome_db_id=309;

* Get dna_frag coordinates for a given species:

  .. code-block:: sql

     SELECT coord_system_name, count(*) FROM dnafrag WHERE genome_db_id=1 GROUP BY coord_system_name;

* Get tree nodes for a given ref_root_id:

  .. code-block:: sql

     SELECT gene_tree_node.* FROM gene_tree_node JOIN gene_tree_root USING (root_id) WHERE ref_root_id=2592155;

* Delete a tree. Use the Perl API !

  .. code-block:: perl

     $gene_tree_adaptor->delete_tree($gene_tree_adaptor->fetch_by_dbID(3));

* Create new tree-tags (alignment length, for instance):

  .. code-block:: sql

     INSERT INTO gene_tree_root_tag (root_id,tag,value) SELECT root_id, "aln_length", aln_length FROM gene_tree_root JOIN gene_align USING (gene_align_id) WHERE clusterset_id = "default";

* Problems with gene_tree_backup ?  Re-insert all the root_ids:

  .. code-block:: sql

     INSERT IGNORE INTO gene_tree_backup (seq_member_id, root_id) SELECT seq_member_id, root_id FROM gene_tree_node JOIN gene_tree_root USING (root_id) WHERE seq_member_id IS NOT NULL AND clusterset_id = "default";

* Check if all gene_tree_roots are in backup:

  .. code-block:: sql

     SELECT * from gene_tree_backup RIGHT JOIN gene_tree_root USING (root_id) WHERE clusterset_id = "default" AND gene_tree_backup.root_id IS NULL;

SELECT value FROM gene_tree_root_tag WHERE root_id=458053 AND tag = 'model_name';

* Count all the trees via gene_root_tag:

  .. code-block:: sql

     SELECT COUNT(DISTINCT root_id) FROM gene_tree_root_tag JOIN gene_tree_root USING (root_id) WHERE tag = 'tree_num_leaves' AND clusterset_id = 'default';

* Get all the nodes that don't have any children (i.e. leaves):

  .. code-block:: sql

     SELECT * FROM gene_tree_node g1 LEFT JOIN gene_tree_node g2 ON g1.node_id = g2.parent_id WHERE g1.root_id = 22365088 AND g1.seq_member_id IS NULL GROUP BY g1.node_id HAVING COUNT(g2.node_id) = 0;

* Flatten a tree:

  .. code-block:: sql

     DELETE homology_member FROM homology JOIN homology_member WHERE gene_tree_root_id = 22365088;
     DELETE FROM homology WHERE gene_tree_root_id = 22365088;
     UPDATE gene_tree_node SET parent_id = root_id WHERE root_id = 22365088 AND seq_member_id IS NOT NULL;
     DELETE gene_tree_node_attr FROM gene_tree_node JOIN gene_tree_node_attr USING (node_id) WHERE root_id = 22365088 AND node_id != root_id AND seq_member_id IS NULL;
     DELETE gene_tree_node_tag  FROM gene_tree_node JOIN gene_tree_node_tag  USING (node_id) WHERE root_id = 22365088 AND node_id != root_id AND seq_member_id IS NULL;
     UPDATE gene_tree_node      SET parent_id = NULL, root_id = NULL                         WHERE root_id = 22365088 AND node_id != root_id AND seq_member_id IS NULL;
     DELETE FROM gene_tree_node WHERE root_id IS NULL;
     UPDATE gene_tree_node SET left_index = 0, right_index = 0, distance_to_parent = 0 WHERE root_id = 22365088;

* Update gene_count:

  .. code-block:: sql

     DELETE FROM gene_tree_root_tag WHERE tag = "gene_count";
     INSERT INTO gene_tree_root_tag SELECT root_id, "gene_count", COUNT(seq_member_id) FROM gene_tree_node GROUP BY root_id;

* Get alignment length:

  .. code-block:: sql

     SELECT * FROM gene_tree_root JOIN gene_align USING (gene_align_id) WHERE root_id=25381383;

* Check report for an specific analysis:

  .. code-block:: sql

     SELECT * FROM lsf_usage WHERE analysis LIKE "raxml(%"

* Get running times and alignment lengths:

  .. code-block:: sql

     SELECT stable_id, aln_length, runtime_msec FROM gene_tree_root INNER JOIN job ON job.input_id LIKE CONCAT('%', gene_tree_root.root_id, '%') JOIN gene_align USING (gene_align_id) WHERE analysis_id=84 AND status="DONE";


Hive data / edit the pipeline workflow
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. warning:: Only if you know you need to do that !

* Get all jobs working for a given root_id:

  .. code-block:: sql

     SELECT * FROM job WHERE input_id like "%2592155%";

* Get all the messages for a specific analysis:

  .. code-block:: sql

     SELECT * FROM msg WHERE analysis_id = 47;

* Change the origin of a dataflow:

  .. code-block:: sql

     SELECT * FROM dataflow_rule WHERE from_analysis_id = 18;
     UPDATE dataflow_rule SET from_analysis_id = 21 WHERE dataflow_rule_id = 29;

* Clear an specific analysis_id (we take advantage of the ON DELETE CASCADE flag)

  .. code-block:: sql

     DELETE FROM job WHERE analysis_id=85;

* Reset the parent job of some failed jobs

  .. code-block:: sql

     UPDATE job AS t1 INNER JOIN
     (
        SELECT prev_job_id
        FROM job WHERE analysis_id = 84 AND status = "FAILED"
     ) AS t2 ON (t2.prev_job_id=t1.job_id)
     SET t1.status = "READY";

* Create new jobs of analysis_id 72 for trees matching a given tag

  .. code-block:: sql

     INSERT INTO job (analysis_id, input_id) SELECT 72, CONCAT("{'gene_tree_id' => ", root_id, "}") FROM gene_tree_root_tag WHERE value LIKE "PTHR23155_SF%";

* Create a new job of analysis_id 85 for each gene-tree

  .. code-block:: sql

     INSERT INTO job (analysis_id, input_id) SELECT 85, CONCAT("{'gene_tree_id' => ", root_id, "}") FROM gene_tree_root WHERE clusterset_id="default" AND tree_type="tree";

* Duplicate the jobs of analysis_id 85 to analysis_id 119, with 119 blocking 85 with semaphores

  .. code-block:: sql

     INSERT INTO job (analysis_id, input_id, semaphore_count, semaphored_job_id) SELECT 119, input_id, 0, job_id FROM job WHERE analysis_id=85;

* Create the jobs that would have been created by data flow (on jobs that have failed):

  .. code-block:: sql

     INSERT INTO job (analysis_id, input_id, semaphored_job_id) SELECT 84, REPLACE(input_id, "}", ", 'remove_columns' => 0}"), semaphored_job_id FROM job WHERE analysis_id=82 AND status = "FAILED";

* Find bogus dataflow rules:

  .. code-block:: sql

     SELECT * FROM dataflow_rule LEFT JOIN analysis_base ON to_analysis_url = logic_name WHERE logic_name IS NULL;


Looking at the results
----------------------

The pipeline generates and emails a report with statistics about the gene trees.
You'll need to use either the PERL API or a REST server to actually connect to the database and study the trees.


