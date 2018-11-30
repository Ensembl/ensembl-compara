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

Bio::EnsEMBL::Compara::PipeConfig::EBI::Plants::ProteinTrees_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::Plants::ProteinTrees_conf \
        -password <your_password> -mlss_id <your_current_PT_mlss_id> \
        -division <eg_division> -eg_release <egrelease>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output


=head1 DESCRIPTION

    The PipeConfig example file for the Plants version of
    ProteinTrees pipeline. This file is inherited from & customised further
    within the Ensembl Genomes infrastructure but this file serves as
    an example of the type of configuration we perform.

=head1 CONTACT

  Please contact Compara or Ensembl Genomes with questions/suggestions

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::Plants::ProteinTrees_conf;

use strict;
use warnings;


use base ('Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # release 94/EG41 plants settings
    division => 'plants',
    mlss_id  => 40138,
    eg_release => 41,


    # custom pipeline name, in case you don't like the default one
    pipeline_name => $self->o('division').'_prottrees_'.$self->o('eg_release').'_'.$self->o('rel_with_suffix'),


    # connection parameters to various databases:

    # the master database for synchronization of various ids (use undef if you don't have a master database)
    'master_db' => 'mysql://ensro@mysql-ens-compara-prod-5:4615/ensembl_compara_master_plants',

    'member_db' => 'mysql://ensro@mysql-ens-compara-prod-2:4522/muffato_load_members_95_plants',

    eg_prod_loc => {
      -host   => 'mysql-eg-prod-2',
      -port   => 4239,
      -user   => 'ensro',
      -db_version => $self->o('ensembl_release')
    },

    e_prod_loc => {
      -host   => 'mysql-ens-vertannot-staging',
      -port   => 4573,
      -user   => 'ensro',
      -db_version => $self->o('ensembl_release')
    },

    eg_mirror_loc => {
        -host   => 'mysql-eg-mirror',
        -port   => 4157,
        -user   => 'ensro',
        -db_version => 93,
    },
    e_mirror_loc => {
        -host   => 'mysql-ensembl-mirror',
        -port   => 4240,
        -user   => 'ensro',
        -db_version => 93,
    },

    # NOTE: The databases referenced in the following arrays have to be hashes (not URLs)
    # Add the database entries for the current and previous core databases
    'curr_core_sources_locs' => [ $self->o('eg_prod_loc'), $self->o('e_prod_loc') ],
    'prev_core_sources_locs'   => [ $self->o('eg_mirror_loc'), $self->o('e_mirror_loc') ],

    # Add the database location of the previous Compara release. Use "undef" if running the pipeline without reuse
    'prev_rel_db' => 'mysql://ensro@mysql-ens-compara-prod-5:4615/ensembl_compara_plants_41_94',

    # Points to the previous production database. Will be used for various GOC operations. Use "undef" if running the pipeline without reuse.
    'goc_reuse_db'=> 'mysql://ensro@mysql-ens-compara-prod-5:4615/ensembl_compara_plants_41_94',

    # How will the pipeline create clusters (families) ?
    # Possible values: 'blastp' (default), 'hmm', 'hybrid'
    #   'blastp' means that the pipeline will run a all-vs-all blastp comparison of the proteins and run hcluster to create clusters. This can take a *lot* of compute
    #   'hmm' means that the pipeline will run an HMM classification
    #   'hybrid' is like "hmm" except that the unclustered proteins go to a all-vs-all blastp + hcluster stage
    #   'topup' means that the HMM classification is reused from prev_rel_db, and topped-up with the updated / new species  >> UNIMPLEMENTED <<
    #   'ortholog' means that it makes clusters out of orthologues coming from 'ref_ortholog_db' (transitive closre of the pairwise orthology relationships)
    'clustering_mode'           => 'hybrid',

    # species tree reconciliation
        # you can define your own species_tree for 'treebest'. It can contain multifurcations
        'species_tree_input_file'   => $self->o('ensembl_cvs_root_dir').'/ensembl-compara/scripts/pipeline/species_tree.plants.branch_len.nw',
        'binary_species_tree_input_file'    => undef,

    # homology_dnds parameters:
        # used by 'homology_dNdS'
        'taxlevels'                 => ['Liliopsida', 'eudicotyledons', 'Chlorophyta'],

    # GOC parameters
        'goc_taxlevels'                 => ['solanum', 'fabids', 'Brassicaceae', 'Pooideae', 'Oryzoideae', 'Panicoideae'],

    };
}


sub tweak_analyses {
    my $self = shift;
    my $analyses_by_name = shift;

    ## Extend this section to redefine the parameters of some analyses
    # turn off projections
    $analyses_by_name->{'insert_member_projections'}->{'-parameters'}->{'source_species_names'} = [];
    # prevent principal components from being flowed
    # $analyses_by_name->{'member_copy_factory'}->{'-parameters'}->{'polyploid_genomes'} = 0;

    ## Here we bump the resource class of some commonly MEMLIMIT
    ## failing analyses. Are these really EG specific?
    $analyses_by_name->{'mcoffee'}->{'-rc_name'} = '8Gb_job';
    $analyses_by_name->{'mcoffee_himem'}->{'-rc_name'} = '32Gb_job';
    $analyses_by_name->{'mafft'}->{'-rc_name'} = '8Gb_job';
    $analyses_by_name->{'mafft_himem'}->{'-rc_name'} = '32Gb_job';
    $analyses_by_name->{'treebest'}->{'-rc_name'} = '4Gb_job';
    $analyses_by_name->{'ortho_tree_himem'}->{'-rc_name'} = '4Gb_job';
    $analyses_by_name->{'members_against_allspecies_factory'}->{'-rc_name'} = '2Gb_job';
    $analyses_by_name->{'members_against_nonreusedspecies_factory'}->{'-rc_name'} = '2Gb_job';
    $analyses_by_name->{'hcluster_run'}->{'-rc_name'} = '1Gb_job';
    $analyses_by_name->{'hcluster_parse_output'}->{'-rc_name'} = '2Gb_job';
    $analyses_by_name->{'exon_boundaries_prep_himem'}->{'-rc_name'} = '8Gb_job';
    $analyses_by_name->{'tree_building_entry_point'}->{'-rc_name'} = '500Mb_job';
    $analyses_by_name->{'mafft_huge'}->{'-rc_name'} = '128Gb_4c_job';
    $analyses_by_name->{'homology_factory'}->{'-rc_name'}         = '1Gb_job';
    $analyses_by_name->{'copy_homology_dNdS'}->{'-rc_name'}       = '1Gb_job';
    $analyses_by_name->{'copy_homology_dNdS'}->{'-hive_capacity'} = '50';
    $analyses_by_name->{'threshold_on_dS'}->{'-rc_name'}          = '1Gb_job';

        $analyses_by_name->{'dump_canonical_members'}->{'-rc_name'} = '500Mb_job';
        $analyses_by_name->{'blastp'}->{'-rc_name'} = '500Mb_job';
}


1;
