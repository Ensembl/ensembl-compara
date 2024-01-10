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

Bio::EnsEMBL::Compara::PipeConfig::EG::WBParaSiteProteinTrees_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EG::WBParaSiteProteinTrees_conf -host mysql-ens-compara-prod-X -port XXXX \
            -mlss_id <curr_ptree_mlss_id>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output


=head1 DESCRIPTION

The PipeConfig example file for Ensembl Genomes group's version of
ProteinTrees pipeline. This file is inherited from & customised further
within the Ensembl Genomes infrastructure but this file serves as
an example of the type of configuration we perform.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EG::WBParaSiteProteinTrees_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::EG::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
      %{$self->SUPER::default_options},   # inherit the EnsemblGenomes ones (especially all the paths and capacities)

      # parameters that are likely to change from execution to another:
      #mlss_id => 40043,
      #'do_not_reuse_list' => ['guillardia_theta'], # set this to empty or to the genome db names we should ignore

      # custom pipeline name, in case you don't like the default one
      'dbowner' => 'ensembl_compara',       # Used to prefix the database name (in HiveGeneric_conf)
      'pipeline_name' => 'parasite_hom_'.$ENV{PARASITE_VERSION} . '_' . $ENV{ENSEMBL_VERSION},
      'division'  => 'parasite',

      # data directories:
      'work_dir'              =>  $ENV{PARASITE_SCRATCH} . '/compara/' . $self->o('pipeline_name'),
      'homology_dumps_shared_basedir' => $ENV{PARASITE_SCRATCH} . '/compara/' . '/homology_dumps/'. $self->o('division'),
      'gene_tree_stats_shared_basedir' => $ENV{PARASITE_SCRATCH} . '/compara/' . '/gene_tree_stats/' . $self->o('division'),
      'msa_stats_shared_basedir'       => $ENV{PARASITE_SCRATCH} . '/compara/' . '/msa_stats/' . $self->o('division'),
            
      # tree building parameters:
      'species_tree_input_file'   =>  $ENV{PARASITE_CONF} . '/compara_guide_tree.wbparasite.tre',

      'use_quick_tree_break'      => 0,
      
      # the master database for synchronization of various ids (use undef if you don't have a master database)
      'master_db' => '',

      # NOTE: only used in LoadMembers
      'exclude_gene_analysis' => {  'macrostomum_lignano_prjna284736' =>  ['mlignano_schatz_gene_bad']  },
      
      'mapped_gene_ratio_per_taxon' => {
          '2759'   => 0.25, #eukaryotes, 
          '119089' => 0.5, # Chromadorea, i.e. nematodes that are not clade I
          '6243'   => 0.65, # Clade V nematodes
          '6199'   => 0.65, # Tapeworms
          '6179'   => 0.65, # Flukes
          '2761626' => 0.49 # bunonema_rgd898_prjna655932
      },

      'ortho_tree_capacity'     => 50,
      'other_paralogs_capacity' => 50,


      ######## THESE ARE PASSED INTO LOAD_REGISTRY_FROM_DB SO PASS IN DB_VERSION
      ######## ALSO RAISE THE POINT ABOUT LOAD_FROM_MULTIPLE_DBs
            
      'mysql-ps-staging-1' => {
        -host   => 'mysql-ps-staging-1.ebi.ac.uk',
        -port   => 4451,
        -user   => 'ensro',
        -db_version => $self->o('ensembl_release')
      },

      'mysql-ps-staging-2' => {
        -host   => 'mysql-ps-staging-2.ebi.ac.uk',
        -port   => 4467,
        -user   => 'ensro',
        -db_version => $self->o('ensembl_release')
      },
            

      # NOTE: The databases referenced in the following arrays have to be hashes (not URLs)
      # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them

      'curr_core_sources_locs' => [$self->o("$ENV{PARASITE_STAGING_MYSQL}")],
    
      # Add the database entries for the core databases of the previous release
      'prev_core_sources_locs'   => 0,
    };
}


sub tweak_analyses {
  my $self = shift;
  my $analyses_by_name = shift;
  
  $analyses_by_name->{'hcluster_parse_output'}->{'-rc_name'} = '16Gb_job';
  $analyses_by_name->{'expand_clusters_with_projections'}->{'-rc_name'} = '4Gb_job';
  $analyses_by_name->{'stable_id_mapping'}->{'-rc_name'} = '4Gb_job';
  $analyses_by_name->{'hcluster_run'}->{'-rc_name'} = '64Gb_job';
  $analyses_by_name->{'ortho_tree'}->{'-rc_name'} = '2Gb_job';
  $analyses_by_name->{'ortho_tree_himem'}->{'-rc_name'} = '4Gb_job';
  $analyses_by_name->{'tree_building_entry_point'}->{'-rc_name'} = '1Gb_job';
  $analyses_by_name->{'treebest_decision'}->{'-rc_name'} = '1Gb_job';
  $analyses_by_name->{'hc_post_tree'}->{'-rc_name'} = '1Gb_job';
  $analyses_by_name->{'hc_tree_homologies'}->{'-rc_name'} = '1Gb_job';
  $analyses_by_name->{'ortho_tree_decision'}->{'-rc_name'} = '1Gb_job';
  $analyses_by_name->{'break_batch_unannotated'}->{'-rc_name'} = '1Gb_job';
  $analyses_by_name->{'treefam_xref_idmap'}->{'-rc_name'} = '4Gb_job';
  $analyses_by_name->{'exon_boundaries_prep_himem'}->{'-rc_name'} = '2Gb_job';
  $analyses_by_name->{'panther_paralogs'}->{'-rc_name'} = '1Gb_job';
  $analyses_by_name->{'panther_paralogs_himem'}->{'-rc_name'} = '4Gb_job';
  $analyses_by_name->{'dump_unannotated_members'}->{'-rc_name'} = '16Gb_job';
  $analyses_by_name->{'ktreedist'}->{'-rc_name'} = '4Gb_job';
  $analyses_by_name->{'ktreedist_himem'}->{'-rc_name'} = '8Gb_job';
  $analyses_by_name->{'final_tree_steps'}->{'-rc_name'} = '1Gb_job';
  $analyses_by_name->{'hc_post_tree'}->{'-rc_name'} = '1Gb_job';
  $analyses_by_name->{'treebest_decision'}->{'-rc_name'} = '1Gb_job';
  $analyses_by_name->{'tree_building_entry_point'}->{'-rc_name'} = '1Gb_job';
  $analyses_by_name->{'rib_group_2'}->{'-rc_name'} = '1Gb_job';
  $analyses_by_name->{'rib_fire_goc'}->{'-rc_name'} = '1Gb_job';
  $analyses_by_name->{'rib_fire_homology_stats'}->{'-rc_name'} = '1Gb_job';
  $analyses_by_name->{'goc_entry_point'}->{'-rc_name'} = '1Gb_job';
  $analyses_by_name->{'dump_unannotated_members'}->{'-rc_name'} = '8Gb_job';
  $analyses_by_name->{'hcluster_parse_output'}->{'-rc_name'} = '8Gb_job';
  $analyses_by_name->{'HMMer_classifyPantherScore_himem'}->{'-rc_name'} = '32Gb_job';
  $analyses_by_name->{'hc_global_tree_set'}->{'-rc_name'} = '32Gb_job';
  $analyses_by_name->{'homology_dumps_mlss_id_factory'}->{'-rc_name'} = '8Gb_job';
  $analyses_by_name->{'rib_group_1'}->{'-rc_name'} = '8Gb_job';
  $analyses_by_name->{'rib_group_2'}->{'-rc_name'} = '8Gb_job';
  $analyses_by_name->{'rib_group_3'}->{'-rc_name'} = '8Gb_job';
  $analyses_by_name->{'rib_fire_tree_stats'}->{'-rc_name'} = '8Gb_job';
  $analyses_by_name->{'set_default_values'}->{'-rc_name'} = '8Gb_job';
  $analyses_by_name->{'rib_fire_high_confidence_orths'}->{'-rc_name'} = '8Gb_job';
  $analyses_by_name->{'paralogue_for_import_factory'}->{'-rc_name'} = '8Gb_job';
  $analyses_by_name->{'mlss_id_for_high_confidence_factory'}->{'-rc_name'} = '8Gb_job';
  $analyses_by_name->{'flag_high_confidence_orthologs'}->{'-rc_name'} = '2Gb_job';
  $analyses_by_name->{'write_stn_tags'}->{'-rc_name'} = '8Gb_job';
}


1;
