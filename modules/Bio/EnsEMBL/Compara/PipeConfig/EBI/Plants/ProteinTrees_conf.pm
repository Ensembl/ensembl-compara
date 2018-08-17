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

use Bio::EnsEMBL::Hive::Utils ('stringify');

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
    'master_db' => 'mysql://ensro@mysql-ens-compara-prod-2:4522/plants_compara_master_41_94',

    'member_db' => 'mysql://ensro@mysql-ens-compara-prod-2:4522/carlac_load_members_plants_41_94',

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
    'prev_rel_db' => 'mysql://ensro@mysql-eg-prod-1:4238/ensembl_compara_plants_40_93',

    # Points to the previous production database. Will be used for various GOC operations. Use "undef" if running the pipeline without reuse.
    'goc_reuse_db'=> 'mysql://ensro@mysql-ens-compara-prod-1:4485/ensembl_compara_plants_hom_40_93',


    # homology_dnds parameters:
        # used by 'homology_dNdS'
        'taxlevels'                 => ['Liliopsida', 'eudicotyledons', 'Chlorophyta'],

    # GOC parameters
        'goc_taxlevels'                 => ['solanum', 'fabids', 'Brassicaceae', 'Pooideae', 'Oryzoideae', 'Panicoideae'],

    # Extra params
        # this should be 0 for plants
        'use_quick_tree_break'      => 0,
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

        $analyses_by_name->{'dump_canonical_members'}->{'-rc_name'} = '500Mb_job';
        $analyses_by_name->{'blastp'}->{'-rc_name'} = '500Mb_job';
        $analyses_by_name->{'ktreedist'}->{'-rc_name'} = '4Gb_job';
}


1;
