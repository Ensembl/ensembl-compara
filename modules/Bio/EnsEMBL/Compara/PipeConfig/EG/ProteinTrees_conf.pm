=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::EG::ProteinTrees_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EG::ProteinTrees_conf -host mysql-ens-compara-prod-X -port XXXX \
        -division <eg_division> -mlss_id <curr_ptree_mlss_id>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output


=head1 DESCRIPTION

The PipeConfig example file for Ensembl Genomes group's version of
ProteinTrees pipeline. This file is inherited from & customised further
within the Ensembl Genomes infrastructure but this file serves as
an example of the type of configuration we perform.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EG::ProteinTrees_conf;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Utils ('stringify');

use base ('Bio::EnsEMBL::Compara::PipeConfig::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # custom pipeline name
        # Used to prefix the database name (in HiveGeneric_conf)
        # Define rel_suffix for re-runs of the pipeline
        'pipeline_name' => $self->o('division').'_hom_'.$self->o('eg_release').'_'.$self->o('ensembl_release').$self->o('rel_suffix'),

    # data directories:
        'work_dir'              => '/nfs/nobackup/ensemblgenomes/'.$ENV{'USER'}.'/compara/ensembl_compara_'. $self->o('pipeline_name'),

    # homology_dnds parameters:
        # used by 'homology_dNdS'
        'taxlevels'                 => [],  # this is the default default
        'taxlevels_fungi'           => ['Botryosphaeriales', 'Calosphaeriales', 'Capnodiales', 'Chaetothyriales', 'Dothideales', 'Erysiphales', 'Eurotiales', 'Glomerellales', 'Helotiales', 'Hypocreales', 'Microascales', 'Onygenales', 'Ophiostomatales', 'Orbiliales', 'Pleosporales', 'Pneumocystidales', 'Saccharomycetales', 'Sordariales', 'Verrucariales', 'Xylariales', 'Venturiales', 'Agaricales', 'Atheliales', 'Boletales', 'Cantharellales', 'Corticiales', 'Dacrymycetales', 'Geastrales', 'Georgefischeriales', 'Gloeophyllales', 'Jaapiales', 'Malasseziales', 'Mixiales', 'Polyporales', 'Russulales', 'Sebacinales', 'Sporidiobolales', 'Tremellales', 'Ustilaginales', 'Wallemiales', 'Cryptomycota', 'Glomerales ', 'Rhizophydiales'],
        'taxlevels_metazoa'         => ['Drosophila' ,'Hymenoptera', 'Nematoda'],
        'taxlevels_protists'        => ['Alveolata', 'Amoebozoa', 'Choanoflagellida', 'Cryptophyta', 'Fornicata', 'Haptophyceae', 'Kinetoplastida', 'Rhizaria', 'Rhodophyta', 'Stramenopiles'],
        'taxlevels_vb'              => ['Calyptratae', 'Culicidae'],

    # hive_capacity values for some analyses:
        'blastp_capacity'           => 200,
        'blastpu_capacity'          => 100,
        'split_genes_capacity'      => 200,
        'cluster_tagging_capacity'  => 200,
        'homology_dNdS_capacity'    => 200,
        'treebest_capacity'         => 200,
        'ortho_tree_capacity'       => 200,
        'quick_tree_break_capacity' => 100,
        'goc_capacity'              => 200,
        'goc_stats_capacity'        =>  15,
        'other_paralogs_capacity'   => 100,
        'mcoffee_short_capacity'    => 200,
        'hc_capacity'               =>   4,
        'decision_capacity'         =>   4,

    # connection parameters to various databases:

        # the production database itself (will be created)
        # it inherits most of the properties from HiveGeneric, we usually only need to redefine the host, but you may want to also redefine 'port'
        'dbowner' => 'ensembl_compara',

        # the master database for synchronization of various ids (use undef if you don't have a master database)
        'master_db' => 'mysql://ensro@mysql-eg-pan-1.ebi.ac.uk:4276/ensembl_compara_master',

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

    # CAFE parameters
        # Do we want to initialise the CAFE part now ?
        'do_cafe'                   => 0,
        #Use Timetree divergence times for the CAFETree internal nodes
        'use_timetree_times'        => 0,

    # GOC parameters
        'goc_taxlevels'             => [],  # this is the default default
        'goc_taxlevels_fungi'       => [],
        'goc_taxlevels_metazoa'     => ['Diptera', 'Hymenoptera', 'Nematoda'],
        'goc_taxlevels_protists'    => [],
        'goc_taxlevels_vb'          => ['Chelicerata', 'Diptera', 'Hemiptera'],

    # Extra analyses
        # compute dNdS for homologies?
        'do_dnds'                => 1,
        # Do we want the Gene QC part to run ?
        'do_gene_qc'             => 0,
        # Do we extract overall statistics for each pair of species ?
        'do_homology_stats'      => 0,
        # Do we need a mapping between homology_ids of this database to another database ?
        'do_homology_id_mapping' => 0,
        # homology dumps options
        'prev_homology_dumps_dir'   => undef,
        'homology_dumps_shared_dir' => undef,

    # HighConfidenceOrthologs Parameters
        # In this structure, the "thresholds" are for resp. the GOC score, the WGA coverage and %identity
        'threshold_levels' => [
            {
                'taxa'          => [ 'Apes', 'Murinae' ],
                'thresholds'    => [ 75, 75, 80 ],
            },
            {
                'taxa'          => [ 'Mammalia', 'Aves', 'Percomorpha' ],
                'thresholds'    => [ 75, 75, 50 ],
            },
            {
                'taxa'          => [ 'Euteleostomi', 'Ciona' ],
                'thresholds'    => [ 50, 50, 25 ],
            },
            {
                'taxa'          => [ 'Panicoideae', 'Oryzinae', 'Pooideae', 'Solanaceae', 'Brassicaceae', 'Malvaceae', 'fabids' ],
                'thresholds'    => [ 50, 50, 25 ],
            },
            {
                'taxa'          => [ 'Aculeata', 'Anophelinae', 'Caenorhabditis', 'Drosophila', 'Glossinidae', 'Onchocercidae' ],
                'thresholds'    => [ 50, 50, 25 ],
            },
            {
                'taxa'          => [ 'Brachycera', 'Culicinae', 'Hemiptera', 'Phlebotominae' ],
                'thresholds'    => [ 25, 25, 25 ],
            },
            {
                'taxa'          => [ 'Chelicerata', 'Diptera', 'Hymenoptera', 'Nematoda' ],
                'thresholds'    => [ undef, undef, 25 ],
            },
            {
                'taxa'          => [ 'all' ],
                'thresholds'    => [ undef, undef, 25 ],
            },
        ],
    };
}


sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    ## Extend this section to redefine the resource names of some analysis
    ## Here we bump the resource class of some commonly MEMLIMIT failing analyses.
    $analyses_by_name->{'mcoffee'}->{'-rc_name'} = '8Gb_job';
    $analyses_by_name->{'mcoffee_himem'}->{'-rc_name'} = '32Gb_job';
    $analyses_by_name->{'mafft'}->{'-rc_name'} = '8Gb_2c_job';
    $analyses_by_name->{'mafft_himem'}->{'-rc_name'} = '32Gb_4c_job';
    $analyses_by_name->{'treebest'}->{'-rc_name'} = '4Gb_job';
    $analyses_by_name->{'ortho_tree_himem'}->{'-rc_name'} = '4Gb_job';
    $analyses_by_name->{'members_against_allspecies_factory'}->{'-rc_name'} = '2Gb_job';
    $analyses_by_name->{'members_against_nonreusedspecies_factory'}->{'-rc_name'} = '2Gb_job';

    if ($self->o('division') eq 'fungi') {
        $analyses_by_name->{'unannotated_all_vs_all_factory'}->{'-parameters'}->{'num_sequences_per_blast_job'} = 5000;
        $analyses_by_name->{'members_against_allspecies_factory'}->{'-parameters'}->{'num_sequences_per_blast_job'} = 5000;
        $analyses_by_name->{'members_against_allspecies_factory'}->{'-parameters'}->{'num_sequences_per_blast_job'} = 5000;
    }
    
    $analyses_by_name->{'set_default_values'}->{'-parameters'}->{'clusterset_id'} = $self->default_options()->{'collection'};

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
