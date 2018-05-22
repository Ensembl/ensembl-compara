=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::EBI::EG::ProteinTrees_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::EG::ProteinTrees_conf \
        -password <your_password> -mlss_id <your_current_PT_mlss_id> \
        -division <eg_division> -eg_release <egrelease>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output


=head1 DESCRIPTION

    The PipeConfig example file for Ensembl Genomes group's version of
    ProteinTrees pipeline. This file is inherited from & customised further
    within the Ensembl Genomes infrastructure but this file serves as
    an example of the type of configuration we perform.

=head1 CONTACT

  Please contact Compara or Ensembl Genomes with questions/suggestions

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::EG::ProteinTrees_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Utils ('stringify');

use base ('Bio::EnsEMBL::Compara::PipeConfig::EBI::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # User details

    # parameters that are likely to change from execution to another:
        # It is very important to check that this value is current (commented out to make it obligatory to specify)
        #mlss_id => 40043,
        # names of species we don't want to reuse this time
        'do_not_reuse_list' => [],

    # custom pipeline name, in case you don't like the default one
        # Used to prefix the database name (in HiveGeneric_conf)
        # Define rel_suffix for re-runs of the pipeline
        pipeline_name => $self->o('division').'_hom_'.$self->o('eg_release').'_'.$self->o('ensembl_release').$self->o('rel_suffix'),

    # dependent parameters: updating 'base_dir' should be enough
        'base_dir'              =>  '/nfs/nobackup/ensemblgenomes/'.$self->o('ENV', 'USER').'/compara/ensembl_compara_',

    # "Member" parameters:
        'allow_ambiguity_codes'     => 1,

    # blast parameters:
        'num_sequences_per_blast_job'   => 5000,
        # cdhit is used to filter out proteins that are too close to each other
        'cdhit_identity_threshold' => 0.99,

    # clustering parameters:

    # tree building parameters:

    # alignment filtering options

    # species tree reconciliation

    # homology_dnds parameters:
        # used by 'homology_dNdS'
        'taxlevels'                 => [],  # this is the default default
        'taxlevels_fungi'           => ['Botryosphaeriales', 'Calosphaeriales', 'Capnodiales', 'Chaetothyriales', 'Dothideales', 'Erysiphales', 'Eurotiales', 'Glomerellales', 'Helotiales', 'Hypocreales', 'Microascales', 'Onygenales', 'Ophiostomatales', 'Orbiliales', 'Pleosporales', 'Pneumocystidales', 'Saccharomycetales', 'Sordariales', 'Verrucariales', 'Xylariales', 'Venturiales', 'Agaricales', 'Atheliales', 'Boletales', 'Cantharellales', 'Corticiales', 'Dacrymycetales', 'Geastrales', 'Georgefischeriales', 'Gloeophyllales', 'Jaapiales', 'Malasseziales', 'Mixiales', 'Polyporales', 'Russulales', 'Sebacinales', 'Sporidiobolales', 'Tremellales', 'Ustilaginales', 'Wallemiales', 'Cryptomycota', 'Glomerales ', 'Rhizophydiales'],
        'taxlevels_metazoa'         => ['Drosophila' ,'Hymenoptera', 'Nematoda'],
        'taxlevels_plants'          => ['Liliopsida', 'eudicotyledons', 'Chlorophyta'],
        'taxlevels_protists'        => ['Alveolata', 'Amoebozoa', 'Choanoflagellida', 'Cryptophyta', 'Fornicata', 'Haptophyceae', 'Kinetoplastida', 'Rhizaria', 'Rhodophyta', 'Stramenopiles'],
        'taxlevels_vb'              => ['Calyptratae', 'Culicidae'],

    # mapping parameters:
        'do_stable_id_mapping'      => 1,
        'do_treefam_xref'           => 1,
        # The TreeFam release to map to
        'tf_release'                => '9_69',

    # executable locations:

    # HMM specific parameters (set to 0 or undef if not in use)
        'hmm_library_basedir'       => '/hps/nobackup/production/ensembl/compara_ensembl/treefam_hmms/2015-12-18',

    # hive_capacity values for some analyses:
        'reuse_capacity'            =>   3,
        'blast_factory_capacity'    =>  50,
        'blastp_capacity'           => 200,
        'blastpu_capacity'          => 100,
        'mcoffee_capacity'          => 200,
        'split_genes_capacity'      => 200,
        'alignment_filtering_capacity'  => 200,
        'prottest_capacity'         => 200,
        'treebest_capacity'         => 200,
        'raxml_capacity'            => 200,
        'examl_capacity'            => 400,
        'notung_capacity'           => 200,
        'ortho_tree_capacity'       => 200,
        'quick_tree_break_capacity' => 100,
        'build_hmm_capacity'        => 200,
        'ktreedist_capacity'        => 150,
        'goc_capacity'              => 200,
        'goc_stats_capacity'        => 15,
        'genesetQC_capacity'        => 100,
        'other_paralogs_capacity'   => 100,
        'homology_dNdS_capacity'    => 200,
        'hc_capacity'               =>   4,
        'decision_capacity'         =>   4,
        'hc_post_tree_capacity'     => 100,
        'HMMer_classify_capacity'   => 400,
        'loadmembers_capacity'      =>  30,
        'HMMer_classifyPantherScore_capacity'   => 1000,
        'copy_trees_capacity'       => 50,
        'copy_alignments_capacity'  => 50,
        'mafft_update_capacity'     => 50,
        'raxml_update_capacity'     => 50,
        'ortho_stats_capacity'      => 10,
        'copy_tree_capacity'        => 100,
        'cluster_tagging_capacity'  => 200,
        'cafe_capacity'             => 50,

    # hive priority for non-LOCAL health_check analysis:

    # connection parameters to various databases:

        # the production database itself (will be created)
        # it inherits most of the properties from HiveGeneric, we usually only need to redefine the host, but you may want to also redefine 'port'
        'dbowner' => 'ensembl_compara',

        # the master database for synchronization of various ids (use undef if you don't have a master database)
        'master_db' => 'mysql://ensro@mysql-eg-pan-1.ebi.ac.uk:4276/ensembl_compara_master',
        'master_db_is_missing_dnafrags' => 1,

    ######## THESE ARE PASSED INTO LOAD_REGISTRY_FROM_DB SO PASS IN DB_VERSION
    ######## ALSO RAISE THE POINT ABOUT LOAD_FROM_MULTIPLE_DBs

    prod_1 => {
      -host   => 'mysql-eg-prod-1.ebi.ac.uk',
      -port   => 4238,
      -user   => 'ensro',
      -db_version => $self->o('ensembl_release')
    },

    staging_1 => {
      -host   => 'mysql-eg-staging-1.ebi.ac.uk',
      -port   => 4160,
      -user   => 'ensro',
      -db_version => $self->o('ensembl_release')
    },

    staging_2 => {
      -host   => 'mysql-eg-staging-2.ebi.ac.uk',
      -port   => 4275,
      -user   => 'ensro',
      -db_version => $self->o('ensembl_release')
    },

        # NOTE: The databases referenced in the following arrays have to be hashes (not URLs)
        # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them
        'curr_core_sources_locs' => [ $self->o('prod_1') ],
        # Add the database entries for the core databases of the previous release
        'prev_core_sources_locs'   => [ $self->o('staging_1') ],

        # Add the database location of the previous Compara release. Use "undef" if running the pipeline without reuse
        'prev_rel_db' => undef,

    # Configuration of the pipeline worklow

        # How will the pipeline create clusters (families) ?
        # Possible values: 'blastp' (default), 'hmm', 'hybrid'
        #   'blastp' means that the pipeline will run a all-vs-all blastp comparison of the proteins and run hcluster to create clusters. This can take a *lot* of compute
        #   'hmm' means that the pipeline will run an HMM classification
        #   'hybrid' is like "hmm" except that the unclustered proteins go to a all-vs-all blastp + hcluster stage
        #   'topup' means that the HMM classification is reused from prev_rel_db, and topped-up with the updated / new species  >> UNIMPLEMENTED <<

        # How much the pipeline will try to reuse from "prev_rel_db"
        # Possible values: 'clusters' (default), 'blastp', 'members'
        #   'members' means that only the members are copied over, and the rest will be re-computed
        #   'hmms' is like 'members', but also copies the HMM profiles. It requires that the clustering mode is not 'blastp'  >> UNIMPLEMENTED <<
        #   'hmm_hits' is like 'hmms', but also copies the HMM hits  >> UNIMPLEMENTED <<
        #   'blastp' is like 'members', but also copies the blastp hits. It requires that the clustering mode is 'blastp'
        #   'clusters' is like 'hmm_hits' or 'blastp' (depending on the clustering mode), but also copies the clusters
        #   'alignments' is like 'clusters', but also copies the alignments  >> UNIMPLEMENTED <<
        #   'trees' is like 'alignments', but also copies the trees  >> UNIMPLEMENTED <<
        #   'homologies is like 'trees', but also copies the homologies  >> UNIMPLEMENTED <<

    # CAFE parameters

    # GOC parameters
        'goc_taxlevels'             => [],  # this is the default default
        'goc_taxlevels_fungi'       => [],
        'goc_taxlevels_metazoa'     => ['Diptera', 'Hymenoptera', 'Nematoda'],
        'goc_taxlevels_plants'      => [],
        'goc_taxlevels_protists'    => [],
        'goc_taxlevels_vb'          => ['Chelicerata', 'Diptera', 'Hemiptera'],

    # Extra analyses
        # Do we want the Gene QC part to run ?
        'do_gene_qc'                    => 0,
        # Do we extract overall statistics for each pair of species ?
        'do_homology_stats'             => 0,

    };
}


sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    ## Extend this section to redefine the resource names of some analysis

    ## Here we bump the resource class of some commonly MEMLIMIT
    ## failing analyses. Are these really EG specific?
    $analyses_by_name->{'mcoffee'}->{'-rc_name'} = '8Gb_job';
    $analyses_by_name->{'mcoffee'}->{'-parameters'}{'cmd_max_runtime'} = 82800;
    $analyses_by_name->{'mcoffee_himem'}->{'-rc_name'} = '32Gb_job';
    $analyses_by_name->{'mcoffee_himem'}->{'-parameters'}{'cmd_max_runtime'} = 82800;
    $analyses_by_name->{'mafft'}->{'-rc_name'} = '8Gb_job';
    $analyses_by_name->{'mafft_himem'}->{'-rc_name'} = '32Gb_job';
    $analyses_by_name->{'treebest'}->{'-rc_name'} = '4Gb_job';
    $analyses_by_name->{'ortho_tree_himem'}->{'-rc_name'} = '4Gb_job';
    $analyses_by_name->{'members_against_allspecies_factory'}->{'-rc_name'} = '2Gb_job';
    $analyses_by_name->{'members_against_nonreusedspecies_factory'}->{'-rc_name'} = '2Gb_job';

    # Some parameters can be division-specific
    if ($self->o('division') eq 'plants') {
        $analyses_by_name->{'dump_canonical_members'}->{'-rc_name'} = '500Mb_job';
        $analyses_by_name->{'blastp'}->{'-rc_name'} = '500Mb_job';
        $analyses_by_name->{'ktreedist'}->{'-rc_name'} = '4Gb_job';
    }

    # Leave this untouched: it is an extremely-hacky way of setting "taxlevels" to
    # a division-default only if it hasn't been redefined on the command line
    if (($self->o('division') !~ /^#:subst/) and (my $tl = $self->default_options()->{'taxlevels_'.$self->o('division')})) {
        if (stringify($self->default_options()->{'taxlevels'}) eq stringify($self->o('taxlevels'))) {
            $analyses_by_name->{'group_genomes_under_taxa'}->{'-parameters'}->{'taxlevels'} = $tl;
        }
    }
    if (($self->o('division') !~ /^#:subst/) and (my $tl = $self->default_options()->{'goc_taxlevels_'.$self->o('division')})) {
        if (stringify($self->default_options()->{'goc_taxlevels'}) eq stringify($self->o('goc_taxlevels'))) {
            $analyses_by_name->{'goc_group_genomes_under_taxa'}->{'-parameters'}->{'taxlevels'} = $tl;
            $analyses_by_name->{'rib_fire_homology_id_mapping'}->{'-parameters'}->{'goc_taxlevels'} = $tl;
            $analyses_by_name->{'rib_fire_goc'}->{'-parameters'}->{'taxlevels'} = $tl;
        }
    }
}


1;
