
=pod 

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::Example::WormProteinTrees_conf

=head1 SYNOPSIS

    #1. update ensembl-hive, ensembl and ensembl-compara CVS repositories before each new release

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

        'pipeline_db' => {                      # the production database itself (will be created)
            -host   => 'farmdb1',
            -port   => 3306,
            -user   => 'wormadmin',
            -pass   => $self->o('password'),                    
            -dbname => 'worm_compara_homology_'.$self->o('rel_with_suffix'),
        },

        'master_db' => {                        # the master database for synchronization of various ids
            -host   => 'farmdb1',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => 'worm_compara_master',
        },

    # switch off the reuse:
        'reuse_core_sources_locs'   => [ ],
        'prev_release'              => 0,   # 0 is the default and it means "take current release number and subtract 1"
        'reuse_db'                  => 0,
    };
}

1;

