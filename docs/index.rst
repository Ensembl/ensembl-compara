.. ensembl_compara_doc documentation master file, created by
   sphinx-quickstart on Thu Dec 15 12:59:35 2016.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

.. Have a look at https://raw.githubusercontent.com/rtfd/readthedocs.org/master/docs/index.rst for inspiration

Welcome to the Ensembl Compara documentation
============================================

.. warning:: This is work in progress. The documentation is currently hosted on `Read
             The Docs`_ but this may change in the future. Watch out the changes !

The code is open source, and `available on GitHub`_.

.. _available on GitHub: http://github.com/Ensembl/ensembl-compara
.. _Read The Docs: http://ensembl-compara.readthedocs.io/

The main documentation is organized into a couple sections:

* :ref:`user-docs`
* :ref:`prod-docs`

.. _user-docs:

User documentation
==================

.. toctree::
   :caption: Perl API
   :maxdepth: 1

   api/README

.. toctree::
   :caption: Database schema
   :maxdepth: 1

   schema

.. _prod-docs:

Data-production documentation
=============================

.. toctree::
   :caption: Production concepts and preparation
   :maxdepth: 1

   production/READMEs/beekeeper.rst
   production/READMEs/master_database.rst
   production/READMEs/ncbi_taxonomy.rst

.. toctree::
   :caption: Production pipelines
   :maxdepth: 1

   production/READMEs/pair_aligner.rst
   production/READMEs/pair_aligner_patches.rst
   production/READMEs/whole_genome_synteny.rst
   production/READMEs/epo.rst
   production/READMEs/low_coverage_genome_aligner.rst
   production/READMEs/multi_align.dumps.rst
   production/READMEs/multiple_aligner.rst
   production/READMEs/base_age.rst
   production/READMEs/protein_trees.rst

.. toctree::
   :caption: Other documents
   :maxdepth: 1

   production/READMEs/stable_id_mapping.rst
   production/READMEs/test_db.md
   production/READMEs/import_ucsc_chain_net.rst

