
=pod 

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::LoadAllMasterGenomeDB_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::LoadAllMasterGenomeDB_conf -password <your_password>

=head1 DESCRIPTION  

    This is a test of JobFactory + LoadOneGenomeDB Runnables

=head1 CONTACT

  Please contact ehive-users@ebi.ac.uk mailing list with questions/suggestions.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::LoadAllMasterGenomeDB_conf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf');

sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},

        'pipeline_name' => 'load_all_master_genomedb',

        'pipeline_db' => {                                  # connection parameters
            -host   => 'compara2',
            -port   => 3306,
            -user   => 'ensadmin',
            -pass   => $self->o('password'),                        # a rule where a previously undefined parameter is used (which makes either of them obligatory)
            -dbname => $ENV{USER}.'_'.$self->o('pipeline_name'),    # a rule where a previously defined parameter is used (which makes both of them optional)
        },

        'reg1' => {
            -host   => 'ens-staging',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },

        'reg2' => {
            -host   => 'ens-staging2',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
        },

        master_db => {
            -host   => 'compara1',
            -port   => 3306,
            -user   => 'ensro',
            -pass   => '',
            -dbname => 'sf5_ensembl_compara_master',
        }
    };
}

sub pipeline_analyses {
    my ($self) = @_;
    return [
        {   -logic_name => 'load_genomedb_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => {
                'db_conn'           => $self->o('master_db'),
                'inputquery'        => 'SELECT genome_db_id, name, assembly FROM genome_db WHERE taxon_id AND assembly_default',
                'fan_branch_code'   => 2,
            },
            -input_ids  => [

                    # Note that if you do specify 'assembly_name' => '#_start_2#'
                    # it would mean "load only those where master_db's assembly is in agreement with staging genomes and crash otherwise:

                # { 'input_id'        => { 'genome_db_id' => '#_start_0#', 'species_name' => '#_start_1#' } },   

                    # Skipping the 'assembly_name' would mean "load the latest assembly for the genome and let me fix the master later":

                { 'input_id'        => { 'genome_db_id' => '#_start_0#', 'species_name' => '#_start_1#', 'assembly_name' => '#_start_2#' } },   

            ],
            -flow_into => {
                2 => [ 'load_genomedb' ],
            },
            -rc_id => 1,
        },

        {   -logic_name => 'load_genomedb',
            -module     => 'Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB',
            -parameters => {
                'registry_dbs'  => [ $self->o('reg1'), $self->o('reg2'), ],
            },
            -flow_into => {
                1 => [ 'dummy' ],   # each will flow into another one
            },
        },

        {   -logic_name    => 'dummy',
            -module        => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
            -hive_capacity => 10,       # allow several workers to perform identical tasks in parallel
        },
    ];
}

1;

