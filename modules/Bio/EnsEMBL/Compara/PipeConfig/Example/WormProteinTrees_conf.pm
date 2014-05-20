=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::Example::WormProteinTrees_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara GIT repositories before each new release

    #2. you may need to update 'schema_version' in meta table to the current release number in ensembl-hive/sql/tables.sql

    #3. make sure that all default_options are set correctly

    #4. Run init_pipeline.pl script:
        init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Example::WormProteinTrees_conf -password <your_password> -mlss_id <your_current_PT_mlss_id>

    #5. Sync and loop the beekeeper.pl as shown in init_pipeline.pl's output


=head1 DESCRIPTION  

The PipeConfig example file for WormBase group's version of ProteinTrees pipeline

=head1 CONTACT

Please contact Compara or WormBase with questions/suggestions

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Example::WormProteinTrees_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::Example::EnsemblProteinTrees_conf');


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # parameters that are likely to change from execution to another:
#       'mlss_id'               => 10,   # it is very important to check that this value is current (commented out to make it obligatory to specify)
#       'release'               => '63', # the ensembl release number

        'rel_suffix'            => 'WS' . $self->o('ENV', 'WORMBASE_RELEASE'),    # this WormBase Build
        'work_dir'              => '/lustre/scratch101/ensembl/wormpipe/tmp/'.$self->o('ENV', 'USER').'/protein_trees_'.$self->o('rel_with_suffix'),
        'outgroups'             => [ ],   # affects 'hcluster_dump_input_per_genome'
        'taxlevels'             => [ 'Nematoda' ],
        'filter_high_coverage'  => 0,   # affects 'group_genomes_under_taxa'

    # connection parameters to various databases:

        # The production database
        'host'          => 'farmdb1',
        'user'          => 'wormadmin',
        'dbowner'       => 'worm',
        'pipeline_name' => 'compara_homology_'.$self->o('rel_with_suffix'),

        # the master database for synchronization of various ids
        'master_db'     => 'mysql://ensro@farmdb1:3306/worm_compara_master',

    # switch off the reuse:
        'reuse_core_sources_locs'   => [ ],
        'reuse_db'                  => undef,
    };
}

1;

