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

  Bio::EnsEMBL::Compara::PipeConfig::EBI::EG::WormProteinTrees_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #2. you may need to update 'schema_version' in meta table to the current release number in ensembl-hive/sql/tables.sql

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::EG::WormProteinTrees_conf \
        -password <your_password> -mlss_id <your_current_PT_mlss_id> \
        -division <eg_division> -eg_release <egrelease>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output


=head1 DESCRIPTION

    The PipeConfig example file for the WormBase  group's version of
    ProteinTrees pipeline. This file is inherited from & customised further
    within the Ensembl Genomes infrastructure but this file serves as
    an example of the type of configuration we perform.

=head1 CONTACT

  Please contact WormBase with questions/suggestions

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::EG::WormProteinTrees_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::EBI::EG::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        # parameters that are likely to change from execution to another:

        #'do_not_reuse_list' => ['guillardia_theta'], # set this to empty or to the genome db names we should ignore
        'division' => 'worms',
        
        # custom pipeline name, in case you don't like the default one
        'dbowner' => 'worm',       # Used to prefix the database name (in HiveGeneric_conf)
        'pipeline_name' => 'compara_homology_WS' . $self->o('ws_release'),

        # dependent parameters: updating 'work_dir' should be enough
        'base_dir'              =>  '/nfs/nobackup/ensemblgenomes/wormbase/'.$self->o('ENV', 'USER').'/compara',
        'work_dir'              =>  $self->o('base_dir').'/ensembl_compara_'.$self->o('pipeline_name'),

        # blast parameters:
        
        # clustering parameters:
        
        # tree building parameters:
        'species_tree_input_file'   =>  $self->o('ensembl_cvs_root_dir') . "/compara-conf/compara_guide_tree.wormbase.nh",
        
        # homology_dnds parameters:
        'filter_high_coverage'      => 0,   # affects 'group_genomes_under_taxa'

        'use_quick_tree_break'      => 0,


        # the master database for synchronization of various ids (use undef if you don't have a master database)
        'master_db' => '',
        
        # NOTE: The databases referenced in the following arrays have to be hashes (not URLs)
        # Add the database entries for the current core databases and link 'curr_core_sources_locs' to them
        'curr_core_sources_locs' => 0,
        
        # Add the database entries for the core databases of the previous release
        'prev_core_sources_locs'   => 0,
        
        # Add the database location of the previous Compara release. Use "undef" if running the pipeline without reuse
        'prev_rel_db' => 0,

    };
}



1;
