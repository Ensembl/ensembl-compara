Import of the NCBI Taxonomy
===========================


#. Loading of a fresh ncbi_taxonomy database is now done by initializing and running a small Hive pipeline.
   Make sure you have ensembl, ensembl-hive and ensembl-compara checked out into $ENSEMBL_CVS_ROOT_DIR

#. Edit ``$ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/taxonomy/ensembl_aliases.sql`` to ensembl aliases if needed.

   The file needs to be updated as new species are integrated into Ensembl.

   .. note: The following is only used by Compara and Production does not need to update them

    For the Compara analysis, the ancestral species must have an "ensembl timetree mya" tag,
    which usually comes from the TimeTree database (http://www.timetree.org).
    Unfortunately, the website is not able to give the age of an ancestral species directly.
    You will have to enter two extant species that have that ancestral species as their last common ancestor.
 
#. Edit ``$ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/taxonomy/web_name_patches.sql`` to patch web names if needed.

   This should be agreed with the web team or just take the one they have chosen from the pre site.

   .. warning: This, again, must be updated with the retirement of some keys

#. Initialize the pipeline (make sure you have deleted the previous version of the database or are using another suffix):

   ::

      init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::ImportNCBItaxonomy_conf -password <your_password> -ensembl_cvs_root_dir <path_to_your_ensembl_cvs_root>

#. Run the pipeline:

   ::

       beekeeper.pl ... # specific command line(s) will be printed by init_pipeline.pl

#. Clean up the target database by removing hive tables:

   ::

       mysql .... (specific connection parameters printed by init_pipeline.pl) -e 'call drop_hive_tables

   You may drop the analysis_description, analysis and meta tables "by hand".

