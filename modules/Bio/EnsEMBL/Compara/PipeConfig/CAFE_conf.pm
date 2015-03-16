=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::CAFE_conf

=head1 SYNOPSIS

    #0. make sure that ncRNA pipeline (whose gene clusters you want to incorporate) is already past member the RFAMClassify analysis

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::CAFE_conf -password <your_password> -pipeline_name <ncRNAtree_pipeline_name> -host <host_where_the_ncRNAtree_pipeline_is_running>> -analysis_topup

    #5. Run the "sync" and "loop" commands as suggested by init_pipeline.pl

    #6. Pray

=head1 DESCRIPTION  

    The PipeConfig file for CAFE pipeline. It is used as an analysis_topup pipeline.

=head1 HISTORY


  Release 68:

  ncRNAtrees pipeline:
  init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::CAFE_conf -mlss_id 40084 -work_dir /nfs/users/nfs_m/mp12/ensembl_main/ncrna_trees_68 -analysis_topup  -wait_for db_snapshot_after_Rfam_classify -per_family_table 0 -type nc -pipeline_name compara_nctrees_68 -host compara2

  Release 69:

  ncRNAtrees pipeline:
  init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::CAFE_conf -mlss_id 40083 -work_dir /nfs/users/nfs_m/mp12/ncrna_trees_68CAFEtest  -analysis_topup -wait_for backbone_fire_db_prepare -per_family_table 0 -type nc -pipeline_name mp12_compara_nctrees_68st -host compara4

  Release 71:
  ncRNAtrees pipeline:
  init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::CAFE_conf -mlss_id 40089 -work_dir /lustre/scratch110/ensembl/mp12/nc_trees_71_CAFE -analysis_topup -wait_for backbone_fire_db_prepare
-per_family_table 0 -type nc -pipeline_name mp12_compara_nctrees_71 -host compara2 -cafe_species "['danio.rerio', 'taeniopygia.guttata', 'callithrix.jacchus', 'pan.troglodytes', 'homo.sapiens', 'mus.musculus']"
  proteinTrees pipeline:
  init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::CAFE_conf -mlss_id 40090 -work_dir /lustre/scratch110/ensembl/mp12/protein_trees_71_CAFE -analysis_topup -wait_for backbone_fire_tree_building -per_family_table 1 -type prot -pipeline_name mm14_compara_homology_71 -host compara1

  Release 72:
  ncRNAtrees pipeline:
  init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::CAFE_conf -mlss_id 40089 -work_dir /lustre/scratch110/ensembl/mp12/nc_trees_72 -analysis_topup -wait_for backbone_fire_db_prepare -per_family_table 0 -type nc -pipeline_name mp12_compara_nctrees_72 -host compara2 -cafe_species "['danio.rerio', 'taeniopygia.guttata', 'callithrix.jacchus', 'pan.troglodytes', 'homo.sapiens', 'mus.musculus']"

  proteinTrees pipeline:
  init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::CAFE_conf -mlss_id 40090 -work_dir /lustre/scratch110/ensembl/mp12/protein_trees_71_CAFE -analysis_topup -wait_for backbone_fire_dnds -per_family_table 1 -type prot -pipeline_name mp12_compara_homology_72 -host compara3 -cafe_species []

  Release 74:
  ncRNAtrees_pipeline:
  init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::CAFE_conf -mlss_id 40094 -work_dir /lustre/scratch109/ensembl/mp12/nc_trees_74 -analysis_topup -wait_for backbone_fire_db_prepare -per_family_table 0 -type nc -pipeline_name mp12_compara_nctrees_74clean2 -host compara2 -cafe_species "['danio.rerio', 'taeniopygia.guttata', 'callithrix.jacchus', 'pan.troglodytes', 'homo.sapiens', 'mus.musculus']"

  proteinTrees pipeline:
  init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::CAFE_conf -mlss_id 40093 -work_dir /lustre/scratch110/ensembl/mp12/protein_trees_74_CAFE -analysis_topup -wait_for backbone_fire_dnds -per_family_table 1 -type prot -pipeline_name mm14_protein_trees_74_with_sheep -host compara1 -cafe_species []

  Release 76:
  ncRNAtrees:
  init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::CAFE_conf -mlss_id 40095 -work_dir /lustre/scratch109/ensembl/mp12/nc_trees_76 -wait_for backbone_fire_db_prepare -per_family_table 0 -type nc -pipeline_url mysql://ensadmin:ensembl@compara4/mp12_compara_nctrees_76b -cafe_species "['danio.rerio', 'taeniopygia.guttata', 'callithrix.jacchus', 'pan.troglodytes', 'homo.sapiens', 'mus.musculus']"

  proteinTrees pipeline:
  init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::CAFE_conf -mlss_id 40096 -work_dir /lustre/scratch110/ensembl/mp12/protein_trees_76_CAFE -wait_for backbone_fire_dnds -per_family_table 1 -type prot -pipeline_url mysql://ensadmin:ensembl@compara3/mm14_protein_trees_76b -cafe_species []


  Release 77:
  ncRNAtrees:
  init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::CAFE_conf -mlss_id 40098 -wait_for backbone_fire_db_prepare -per_family_table 0 -type nc -pipeline_url mysql://ensadmin:ensembl@compara3/mm14_compara_nctrees_77 -cafe_species "['danio.rerio', 'taeniopygia.guttata', 'callithrix.jacchus', 'pan.troglodytes', 'homo.sapiens', 'mus.musculus']"

  proteinTrees:
  init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::CAFE_conf -mlss_id 40097 -wait_for backbone_fire_dnds -per_family_table 1 -type prot -pipeline_url mysql://ensadmin:ensembl@compara1/mm14_protein_trees_77 -cafe_species []

  Release 78:
  ncRNAtrees:
  init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::CAFE_conf -mlss_id 40098 -wait_for backbone_fire_db_prepare -per_family_table 0 -type nc -pipeline_url mysql://ensadmin:ensembl@compara3/mp12_compara_nctrees_78a -cafe_species "['danio.rerio', 'taeniopygia.guttata', 'callithrix.jacchus', 'pan.troglodytes', 'homo.sapiens', 'mus.musculus']"

  Release 79:
  init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::CAFE_conf -mlss_id 40100 -work_dir scratch/109/cafe_nctrees_79 -wait_for backbone_fire_db_prepare -per_family_table 0 -type nc -pipeline_url mysql://ensadmin:ensembl@compara3/mm14_compara_nctrees_79b -cafe_species "['danio.rerio', 'taeniopygia.guttata', 'callithrix.jacchus', 'pan.troglodytes', 'homo.sapiens', 'mus.musculus']" -hive_no_init 1
  init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::CAFE_conf -mlss_id 40099 -work_dir scratch/109/cafe_proteintrees_79 -wait_for backbone_fire_dnds -per_family_table 1 -type prot -pipeline_url mysql://ensadmin:ensembl@compara1/mm14_protein_trees_79 -cafe_species [] -hive_no_init 1

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::CAFE_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
            %{$self->SUPER::default_options},

            # You need to specify -pipeline_name, -host and -password on command line (if they are not already set as an environmental variable)

            # Data needed for CAFE
            'cafe_lambdas'             => '',  # For now, we don't supply lambdas
            'cafe_struct_tree_str'     => '',  # Not set by default
            'cafe_shell'               => '/software/ensembl/compara/cafe/cafe.2.2/cafe/bin/shell',
            'full_species_tree_label'  => 'full_species_tree',
#            'badiRate_exe'            => '/software/ensembl/compara/badirate-1.35/BadiRate.pl',

            'pipeline_db'   => {
                                -driver => 'mysql',
                                -host   => $self->o('host'),
                                -port   => 3306,
                                -user   => 'ensadmin',
                                -pass   => $self->o('password'),
                                -dbname => $self->o('pipeline_name'),  # redefined (defined also in HiveGeneric_conf.pm) to allow toping up in other user's pipelines
                               },
           };
}

sub pipeline_analyses {
    my ($self) = @_;
    return [
            {
             -logic_name => 'make_full_species_tree',
             -module => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
             -input_ids => [{}],
             -parameters => {
                             'mlss_id'  => $self->o('mlss_id'),
                             'label'    => $self->o('full_species_tree_label'),
                            },
             -wait_for => [$self->o('wait_for')],
             -flow_into  => {
                             # 3 => { 'mysql:////meta' => { 'meta_key' => $self->o('species_tree_meta_key'), 'meta_value' => '#species_tree_string#' } },
                             1 => ['CAFE_species_tree'],
                            },
            },

            {
             -logic_name => 'CAFE_species_tree',
             -module => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CAFESpeciesTree',
             -parameters => {
                             'cafe_species' => $self->o('cafe_species'),
                             'mlss_id'      => $self->o('mlss_id'),
                             'label'        => $self->o('full_species_tree_label')
                            },
             -flow_into => {
#                            '1->A' => ['BadiRate'],
                            1 => ['CAFE_table'],
                           },
            },

#            {
#             -logic_name => 'BadiRate',
#             -module     => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::BadiRate',
#             -parameters => {
#                             'mlss_id'               => $self->o('mlss_id'),
#                             'species_tree_meta_key' => $self->o('species_tree_meta_key'),
#                             'badiRate_exe'          => $self->o('badiRate_exe'),
#                            }
#            },

            {
             -logic_name => 'CAFE_table',
             -module => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CAFETable',
             -parameters => {
                             'cafe_species' => $self->o('cafe_species'),
                             'mlss_id'      => $self->o('mlss_id'),
                             'type'         => $self->o('type'),   # [nc|prot]
                             'perFamTable'  => $self->o('per_family_table'),
                             'mlss_id'      => $self->o('mlss_id'),
                             'cafe_shell'   => $self->o('cafe_shell'),
                            },
             -rc_name => '1Gb_job',
             -meadow_type => 'LSF',
             -flow_into => {
                            2 => ['CAFE_analysis'],
                           },
            },

            {
             -logic_name => 'CAFE_analysis',
             -module => 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CAFEAnalysis',
             -parameters => {
#                             'cafe_lambdas'         => $self->o('cafe_lambdas'),
#                             'cafe_struct_taxons'  => $self->o('cafe_'),
                             'cafe_struct_tree_str' => $self->o('cafe_struct_tree_str'),
                             'mlss_id'              => $self->o('mlss_id'),
                             'cafe_shell'           => $self->o('cafe_shell'),
                            },
             -rc_name => '1Gb_job',
             -meadow_type => 'LSF',
             -priority => 10,
            },
           ]
}

1;
