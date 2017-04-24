Pairwise alignments on assembly patches
=======================================

This document describes the process of running the pairwise alignment pipeline for only new patches of a species (currently human or mouse) against a selection of other species. 

Note that aligments which are currently BLASTZ_NET will have patches run using LASTZ_NET but they will have the same method_link_species_set_id as the BLASTZ_NET results.

Instructions
------------

1) Find the new patches

Run the script ``find_assembly_patches.pl`` using the latest core database and the previous core database to find just the newest patches.

::

    $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/find_assembly_patches.pl -new_core "mysql://ensro@ens-staging1:3306/homo_sapiens_core_68_37?group=core&species=homo_sapiens" -prev_core "mysql://ensro@ens-livemirror:3306/homo_sapiens_core_67_37?group=core&species=homo_sapiens"

This produces output like:

::

    NEW patches
      HG871_PATCH 1000759274 2012-04-27 12:12:07
      HG1292_PATCH 1000759258 2012-04-27 12:12:07
      HG1293_PATCH 1000759262 2012-04-27 12:12:07
      HG1304_PATCH 1000759268 2012-04-27 12:12:07
      HG962_PATCH 1000759272 2012-04-27 12:12:07
      HSCHR3_1_CTG1 1000759264 2012-04-27 12:12:07
      HG1287_PATCH 1000759260 2012-04-27 12:12:07
      HG1308_PATCH 1000759270 2012-04-27 12:12:07
      HG271_PATCH 1000759278 2012-04-27 12:12:07
      HG1322_PATCH 1000759266 2012-04-27 12:12:07
    CHANGED patches
      HG1211_PATCH new=1000759276 2012-04-27 12:12:07       prev=1000658983 2012-02-09 10:46:34
    DELETED patches
    
    Patches to delete: ("HG1211_PATCH")
    Input for create_patch_pairaligner_conf.pl:
    --patches chromosome:HG1287_PATCH,chromosome:HG1292_PATCH,chromosome:HG1322_PATCH,chromosome:HG962_PATCH,chromosome:HG1211_PATCH,chromosome:HG871_PATCH,chromosome:HG1304_PATCH,chromosome:HG1308_PATCH,chromosome:HG1293_PATCH,chromosome:HG271_PATCH,chromosome:HSCHR3_1_CTG1

2) Add the patches to the ensembl-compara-master database

   a) You may want to make a backup of the master first:

      ::

          mysqldump --opt -h compara1 -u ensro ensembl_compara_master > /path/to/dump/dir/ensembl_compara_master.dump

   b) Remove any dnafrags which have been CHANGED or DELETED. These are listed in "Patches to delete:" in the output above.

      .. code-block:: sql

          DELETE df FROM dnafrag df JOIN genome_db gdb USING (genome_db_id) WHERE gdb.name = "homo_sapiens" AND df.name IN ("HG1211_PATCH");

   c) Run update_genome.pl

      You need to use the --force option because we are adding additional dnafrags to an existing species

      ::

          perl $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/update_genome.pl --reg_conf $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/production_reg_conf.pl --compara compara_master --species human --force

      The registry configuration file needs to contain the information for the compara master.
      Check that these have been added.

3) Create the lastz.conf file.

This script currently only supports homo_sapiens and mus_musculus as "patched" species. If assembly patches become available for more species, an extra dna_collection will have to be implemented in the script, e.g.
``$dna_collection->{homo_sapiens_mammal}``

An additional dna_collection may be added to deal with species which require different parameters. The list of exception species (e.g. primates in the case of human) are defined by the ``--exception_species`` parameter.
By default, all the primates (species under the taxon ID 9443) are defined as exceptions when the patched species is human, and no exceptions are defined for mouse. The dna_collection is specied of the form (e.g.):
``$dna_collection->{homo_sapiens_exception}``

The default pair aligner options are defined in the variable $pair_aligner->{mammal} and for the exception_species, in ``$pair_aligner->{exception}``.

The list of patches to use is given in the output of the find_assembly_patches.pl script.

::

    perl $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/create_patch_pairaligner_conf.pl --reg_conf $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/production_reg_conf.pl --patched_species homo_sapiens --patches chromosome:HG1292_PATCH,chromosome:HG1287_PATCH,chromosome:HG1293_PATCH,chromosome:HG1322_PATCH,chromosome:HG1304_PATCH,chromosome:HG1308_PATCH,chromosome:HG962_PATCH,chromosome:HG871_PATCH,chromosome:HG1211_PATCH,chromosome:HG271_PATCH,chromosome:HSCHR3_1_CTG1 > lastz.conf

By default, the script will list all the species the "patched" species has alignments with, and select the ones that have chromosomes. You can use the --species parameter to define a list of your own, e.g.

::

  --species rattus_norvegicus,macaca_mulatta,pan_troglodytes,gallus_gallus,ornithorhynchus_anatinus,monodelphis_domestica,pongo_abelii,equus_caballus,bos_taurus,sus_scrofa,gorilla_gorilla,callithrix_jacchus,oryctolagus_cuniculus

Alternatively, you can use the ``--skip_species`` option to remove skip some species that are found automatically by the script (for instance, if you've just computed a full-scale pairwise alignment, the patches are probabyl already in).

By default, NIB files will be dumped into ``/lustre/scratch109/ensembl/$USER/scratch/hive/release_XX/nib_files/``. Use the ``--dump_dir`` option if you want it to be different.

By default, the script will search for core databases of the same version as the Core API. Use ``--ensembl_version`` if you want a specific version instead.

Options become tricky when the "patched" species is not the reference used in the alignment (e.g. the human-vs-mouse alignment uses human as the reference but the patches may be on the mosue side). For mouse patches, the script needs to be called twice:

- once with ``--skip_species homo_sapiens`` to generate the config file that will align the new mouse patches to every species except human
- once with ``--patched_species_is_alignment_reference 0 --species homo_sapiens`` to generate the config file that will align all the human chromosomes to the mouse patches (mouse is the non-reference species in the alignment)


NOTE: see below for the command-lines and the resulting lastz.conf used in e81 in which we had human and mouse patches

NOTE: You may get warnings for those pairwise alignments which are still BLASTZ_NET, ie are not yet LASTZ_NET. These can be ignored.

4) Run init_pipeline

Run the init_pipeline command, setting --conf_file to lastz.conf

::

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Lastz_conf --reg_conf $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/production_reg_conf.pl --conf_file lastz_patch_mouse_81.conf --pipeline_name lastz_mouse_patches_81 --patch_alignments 1

(assuming the password is defined in your environment variable $ENSADMIN_PSW)

5) Run the beekeeper

There are likely to be some health check failures. These are due to the health check expecting a percentage difference < 20% between the number of genomic_align_blocks of the current database and previous database. As it is comparing the patch against the full genome this difference is expected to be much higher. Hence, we ignore this failures for now. In the future, we will make the expected percentage difference a command line argument which can be change we are only running patches, thereby eliminating this Healthcheck failures.

6) Check results

   .. code-block:: sql

       select method_link_species_set_id, name, count(*) from genomic_align_block join method_link_species_set using (method_link_species_set_id) where method_link_id in (1,16) group by method_link_species_set_id;

7) Add to release database. Documentation in the Release Document.

8) Remove alignments on CHANGED or DELETED patches from the release database:

   For instance, for dnafrag_id=13705533

   .. code-block:: sql

      SELECT COUNT(*) FROM genomic_align WHERE dnafrag_id=13705533;
      # 608
      SELECT COUNT(*) FROM genomic_align ga1, genomic_align ga2, genomic_align_block gab WHERE ga1.dnafrag_id=13705533 AND ga1.genomic_align_block_id = ga2.genomic_align_block_id AND ga1.genomic_align_id != ga2.genomic_align_id AND  ga1.genomic_align_block_id = gab.genomic_align_block_id;
      # 608
      DELETE ga1, ga2, gab FROM genomic_align ga1, genomic_align ga2, genomic_align_block gab WHERE ga1.dnafrag_id=13705533 AND ga1.genomic_align_block_id = ga2.genomic_align_block_id AND ga1.genomic_align_id != ga2.genomic_align_id AND ga1.genomic_align_block_id = gab.genomic_align_block_id;
      # 608*3 = 1824

Example files
-------------

Command lines
~~~~~~~~~~~~~

::

    # human patches vs * chromosomes
    perl $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/create_patch_pairaligner_conf.pl --reg_conf $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/production_reg_conf.pl --patched_species homo_sapiens --patches chromosome:CHR_HSCHR15_6_CTG8,chromosome:CHR_HG2290_PATCH,chromosome:CHR_HG1651_PATCH,chromosome:CHR_HSCHR16_3_CTG3_1,chromosome:CHR_HG2237_PATCH,chromosome:CHR_HG2235_PATCH,chromosome:CHR_HG1342_HG2282_PATCH,chromosome:CHR_HG2239_PATCH > lastz_patch_human_81.conf

    # mouse patches vs * chromosomes (except human)
    perl $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/create_patch_pairaligner_conf.pl --reg_conf $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/production_reg_conf.pl --patched_species mus_musculus --patches chromosome:CHR_MG3231_PATCH,chromosome:CHR_MG4265_PATCH,chromosome:CHR_MG4259_PATCH,chromosome:CHR_MG4266_PATCH,chromosome:CHR_MG4248_PATCH,chromosome:CHR_MG3561_PATCH,chromosome:CHR_MG4254_PATCH,chromosome:CHR_MG3609_PATCH,chromosome:CHR_MG3562_PATCH,chromosome:CHR_MG117_PATCH,chromosome:CHR_MG4255_PATCH,chromosome:CHR_MG132_PATCH,chromosome:CHR_MG4261_PATCH,chromosome:CHR_MG4249_PATCH,chromosome:CHR_MG4264_PATCH --skip_species homo_sapiens > lastz_patch_mouse_81a.conf

    # human chromosomes vs mouse patches
    perl $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/create_patch_pairaligner_conf.pl --reg_conf $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/production_reg_conf.pl --patched_species mus_musculus --patches chromosome:CHR_MG3231_PATCH,chromosome:CHR_MG4265_PATCH,chromosome:CHR_MG4259_PATCH,chromosome:CHR_MG4266_PATCH,chromosome:CHR_MG4248_PATCH,chromosome:CHR_MG3561_PATCH,chromosome:CHR_MG4254_PATCH,chromosome:CHR_MG3609_PATCH,chromosome:CHR_MG3562_PATCH,chromosome:CHR_MG117_PATCH,chromosome:CHR_MG4255_PATCH,chromosome:CHR_MG132_PATCH,chromosome:CHR_MG4261_PATCH,chromosome:CHR_MG4249_PATCH,chromosome:CHR_MG4264_PATCH --patched_species_is_alignment_reference 0 --species homo_sapiens > lastz_patch_mouse_81b.conf

    # initialize a pipeline
    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Lastz_conf --reg_conf $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/production_reg_conf.pl --conf_file {lastz_patch_???.conf} --pipeline_name {lastz_???_patches_81} --patch_alignments 1



lastz_patch_mouse_81b.conf
~~~~~~~~~~~~~~~~~~~~~~~~~~

::

    [
    {TYPE => SPECIES,
      'abrev'          => 'homo_sapiens',
      'genome_db_id'   => 150,
      'taxon_id'       => 9606,
      'phylum'         => 'Vertebrata',
      'module'         => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
      'host'           => 'ens-staging1',
      'port'           => '3306',
      'user'           => 'ensro',
      'dbname'         => 'homo_sapiens_core_81_38',
      'species'        => 'homo_sapiens',
    },
    {TYPE => SPECIES,
      'abrev'          => 'mus_musculus',
      'genome_db_id'   => 134,
      'taxon_id'       => 10090,
      'phylum'         => 'Vertebrata',
      'module'         => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
      'host'           => 'ens-staging2',
      'port'           => '3306',
      'user'           => 'ensro',
      'dbname'         => 'mus_musculus_core_81_38',
      'species'        => 'mus_musculus',
    },
    {TYPE => DNA_COLLECTION,
     'collection_name'       => 'homo_sapiens exception',
     'genome_db_id'          => 150,
     'genome_name_assembly'  => 'homo_sapiens:GRCh38',
     'chunk_size'            => 30000000,
     'overlap'               => 0,
     'include_non_reference' => 0,
     'masking_options'       => "{default_soft_masking => 1}"
    },
    {TYPE => DNA_COLLECTION,
     'collection_name'       => 'homo_sapiens mammal',
     'genome_db_id'          => 150,
     'genome_name_assembly'  => 'homo_sapiens:GRCh38',
     'chunk_size'            => 30000000,
     'overlap'               => 0,
     'include_non_reference' => 0,
     'masking_options_file'  => '/nfs/users/nfs_m/mm14/workspace/src/ensembl/ensembl-compara/scripts/pipeline/human36.spec'
    },
    { TYPE => DNA_COLLECTION,
     'collection_name'      => 'mus_musculus all',
     'genome_db_id'         => 134,
     'genome_name_assembly' => 'mus_musculus:GRCm38',
     'region'               => 'chromosome:CHR_MG3231_PATCH,chromosome:CHR_MG4265_PATCH,chromosome:CHR_MG4259_PATCH,chromosome:CHR_MG4266_PATCH,chromosome:CHR_MG4248_PATCH,chromosome:CHR_MG3561_PATCH,chromosome:CHR_MG4254_PATCH,chromosome:CHR_MG3609_PATCH,chromosome:CHR_MG3562_PATCH,chromosome:CHR_MG117_PATCH,chromosome:CHR_MG4255_PATCH,chromosome:CHR_MG132_PATCH,chromosome:CHR_MG4261_PATCH,chromosome:CHR_MG4249_PATCH,chromosome:CHR_MG4264_PATCH',
     'chunk_size'           => 10100000,
     'group_set_size'       => 10100000,
     'overlap'              => 100000,
     'masking_options'      => "{default_soft_masking => 1}",
     'include_non_reference' => 1,
    },
    { TYPE => PAIR_ALIGNER,
     'logic_name_prefix'             => 'LastZ',
     'method_link'                   => [1001, 'LASTZ_RAW'],
     'analysis_template'             => {
        '-program'                   => 'lastz',
        '-parameters'                => "{method_link=>'LASTZ_RAW',options=>'T=1 K=3000 L=3000 H=2200 O=400 E=30 --ambiguous=iupac'}",
        '-module'                    => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::LastZ',
     },
     'max_parallel_workers'          => 100,
     'batch_size'                    => 10,
     'non_reference_collection_name' => 'mus_musculus all',
     'reference_collection_name'     => 'homo_sapiens mammal',
    },
    { TYPE => DNA_COLLECTION,
     'collection_name'       => 'homo_sapiens for chain',
     'genome_db_id'          => 150,
     'genome_name_assembly'  => 'homo_sapiens:GRCh38',
     'include_non_reference' => 0,
     'dump_loc'              => '/lustre/scratch109/ensembl/mm14/scratch/hive/release_81/nib_files//homo_sapiens_nib_for_chain'
    },
    { TYPE => DNA_COLLECTION,
     'collection_name'       => 'mus_musculus for chain',
     'genome_db_id'          => 134,
     'genome_name_assembly'  => 'mus_musculus:GRCm38',
     'region'                => 'chromosome:CHR_MG3231_PATCH,chromosome:CHR_MG4265_PATCH,chromosome:CHR_MG4259_PATCH,chromosome:CHR_MG4266_PATCH,chromosome:CHR_MG4248_PATCH,chromosome:CHR_MG3561_PATCH,chromosome:CHR_MG4254_PATCH,chromosome:CHR_MG3609_PATCH,chromosome:CHR_MG3562_PATCH,chromosome:CHR_MG117_PATCH,chromosome:CHR_MG4255_PATCH,chromosome:CHR_MG132_PATCH,chromosome:CHR_MG4261_PATCH,chromosome:CHR_MG4249_PATCH,chromosome:CHR_MG4264_PATCH',
     'include_non_reference' => 1,
     'dump_loc'              => '/lustre/scratch109/ensembl/mm14/scratch/hive/release_81/nib_files//mus_musculus_nib_for_chain'
    },
    {TYPE                            => CHAIN_CONFIG,
     'input_method_link'             => [1001, 'LASTZ_RAW'],
     'output_method_link'            => [1002, 'LASTZ_CHAIN'],
     'reference_collection_name'     => 'homo_sapiens for chain',
     'non_reference_collection_name' => 'mus_musculus for chain',
     'max_gap'                       => 50,
     'linear_gap'                    => 'medium'
    },
    { TYPE                           => NET_CONFIG,
     'input_method_link'             => [1002, 'LASTZ_CHAIN'],
     'output_method_link'            => [16, 'LASTZ_NET'],
     'reference_collection_name'     => 'homo_sapiens for chain',
     'non_reference_collection_name' => 'mus_musculus for chain',
     'max_gap'                       => 50,
     'input_group_type'              => 'chain',
     'output_group_type'             => 'default',
    },
    { TYPE => END }
    ]


lastz_patch_human_81.conf
~~~~~~~~~~~~~~~~~~~~~~~~~

.. note:: This file has been edited ... only human vs macaque and stickleback below, but other species (incl. mouse) have the same structure
   macaque is an "exception", i.e. has different settings than stickleback

::

    [
    {TYPE => SPECIES,
      'abrev'          => 'homo_sapiens',
      'genome_db_id'   => 150,
      'taxon_id'       => 9606,
      'phylum'         => 'Vertebrata',
      'module'         => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
      'host'           => 'ens-staging1',
      'port'           => '3306',
      'user'           => 'ensro',
      'dbname'         => 'homo_sapiens_core_81_38',
      'species'        => 'homo_sapiens',
    },
    {TYPE => SPECIES,
      'abrev'          => 'macaca_mulatta',
      'genome_db_id'   => 31,
      'taxon_id'       => 9544,
      'phylum'         => 'Vertebrata',
      'module'         => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
      'host'           => 'ens-staging1',
      'port'           => '3306',
      'user'           => 'ensro',
      'dbname'         => 'macaca_mulatta_core_81_10',
      'species'        => 'macaca_mulatta',
    },
    {TYPE => SPECIES,
      'abrev'          => 'gasterosteus_aculeatus',
      'genome_db_id'   => 36,
      'taxon_id'       => 69293,
      'phylum'         => 'Vertebrata',
      'module'         => 'Bio::EnsEMBL::DBSQL::DBAdaptor',
      'host'           => 'ens-staging1',
      'port'           => '3306',
      'user'           => 'ensro',
      'dbname'         => 'gasterosteus_aculeatus_core_81_1',
      'species'        => 'gasterosteus_aculeatus',
    },
    (... other species ...)
    {TYPE => DNA_COLLECTION,
     'collection_name'       => 'homo_sapiens exception',
     'genome_db_id'          => 150,
     'genome_name_assembly'  => 'homo_sapiens:GRCh38',
     'region'                => 'chromosome:CHR_HSCHR15_6_CTG8,chromosome:CHR_HG2290_PATCH,chromosome:CHR_HG1651_PATCH,chromosome:CHR_HSCHR16_3_CTG3_1,chromosome:CHR_HG2237_PATCH,chromosome:CHR_HG2235_PATCH,chromosome:CHR_HG1342_HG2282_PATCH,chromosome:CHR_HG2239_PATCH',
     'chunk_size'            => 30000000,
     'overlap'               => 0,
     'include_non_reference' => 1,
     'masking_options'       => "{default_soft_masking => 1}"
    },
    {TYPE => DNA_COLLECTION,
     'collection_name'       => 'homo_sapiens mammal',
     'genome_db_id'          => 150,
     'genome_name_assembly'  => 'homo_sapiens:GRCh38',
     'region'                => 'chromosome:CHR_HSCHR15_6_CTG8,chromosome:CHR_HG2290_PATCH,chromosome:CHR_HG1651_PATCH,chromosome:CHR_HSCHR16_3_CTG3_1,chromosome:CHR_HG2237_PATCH,chromosome:CHR_HG2235_PATCH,chromosome:CHR_HG1342_HG2282_PATCH,chromosome:CHR_HG2239_PATCH',
     'chunk_size'            => 30000000,
     'overlap'               => 0,
     'include_non_reference' => 1,
     'masking_options_file'  => '/nfs/users/nfs_m/mm14/workspace/src/ensembl/ensembl-compara/scripts/pipeline/human36.spec'
    },
    { TYPE => DNA_COLLECTION,
     'collection_name'      => 'macaca_mulatta all',
     'genome_db_id'         => 31,
     'genome_name_assembly' => 'macaca_mulatta:MMUL_1',
     'chunk_size'           => 10100000,
     'group_set_size'       => 10100000,
     'overlap'              => 100000,
     'masking_options'      => "{default_soft_masking => 1}",
    },
    (... other exceptions ...)
    { TYPE => DNA_COLLECTION,
     'collection_name'      => 'gasterosteus_aculeatus all',
     'genome_db_id'         => 36,
     'genome_name_assembly' => 'gasterosteus_aculeatus:BROADS1',
     'chunk_size'           => 10100000,
     'group_set_size'       => 10100000,
     'overlap'              => 100000,
     'masking_options'      => "{default_soft_masking => 1}",
    },
    (... other non-exceptions ...)
    { TYPE => PAIR_ALIGNER,
     'logic_name_prefix'             => 'LastZ',
     'method_link'                   => [1001, 'LASTZ_RAW'],
     'analysis_template'             => {
        '-program'                   => 'lastz',
        '-parameters'                => "{method_link=>'LASTZ_RAW',options=>'T=1 K=5000 L=5000 H=3000 M=10 O=400 E=30 Q=/nfs/users/nfs_m/mm14/workspace/src/ensembl/ensembl-compara/scripts/pipeline/primate.matrix --ambiguous=iupac'}",
        '-module'                    => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::LastZ',
     },
     'max_parallel_workers'          => 100,
     'batch_size'                    => 10,
     'non_reference_collection_name' => 'macaca_mulatta all',
     'reference_collection_name'     => 'homo_sapiens exception',
    },
    (... other exceptions ...)
    { TYPE => PAIR_ALIGNER,
     'logic_name_prefix'             => 'LastZ',
     'method_link'                   => [1001, 'LASTZ_RAW'],
     'analysis_template'             => {
        '-program'                   => 'lastz',
        '-parameters'                => "{method_link=>'LASTZ_RAW',options=>'T=1 K=3000 L=3000 H=2200 O=400 E=30 --ambiguous=iupac'}",
        '-module'                    => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::LastZ',
     },
     'max_parallel_workers'          => 100,
     'batch_size'                    => 10,
     'non_reference_collection_name' => 'gasterosteus_aculeatus all',
     'reference_collection_name'     => 'homo_sapiens mammal',
    },
    (... other non-exceptions ...)
    { TYPE => DNA_COLLECTION,
     'collection_name'       => 'homo_sapiens for chain',
     'genome_db_id'          => 150,
     'genome_name_assembly'  => 'homo_sapiens:GRCh38',
     'region'                => 'chromosome:CHR_HSCHR15_6_CTG8,chromosome:CHR_HG2290_PATCH,chromosome:CHR_HG1651_PATCH,chromosome:CHR_HSCHR16_3_CTG3_1,chromosome:CHR_HG2237_PATCH,chromosome:CHR_HG2235_PATCH,chromosome:CHR_HG1342_HG2282_PATCH,chromosome:CHR_HG2239_PATCH',
     'include_non_reference' => 1,
     'dump_loc'              => '/lustre/scratch109/ensembl/mm14/scratch/hive/release_81/nib_files//homo_sapiens_nib_for_chain'
    },
    { TYPE => DNA_COLLECTION,
     'collection_name'       => 'macaca_mulatta for chain',
     'genome_db_id'          => 31,
     'genome_name_assembly'  => 'macaca_mulatta:MMUL_1',
     'dump_loc'              => '/lustre/scratch109/ensembl/mm14/scratch/hive/release_81/nib_files//macaca_mulatta_nib_for_chain'
    },
    { TYPE => DNA_COLLECTION,
     'collection_name'       => 'gasterosteus_aculeatus for chain',
     'genome_db_id'          => 36,
     'genome_name_assembly'  => 'gasterosteus_aculeatus:BROADS1',
     'dump_loc'              => '/lustre/scratch109/ensembl/mm14/scratch/hive/release_81/nib_files//gasterosteus_aculeatus_nib_for_chain'
    },
    (... other species ...)
    {TYPE                            => CHAIN_CONFIG,
     'input_method_link'             => [1001, 'LASTZ_RAW'],
     'output_method_link'            => [1002, 'LASTZ_CHAIN'],
     'reference_collection_name'     => 'homo_sapiens for chain',
     'non_reference_collection_name' => 'macaca_mulatta for chain',
     'max_gap'                       => 50,
     'linear_gap'                    => 'medium'
    },
    {TYPE                            => CHAIN_CONFIG,
     'input_method_link'             => [1001, 'LASTZ_RAW'],
     'output_method_link'            => [1002, 'LASTZ_CHAIN'],
     'reference_collection_name'     => 'homo_sapiens for chain',
     'non_reference_collection_name' => 'gasterosteus_aculeatus for chain',
     'max_gap'                       => 50,
     'linear_gap'                    => 'medium'
    },
    (... other species ...)
    { TYPE                           => NET_CONFIG,
     'input_method_link'             => [1002, 'LASTZ_CHAIN'],
     'output_method_link'            => [16, 'LASTZ_NET'],
     'reference_collection_name'     => 'homo_sapiens for chain',
     'non_reference_collection_name' => 'macaca_mulatta for chain',
     'max_gap'                       => 50,
     'input_group_type'              => 'chain',
     'output_group_type'             => 'default',
    },
    { TYPE                           => NET_CONFIG,
     'input_method_link'             => [1002, 'LASTZ_CHAIN'],
     'output_method_link'            => [16, 'LASTZ_NET'],
     'reference_collection_name'     => 'homo_sapiens for chain',
     'non_reference_collection_name' => 'gasterosteus_aculeatus for chain',
     'max_gap'                       => 50,
     'input_group_type'              => 'chain',
     'output_group_type'             => 'default',
    },
    (... other species ...)
    { TYPE => END }
    ]

